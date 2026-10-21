import SwiftUI
import UIKit

struct ExposureControlsView: View {
    @EnvironmentObject private var camera: CameraController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Exposure compensation")
                    Spacer()
                    Text(String(format: "%+.1f EV", camera.exposure)).monospacedDigit()
                }
                if camera.exposureBounds.lowerBound < camera.exposureBounds.upperBound {
                    Slider(value: Binding(get: { camera.exposure }, set: camera.setExposure), in: camera.exposureBounds, step: 0.1)
                        .accessibilityLabel("Exposure compensation")
                    HStack {
                        Text(String(format: "%+.1f", camera.exposureBounds.lowerBound))
                        Spacer()
                        Text(String(format: "%+.1f", camera.exposureBounds.upperBound))
                    }
                    .font(.caption)
                    .foregroundStyle(LutliTheme.secondary)
                } else {
                    Text("Exposure compensation is unavailable for the current camera.")
                        .foregroundStyle(LutliTheme.secondary)
                }
                Text("Adjusts automatic exposure. Applies to all looks during this session.")
                    .font(.footnote)
                    .foregroundStyle(LutliTheme.secondary)
                Button("Reset to 0 EV") { camera.setExposure(0) }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(!camera.isRunning)
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(LutliTheme.background)
            .navigationTitle("Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.height(340), .medium])
        .presentationDragIndicator(.visible)
    }
}

struct WhiteBalanceControlsView: View {
    @EnvironmentObject private var camera: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var temperature = 5_200.0
    @State private var tint = 0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 8) {
                        modeButton("Auto", selected: camera.whiteBalance == .auto, available: true) { camera.setWhiteBalance(.auto) }
                        modeButton("Lock", selected: camera.whiteBalance == .locked, available: camera.supportsWhiteBalanceLock) { camera.setWhiteBalance(.locked) }
                        modeButton("Manual", selected: isManual, available: camera.supportsManualWhiteBalance) { applyManual() }
                    }
                    adjustment("Temperature", value: "\(Int(temperature)) K") {
                        Slider(value: $temperature, in: 2_000...10_000, step: 50)
                            .accessibilityLabel("White-balance temperature in Kelvin")
                            .onChange(of: temperature) { _, _ in applyManual() }
                    }
                    adjustment("Tint", value: String(format: "%+.0f", tint)) {
                        Slider(value: $tint, in: -100...100, step: 1)
                            .accessibilityLabel("White-balance tint")
                            .onChange(of: tint) { _, _ in applyManual() }
                    }
                    Text(camera.supportsManualWhiteBalance ? "Moving a slider selects Manual. White balance applies to all looks during this session." : "Manual white balance is unavailable for this camera.")
                        .font(.footnote)
                        .foregroundStyle(LutliTheme.secondary)
                    Button("Reset to Auto") { camera.setWhiteBalance(.auto) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(24)
            }
            .background(LutliTheme.background)
            .navigationTitle("White balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                if case .manual(let kelvin, let shift) = camera.whiteBalance {
                    temperature = Double(kelvin)
                    tint = Double(shift)
                }
            }
        }
        .presentationDetents([.height(460), .large])
        .presentationDragIndicator(.visible)
    }

    private var isManual: Bool {
        if case .manual = camera.whiteBalance { return true }
        return false
    }

    private func applyManual() {
        guard camera.supportsManualWhiteBalance else { return }
        camera.setWhiteBalance(.manual(temperature: Float(temperature), tint: Float(tint)))
    }

    private func modeButton(_ name: String, selected: Bool, available: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.white : LutliTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? .black : .white)
        }
        .buttonStyle(.plain)
        .disabled(!available || !camera.isRunning)
        .opacity(available ? 1 : 0.35)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func adjustment<Content: View>(_ title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            HStack { Text(title); Spacer(); Text(value).monospacedDigit() }
            content()
        }
        .font(.subheadline)
        .disabled(!camera.supportsManualWhiteBalance || !camera.isRunning)
        .opacity(camera.supportsManualWhiteBalance ? 1 : 0.35)
    }
}

struct CaptureReviewView: View {
    let photo: CapturedPhoto
    @EnvironmentObject private var camera: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginal = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if showOriginal, let data = photo.originalJPEG, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Image(decorative: photo.image, scale: 1).resizable().scaledToFit()
                    }
                }
                .accessibilityLabel(showOriginal ? "Unfiltered original" : "Filtered photo")
                if photo.originalJPEG != nil {
                    Toggle("Show unfiltered original", isOn: $showOriginal)
                        .padding(.horizontal)
                }
                saveStatus
                Button { showShare = true } label: {
                    Label("Share photo", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(QuietPrimaryButton())
                .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .padding(.vertical)
            .background(LutliTheme.background)
            .navigationTitle("Last photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showShare) { ShareSheet(items: [shareImage]) }
        }
    }

    private var shareImage: UIImage {
        if showOriginal, let original = photo.originalJPEG, let image = UIImage(data: original) { return image }
        return UIImage(data: photo.filteredJPEG) ?? UIImage(cgImage: photo.image)
    }

    @ViewBuilder
    private var saveStatus: some View {
        if let status = camera.photoSaveStatus, status.photoID == photo.id {
            switch status.phase {
            case .saving:
                ProgressView("Saving to Photos…").font(.footnote)
            case .saved:
                Label("Saved to Photos", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(LutliTheme.secondary)
            case .failed(let message, let needsPermission):
                VStack(spacing: 10) {
                    Label("Not saved to Photos", systemImage: "exclamationmark.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(LutliTheme.secondary)
                        .multilineTextAlignment(.center)
                    Text("Your photo is still available here to share.")
                        .font(.footnote)
                        .foregroundStyle(LutliTheme.secondary)
                    HStack(spacing: 18) {
                        if needsPermission {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                        Button("Try saving again") { camera.retrySaveLatestCapture() }
                            .disabled(camera.isSaving || camera.isCapturing || camera.latestCapture?.id != photo.id)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
                .padding(.horizontal)
            }
        }
    }
}
