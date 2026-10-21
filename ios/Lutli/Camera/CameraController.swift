import AVFoundation
import Combine
import CoreGraphics
import Foundation
import LutliCore

/// UI-facing camera state. All AVCaptureSession work lives on the service queue.
@MainActor
final class CameraController: ObservableObject {
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var authorization: CameraAuthorization = .notDetermined
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var exposureBounds: ClosedRange<Double> = 0...0
    @Published private(set) var exposure: Double = 0
    @Published private(set) var lenses: [CameraLens] = []
    @Published private(set) var currentLensID: String?
    @Published private(set) var isFrontCamera = false
    @Published private(set) var supportsWhiteBalanceLock = false
    @Published private(set) var supportsManualWhiteBalance = false
    @Published private(set) var supportsFlash = false
    @Published private(set) var flashMode: CameraFlashMode = .off
    @Published private(set) var whiteBalance: CameraWhiteBalance = .auto
    @Published private(set) var latestCapture: CapturedPhoto?
    @Published private(set) var photoSaveStatus: PhotoSaveStatus?

    private var wantsRunning = false
    private var requestingAccess = false
    private lazy var service = CameraSessionService { [weak self] event in
        self?.handle(event)
    }

    func start() {
        wantsRunning = true
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            authorization = .authorized
            service.start()
        case .notDetermined:
            authorization = .notDetermined
            guard !requestingAccess else { return }
            requestingAccess = true
            Task { [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self else { return }
                self.requestingAccess = false
                self.authorization = granted ? .authorized : .denied
                if granted && self.wantsRunning { self.service.start() }
            }
        case .denied:
            authorization = .denied
            isRunning = false
            previewImage = nil
            service.stop()
        case .restricted:
            authorization = .restricted
            isRunning = false
            previewImage = nil
            service.stop()
        @unknown default:
            authorization = .restricted
            isRunning = false
            previewImage = nil
            service.stop()
        }
    }

    func stop() {
        wantsRunning = false
        isRunning = false
        previewImage = nil
        service.stop()
    }

    func setLUT(_ cube: CubeLUT) {
        service.setLUT(cube)
    }

    func setExposure(_ value: Double) {
        guard value.isFinite else { return }
        let clamped = min(max(value, exposureBounds.lowerBound), exposureBounds.upperBound)
        exposure = clamped
        service.setExposure(clamped)
    }

    func setWhiteBalance(_ mode: CameraWhiteBalance) {
        switch mode {
        case .auto: break
        case .locked:
            guard supportsWhiteBalanceLock else { return }
        case .manual(let temperature, let tint):
            guard supportsManualWhiteBalance, temperature.isFinite, tint.isFinite else { return }
        }
        whiteBalance = mode
        service.setWhiteBalance(mode)
    }

    func setFlashMode(_ mode: CameraFlashMode) {
        flashMode = supportsFlash ? mode : .off
        service.setFlashMode(flashMode)
    }

    func switchCamera() {
        guard !isCapturing else { return }
        service.switchCamera()
    }

    func selectLens(id: String) {
        guard !isCapturing else { return }
        service.selectLens(id: id)
    }

    /// Coordinates are normalized to the displayed upright, mirrored preview.
    /// The UI must account for any aspect-fill cropping before calling this.
    func tapFocus(normalized point: CGPoint) {
        guard point.x.isFinite, point.y.isFinite else { return }
        let clamped = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        service.focus(at: clamped)
    }

    func capture(saveOriginal: Bool) {
        guard isRunning, !isCapturing, !isSaving else { return }
        errorMessage = nil
        isCapturing = true
        service.capture(saveOriginal: saveOriginal)
    }

    func clearError() {
        errorMessage = nil
    }

    /// A successful or in-flight save cannot be submitted a second time.
    func retrySaveLatestCapture() {
        guard !isSaving, !isCapturing, let photo = latestCapture, let status = photoSaveStatus,
              status.photoID == photo.id, case .failed = status.phase else { return }
        errorMessage = nil
        saveToPhotos(photo)
    }

    private func saveToPhotos(_ photo: CapturedPhoto) {
        guard !isSaving, latestCapture?.id == photo.id else { return }
        isSaving = true
        photoSaveStatus = PhotoSaveStatus(photoID: photo.id, phase: .saving)
        Task { [weak self] in
            let phase: PhotoSavePhase
            do {
                try await PhotoLibraryWriter().save(photo)
                phase = .saved
            } catch {
                phase = .failed(
                    message: error.localizedDescription,
                    needsPermission: (error as? PhotoLibraryWriter.Failure) == .accessDenied
                )
            }
            guard let self, self.latestCapture?.id == photo.id,
                  self.photoSaveStatus?.photoID == photo.id else { return }
            self.photoSaveStatus = PhotoSaveStatus(photoID: photo.id, phase: phase)
            self.isSaving = false
            if case .failed(let message, _) = phase { self.errorMessage = message }
        }
    }

    private func handle(_ event: CameraEvent) {
        switch event {
        case .preview(let image):
            if wantsRunning, isRunning, authorization == .authorized { previewImage = image }
        case .running(let running):
            isRunning = running && wantsRunning && authorization == .authorized
            if !isRunning { previewImage = nil }
        case .capabilities(let capabilities):
            lenses = capabilities.lenses
            currentLensID = capabilities.currentLensID
            isFrontCamera = capabilities.isFront
            exposureBounds = capabilities.exposureBounds
            exposure = capabilities.exposure
            supportsWhiteBalanceLock = capabilities.supportsWhiteBalanceLock
            supportsManualWhiteBalance = capabilities.supportsManualWhiteBalance
            supportsFlash = capabilities.supportsFlash
            if !supportsFlash { flashMode = .off }
            if !supportsWhiteBalanceLock { whiteBalance = .auto }
        case .whiteBalanceChanged(let mode):
            whiteBalance = mode
        case .captureFinished(let photo):
            isCapturing = false
            latestCapture = photo
            saveToPhotos(photo)
        case .captureFailed(let message):
            isCapturing = false
            errorMessage = message
        case .error(let message):
            errorMessage = message
        case .interrupted(let message):
            isRunning = false
            previewImage = nil
            errorMessage = message
        case .interruptionEnded:
            errorMessage = nil
        }
    }
}
