import AVFoundation
import CoreImage
import Foundation
import LutliCore

/// All capture configuration and device mutations run on sessionQueue. Frame
/// rendering has its own serial queue, and LUTRenderer protects its recipe.
final class CameraSessionService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.lutli.camera.session", qos: .userInitiated)
    private let frameQueue = DispatchQueue(label: "app.lutli.camera.frames", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let renderer = LUTRenderer()
    private let onEvent: @MainActor (CameraEvent) -> Void
    private let deliveryLock = NSLock()
    private var previewDeliveryPending = false

    // sessionQueue only
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private var wantsRunning = false
    private var requestedExposure: Double = 0
    private var whiteBalance: CameraWhiteBalance = .auto
    private var flashMode: CameraFlashMode = .off
    private var captureProcessors: [Int64: PhotoCaptureProcessor] = [:]
    private var notificationTokens: [NSObjectProtocol] = []

    // frameQueue only
    private var lastPreviewTime: TimeInterval = 0
    private var reportedRenderError = false

    init(onEvent: @escaping @MainActor (CameraEvent) -> Void) {
        self.onEvent = onEvent
        super.init()
        installNotifications()
    }

    deinit {
        for token in notificationTokens { NotificationCenter.default.removeObserver(token) }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = true
            do {
                if !self.configured { try self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                self.publish(.running(self.session.isRunning))
            } catch {
                self.publish(.running(false))
                self.publish(.error(error.localizedDescription))
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.publish(.running(false))
        }
    }

    func setLUT(_ lut: CubeLUT) {
        renderer.setLUT(lut)
    }

    func setDiffusion(_ settings: DiffusionSettings) {
        renderer.setDiffusion(settings)
    }

    func setExposure(_ value: Double) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.requestedExposure = value
            guard let device = self.input?.device else { return }
            do {
                try self.configureExposure(on: device)
                self.publishCapabilities()
            } catch { self.publish(.error(error.localizedDescription)) }
        }
    }

    func setWhiteBalance(_ value: CameraWhiteBalance) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.input?.device else {
                self.whiteBalance = value
                return
            }
            do {
                try self.configureWhiteBalance(value, on: device)
                self.whiteBalance = value
                self.publish(.whiteBalanceChanged(value))
            } catch {
                self.publish(.whiteBalanceChanged(self.whiteBalance))
                self.publish(.error(error.localizedDescription))
            }
        }
    }

    func setFlashMode(_ mode: CameraFlashMode) {
        sessionQueue.async { [weak self] in self?.flashMode = mode }
    }

    func selectLens(id: String) {
        sessionQueue.async { [weak self] in
            guard let self, self.captureProcessors.isEmpty,
                  let device = self.discoverDevices().first(where: { $0.uniqueID == id }) else { return }
            do { try self.changeDevice(to: device) }
            catch { self.publish(.error(error.localizedDescription)) }
        }
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureProcessors.isEmpty, let current = self.input?.device else { return }
            let position: AVCaptureDevice.Position = current.position == .front ? .back : .front
            let candidates = self.discoverDevices().filter { $0.position == position }
            guard let device = candidates.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? candidates.first else {
                self.publish(.error("There is no other camera available on this device."))
                return
            }
            do { try self.changeDevice(to: device) }
            catch { self.publish(.error(error.localizedDescription)) }
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.input?.device else { return }
            // The preview is portrait, and front-camera pixels are mirrored.
            let displayX = device.position == .front ? 1 - point.x : point.x
            let devicePoint = CGPoint(x: point.y, y: 1 - displayX)
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            } catch { self.publish(.error(error.localizedDescription)) }
        }
    }

    func capture(saveOriginal: Bool) {
        // Freeze the recipe at the user's shutter action, before sessionQueue
        // scheduling can allow a subsequent look change to overtake the capture.
        let recipe = renderer.snapshot()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning, self.captureProcessors.isEmpty else {
                self.publish(.captureFailed(CameraFailure.notRunning.localizedDescription))
                return
            }
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.photoQualityPrioritization = .quality
            if self.photoOutput.maxPhotoDimensions.width > 0 {
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            }
            if self.input?.device.isFlashAvailable == true {
                settings.flashMode = self.flashMode.captureMode
            }
            let identifier = settings.uniqueID
            let processor = PhotoCaptureProcessor { [weak self] result in
                guard let self else { return }
                self.sessionQueue.async {
                    self.captureProcessors.removeValue(forKey: identifier)
                }
                self.frameQueue.async {
                    do {
                        let data = try result.get()
                        let photo = try self.renderer.renderCapture(data: data, recipe: recipe, saveOriginal: saveOriginal)
                        self.publish(.captureFinished(photo))
                    } catch { self.publish(.captureFailed(error.localizedDescription)) }
                }
            }
            self.captureProcessors[identifier] = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPreviewTime >= 1.0 / 15.0,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        deliveryLock.lock()
        let alreadyPending = previewDeliveryPending
        if !alreadyPending { previewDeliveryPending = true }
        deliveryLock.unlock()
        guard !alreadyPending else { return }
        lastPreviewTime = now

        // The video connection has already physically rotated/mirrored the BGRA
        // buffer. Do not apply the photo's EXIF transform to preview buffers.
        autoreleasepool {
            do {
                let image = try renderer.renderPreview(CIImage(cvPixelBuffer: buffer))
                reportedRenderError = false
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onEvent(.preview(image))
                    self.finishPreviewDelivery()
                }
            } catch {
                finishPreviewDelivery()
                if !reportedRenderError {
                    reportedRenderError = true
                    publish(.error(error.localizedDescription))
                }
            }
        }
    }

    private func configure() throws {
        let devices = discoverDevices()
        guard let device = devices.first(where: { $0.position == .back && $0.deviceType == .builtInWideAngleCamera }) ?? devices.first else {
            throw CameraFailure.noCamera
        }
        let newInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        do {
            session.sessionPreset = .photo
            // The first implementation has an SDR sRGB processing contract.
            // Do not let adding the photo output silently select a wide-color
            // device configuration that differs from the video preview.
            session.automaticallyConfiguresCaptureDeviceForWideColor = false
            guard session.canAddInput(newInput) else { throw CameraFailure.unavailableInput }
            session.addInput(newInput)
            guard session.canAddOutput(photoOutput) else { throw CameraFailure.unavailableOutput }
            session.addOutput(photoOutput)
            guard session.canAddOutput(videoOutput) else { throw CameraFailure.unavailableOutput }
            session.addOutput(videoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
            input = newInput
            try configureDevice(device)
            configureConnections(isFront: device.position == .front)
            configurePhotoDimensions(for: device)
            session.commitConfiguration()
            configured = true
            publishCapabilities()
        } catch {
            for output in session.outputs { session.removeOutput(output) }
            for input in session.inputs { session.removeInput(input) }
            input = nil
            session.commitConfiguration()
            throw error
        }
    }

    private func changeDevice(to device: AVCaptureDevice) throws {
        guard let oldInput = input, oldInput.device.uniqueID != device.uniqueID else { return }
        let newInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        session.removeInput(oldInput)
        guard session.canAddInput(newInput) else {
            if session.canAddInput(oldInput) { session.addInput(oldInput) }
            session.commitConfiguration()
            throw CameraFailure.unavailableInput
        }
        session.addInput(newInput)
        input = newInput
        do {
            try configureDevice(device)
            configureConnections(isFront: device.position == .front)
            configurePhotoDimensions(for: device)
            session.commitConfiguration()
            publishCapabilities()
        } catch {
            session.removeInput(newInput)
            if session.canAddInput(oldInput) { session.addInput(oldInput) }
            input = oldInput
            configureConnections(isFront: oldInput.device.position == .front)
            configurePhotoDimensions(for: oldInput.device)
            session.commitConfiguration()
            publishCapabilities()
            throw error
        }
    }

    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        if device.activeFormat.supportedColorSpaces.contains(.sRGB) {
            device.activeColorSpace = .sRGB
        }
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = false
            device.isVideoHDREnabled = false
        }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        device.unlockForConfiguration()
        try configureExposure(on: device)
        if device.isWhiteBalanceModeSupported(.locked) || whiteBalance == .auto {
            try configureWhiteBalance(whiteBalance, on: device)
        } else {
            whiteBalance = .auto
            try configureWhiteBalance(.auto, on: device)
        }
        publish(.whiteBalanceChanged(whiteBalance))
    }

    private func configureExposure(on device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        let value = min(max(Float(requestedExposure), device.minExposureTargetBias), device.maxExposureTargetBias)
        device.setExposureTargetBias(value, completionHandler: nil)
    }

    private func configureWhiteBalance(_ mode: CameraWhiteBalance, on device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        switch mode {
        case .auto:
            guard device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { throw CameraFailure.whiteBalanceUnavailable }
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        case .locked:
            guard device.isWhiteBalanceModeSupported(.locked) else { throw CameraFailure.whiteBalanceUnavailable }
            device.setWhiteBalanceModeLocked(with: clampedGains(device.deviceWhiteBalanceGains, on: device), completionHandler: nil)
        case .manual(let temperature, let tint):
            guard device.isWhiteBalanceModeSupported(.locked) else { throw CameraFailure.whiteBalanceUnavailable }
            let values = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: min(max(temperature, 2_000), 10_000),
                tint: min(max(tint, -150), 150)
            )
            let gains = device.deviceWhiteBalanceGains(for: values)
            device.setWhiteBalanceModeLocked(with: clampedGains(gains, on: device), completionHandler: nil)
        }
    }

    private func clampedGains(_ gains: AVCaptureDevice.WhiteBalanceGains, on device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        func clamp(_ value: Float) -> Float {
            guard value.isFinite else { return 1 }
            return min(max(value, 1), device.maxWhiteBalanceGain)
        }
        return AVCaptureDevice.WhiteBalanceGains(
            redGain: clamp(gains.redGain), greenGain: clamp(gains.greenGain), blueGain: clamp(gains.blueGain)
        )
    }

    private func configureConnections(isFront: Bool) {
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 }) {
            // Explicit portrait orientation is intentional for the first release.
            // This API remains available on iOS 17 and handles sensor orientation
            // for both front and rear cameras without guessing physical angles.
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFront
            }
        }
    }

    private func configurePhotoDimensions(for device: AVCaptureDevice) {
        if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            photoOutput.maxPhotoDimensions = largest
        }
    }

    private func discoverDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video, position: .unspecified
        ).devices
    }

    private func publishCapabilities() {
        guard let device = input?.device else { return }
        let available = discoverDevices().filter { $0.position == device.position }
        let lenses = available.sorted { lensRank($0) < lensRank($1) }.map {
            CameraLens(id: $0.uniqueID, title: lensTitle($0), isFront: $0.position == .front)
        }
        let supportsLock = device.isWhiteBalanceModeSupported(.locked)
        publish(.capabilities(CameraCapabilities(
            lenses: lenses, currentLensID: device.uniqueID, isFront: device.position == .front,
            exposureBounds: Double(device.minExposureTargetBias)...Double(device.maxExposureTargetBias),
            exposure: min(max(requestedExposure, Double(device.minExposureTargetBias)), Double(device.maxExposureTargetBias)),
            supportsWhiteBalanceLock: supportsLock, supportsManualWhiteBalance: supportsLock,
            supportsFlash: device.hasFlash && device.isFlashAvailable
        )))
    }

    private func lensRank(_ device: AVCaptureDevice) -> Int {
        switch device.deviceType {
        case .builtInUltraWideCamera: return 0
        case .builtInWideAngleCamera: return 1
        default: return 2
        }
    }

    private func lensTitle(_ device: AVCaptureDevice) -> String {
        switch device.deviceType {
        case .builtInUltraWideCamera: return "0.5×"
        case .builtInWideAngleCamera: return "1×"
        default: return "Tele"
        }
    }

    private func publish(_ event: CameraEvent) {
        Task { @MainActor [onEvent] in onEvent(event) }
    }

    private func finishPreviewDelivery() {
        deliveryLock.lock()
        previewDeliveryPending = false
        deliveryLock.unlock()
    }

    private func installNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            self?.publish(.interrupted("The camera was interrupted. It will resume when it becomes available."))
        })
        notificationTokens.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.publish(.interruptionEnded)
            self.sessionQueue.async {
                if self.wantsRunning && !self.session.isRunning { self.session.startRunning() }
                self.publish(.running(self.session.isRunning))
            }
        })
        notificationTokens.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            self.sessionQueue.async {
                if error?.code == .mediaServicesWereReset, self.wantsRunning {
                    self.session.startRunning()
                } else {
                    self.publish(.error(error?.localizedDescription ?? "The camera stopped unexpectedly. Please reopen it."))
                }
                self.publish(.running(self.session.isRunning))
            }
        })
    }
}

private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void
    private let lock = NSLock()
    private var data: Data?
    private var processingError: Error?

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        processingError = error
        if error == nil { data = photo.fileDataRepresentation() }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        lock.lock()
        let captureError = error ?? processingError
        let capturedData = data
        lock.unlock()
        if let captureError {
            completion(.failure(captureError))
        } else if let capturedData {
            completion(.success(capturedData))
        } else {
            completion(.failure(CameraFailure.noPhotoData))
        }
    }
}
