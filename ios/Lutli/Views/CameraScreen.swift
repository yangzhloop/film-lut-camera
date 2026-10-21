import LutliCore
import SwiftUI
import UIKit

struct CameraScreen: View {
    @EnvironmentObject private var model: LutliAppModel
    @EnvironmentObject private var camera: CameraController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var shortcutHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var intensityHeight: CGFloat = 34
    @State private var sheet: CameraSheet?
    @State private var showsDiffusion = false

    private enum CameraSheet: String, Identifiable {
        case looks, menu, exposure, whiteBalance, review
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let controlsHeight: CGFloat = 46 + shortcutHeight + 95 + intensityHeight + 82
            let previewHeight = max(0, min(geometry.size.width * 4 / 3, geometry.size.height - controlsHeight))
            VStack(spacing: 0) {
                toolbar
                ZStack(alignment: .bottom) {
                    PreviewSurface(image: camera.isRunning && camera.authorization == .authorized ? camera.previewImage : nil, grid: model.showGrid) { point in
                        camera.tapFocus(normalized: point)
                    }
                    .allowsHitTesting(!showsDiffusion)
                    .accessibilityIdentifier("camera.preview")
                    if camera.previewImage == nil || !camera.isRunning || camera.authorization != .authorized {
                        cameraAvailability
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityHidden(showsDiffusion)
                    }
                    if let remaining = model.countdown {
                        Text("\(remaining)")
                            .font(.system(size: 76, weight: .light, design: .rounded))
                            .shadow(radius: 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel("Taking photo in \(remaining) seconds")
                    }
                    if showsDiffusion {
                        // Consume the first outside tap: closing the tray must
                        // not also move focus or exposure behind it.
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { setDiffusionVisible(false) }
                            .accessibilityHidden(true)
                        DiffusionControlsView(maximumHeight: max(0, previewHeight - 44)) {
                            setDiffusionVisible(false)
                        }
                        .transition(reduceMotion ? .identity : .opacity)
                    } else {
                        lensSelector
                            .padding(.bottom, 12)
                    }
                }
                .frame(height: previewHeight)
                .background(.black)
                .clipped()
                controlShortcuts
                lookStrip
                intensityControl
                captureControls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(LutliTheme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .onChange(of: scenePhase) { _, phase in
            // Native color selection can briefly make the scene inactive.
            // Collapse on background only so its live selection is retained.
            if phase == .background { showsDiffusion = false }
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .looks: LooksLibraryView()
            case .menu: AppMenuView()
            case .exposure: ExposureControlsView()
            case .whiteBalance: WhiteBalanceControlsView()
            case .review:
                if let photo = camera.latestCapture { CaptureReviewView(photo: photo) }
            }
        }
        .alert("Lutli", isPresented: Binding(
            get: { model.errorMessage != nil || camera.errorMessage != nil },
            set: { shown in if !shown { model.errorMessage = nil; camera.clearError() } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil; camera.clearError() }
        } message: {
            Text(model.errorMessage ?? camera.errorMessage ?? "Please try again.")
        }
    }

    private var toolbar: some View {
        HStack {
            IconButton(systemName: flashSymbol, label: camera.supportsFlash ? "Flash \(camera.flashMode.rawValue)" : "Flash unavailable") {
                let modes = CameraFlashMode.allCases
                guard let index = modes.firstIndex(of: camera.flashMode) else { return }
                camera.setFlashMode(modes[(index + 1) % modes.count])
            }
            .disabled(!camera.supportsFlash || camera.isCapturing)
            .opacity(camera.supportsFlash ? 1 : 0.35)
            Spacer()
            Text("lutli").font(.system(size: 24, weight: .medium, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            IconButton(systemName: "gearshape", label: "App menu") {
                model.cancelCountdown()
                present(.menu)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
    }

    private var flashSymbol: String {
        switch camera.flashMode {
        case .off: return "bolt.slash"
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        }
    }

    private var cameraAvailability: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera").font(.largeTitle)
            switch camera.authorization {
            case .denied, .restricted:
                Text("Camera access is needed to shoot.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.bordered)
            case .notDetermined:
                Text("Allow camera access to start shooting.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            case .authorized:
                Text(camera.isRunning ? "Preparing preview…" : "Camera is not available")
                    .font(.headline)
                if !camera.isRunning {
                    Text("Use a supported iPhone to capture photos. You can still manage your looks.")
                        .font(.footnote)
                        .foregroundStyle(LutliTheme.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { camera.start() }.buttonStyle(.bordered)
                }
            }
        }
        .padding(26)
    }

    private var lensSelector: some View {
        HStack(spacing: 0) {
            ForEach(camera.lenses.filter { $0.isFront == camera.isFrontCamera }) { lens in
                Button {
                    camera.selectLens(id: lens.id)
                } label: {
                    Text(lens.title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(camera.currentLensID == lens.id ? .black : .white)
                        .frame(minWidth: 42, minHeight: 40)
                        .background {
                            if camera.currentLensID == lens.id { Circle().fill(.white).padding(3) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lens.title) camera")
                .accessibilityAddTraits(camera.currentLensID == lens.id ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 3)
        .background(.black.opacity(0.5), in: Capsule())
        .disabled(camera.isCapturing || model.countdown != nil)
    }

    private var controlShortcuts: some View {
        HStack(spacing: 0) {
            Button {
                present(.exposure)
            } label: {
                shortcutLabel("EV", value: String(format: "%+.1f", camera.exposure), symbol: "plusminus.circle")
                    .frame(maxWidth: .infinity, minHeight: shortcutHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Exposure compensation")
            .accessibilityValue(String(format: "%+.1f EV", camera.exposure))
            .disabled(!camera.isRunning || camera.exposureBounds.lowerBound == camera.exposureBounds.upperBound)
            Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 18)
            Button { present(.whiteBalance) } label: {
                shortcutLabel("WB", value: whiteBalanceTitle, symbol: "sun.max")
                    .frame(maxWidth: .infinity, minHeight: shortcutHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("White balance")
            .accessibilityValue(whiteBalanceTitle)
            .disabled(!camera.isRunning)
            Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 18)
            Button { setDiffusionVisible(!showsDiffusion) } label: {
                diffusionShortcut
                    .frame(maxWidth: .infinity, minHeight: shortcutHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Diffusion filters")
            .accessibilityValue(diffusionAccessibilityValue)
            .accessibilityHint(showsDiffusion ? "Closes filter controls" : "Opens filter controls")
            .accessibilityIdentifier("diffusion.toggle")
            .disabled(model.isApplyingLook)
        }
        .font(.footnote)
        .frame(height: shortcutHeight)
        .buttonStyle(.plain)
        .disabled(model.countdown != nil || camera.isCapturing)
        .overlay(alignment: .bottom) { Divider().overlay(.white.opacity(0.08)) }
    }

    private var whiteBalanceTitle: String {
        switch camera.whiteBalance {
        case .auto: return "Auto"
        case .locked: return "Lock"
        case .manual(let temperature, _): return "\(Int(temperature)) K"
        }
    }

    private func shortcutLabel(_ title: String, value: String, symbol: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Label("\(title) \(value)", systemImage: symbol).fixedSize()
            Text("\(title) \(value)").fixedSize()
            VStack(spacing: 0) {
                Text(title)
                Text(value)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
    }

    private var diffusionShortcut: some View {
        let name = model.diffusion.effect == .hdf ? "HDF" : "Mist"
        let percentage = "\(Int((model.diffusion.strength * 100).rounded()))%"
        return HStack(spacing: 4) {
            if model.diffusion.effect == .hdf {
                Circle().fill(model.diffusion.glowColor.displayColor)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            if model.diffusion.effect == .off {
                ViewThatFits(in: .horizontal) {
                    Label("Filters Off", systemImage: "camera.filters").fixedSize()
                    Text("Filters Off").fixedSize()
                    VStack(spacing: 0) {
                        Text("Filters")
                        Text("Off")
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    Text("\(name) \(percentage)").fixedSize()
                    VStack(spacing: 0) {
                        Text(name)
                        Text(percentage)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
            Image(systemName: showsDiffusion ? "chevron.down" : "chevron.up")
                .font(.system(size: 9, weight: .semibold))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 4)
    }

    private var diffusionAccessibilityValue: String {
        guard model.diffusion.effect != .off else { return "Off" }
        let percentage = Int((model.diffusion.strength * 100).rounded())
        let effect = "\(model.diffusion.effect.displayName), \(percentage)%"
        return model.diffusion.effect == .hdf ? "\(effect), \(model.diffusion.glowColor.label)" : effect
    }

    private func setDiffusionVisible(_ visible: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            showsDiffusion = visible
        }
    }

    private func present(_ destination: CameraSheet) {
        showsDiffusion = false
        sheet = destination
    }

    private var lookStrip: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "rectangle.on.rectangle", label: "Your looks") {
                model.cancelCountdown()
                present(.looks)
            }
            Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 54)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(model.lookItems) { item in
                            Button {
                                model.triggerHaptic()
                                Task {
                                    await model.select(item.id)
                                }
                            } label: {
                                FilterLabelView(label: item.label, selected: model.selection == item.id, compact: true)
                                    .frame(width: 73, height: 79)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("camera.look.\(item.id.id)")
                            .id(item.id)
                        }
                    }
                    .padding(.trailing, 12)
                }
                .accessibilityIdentifier("camera.lookStrip")
                .onChange(of: model.selection) { _, selection in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo(selection, anchor: .center) }
                }
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
        .disabled(model.countdown != nil || camera.isCapturing)
    }

    private var intensityControl: some View {
        HStack(spacing: 12) {
            Text("Look intensity").font(.caption).lineLimit(1).minimumScaleFactor(0.7)
            Slider(value: Binding(get: { model.intensity }, set: model.setIntensity), in: 0...1) { editing in
                if !editing { model.persistCurrentIntensity() }
            }
            .accessibilityLabel("Look intensity")
            .accessibilityValue("\(Int(model.intensity * 100)) percent")
            .accessibilityIdentifier("camera.lookIntensity")
            Text("\(Int(model.intensity * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: intensityHeight)
        .disabled(model.selection == .builtIn(.original) || model.isApplyingLook || model.countdown != nil || camera.isCapturing)
    }

    private var captureControls: some View {
        HStack {
            Button { present(.review) } label: {
                Group {
                    if let photo = camera.latestCapture {
                        Image(decorative: photo.image, scale: 1).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").font(.title3).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(LutliTheme.secondary).background(LutliTheme.surface)
                    }
                }
                .frame(width: 44, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(camera.latestCapture == nil)
            .accessibilityLabel("Review last photo")
            Spacer()
            Button { model.capture() } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 2).frame(width: 71, height: 71)
                    if camera.isCapturing || camera.isSaving {
                        ProgressView().tint(.white)
                    } else if model.countdown != nil {
                        Image(systemName: "xmark").font(.title2)
                    } else {
                        Circle().fill(.white).frame(width: 61, height: 61)
                    }
                }
                .frame(width: 80, height: 80)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.countdown != nil ? "Cancel timer" : "Take photo")
            .accessibilityIdentifier("camera.shutter")
            .disabled(!camera.isRunning || camera.isCapturing || camera.isSaving || model.isApplyingLook || model.isLoadingLibrary)
            .opacity(camera.isRunning ? 1 : 0.4)
            Spacer()
            IconButton(systemName: "arrow.triangle.2.circlepath.camera", label: "Switch camera") {
                camera.switchCamera()
            }
            .disabled(!camera.isRunning || camera.isCapturing || model.countdown != nil)
        }
        .padding(.horizontal, 22)
        .frame(height: 82)
    }
}

struct PreviewSurface: View {
    let image: CGImage?
    var grid = false
    var onTap: ((CGPoint) -> Void)?
    @State private var focusPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                    if grid {
                        let bounds = fittedRect(image: image, size: geometry.size)
                        RuleOfThirdsGrid()
                            .frame(width: bounds.width, height: bounds.height)
                            .position(x: bounds.midX, y: bounds.midY)
                            .allowsHitTesting(false)
                    }
                }
                if let focusPoint {
                    RoundedRectangle(cornerRadius: 3).stroke(.white, lineWidth: 1)
                        .frame(width: 58, height: 58)
                        .position(focusPoint)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { event in
                guard let image, let onTap else { return }
                let bounds = fittedRect(image: image, size: geometry.size)
                guard bounds.contains(event.location) else { return }
                onTap(CGPoint(x: (event.location.x - bounds.minX) / bounds.width, y: (event.location.y - bounds.minY) / bounds.height))
                focusPoint = event.location
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    if focusPoint == event.location { focusPoint = nil }
                }
            })
        }
        .clipped()
        .accessibilityLabel("Live camera preview")
        .accessibilityHint(onTap == nil ? "" : "Tap the preview to set focus and metering")
    }

    private func fittedRect(image: CGImage, size: CGSize) -> CGRect {
        let ratio = min(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        let width = CGFloat(image.width) * ratio
        let height = CGFloat(image.height) * ratio
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

private struct RuleOfThirdsGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                for fraction in [1.0 / 3, 2.0 / 3] {
                    let x = geometry.size.width * fraction
                    let y = geometry.size.height * fraction
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.4), lineWidth: 0.5)
        }
    }
}
