import LutliCore
import SwiftUI
import UIKit

/// A bounded overlay: its height changes without participating in camera layout.
struct DiffusionControlsView: View {
    let maximumHeight: CGFloat
    let close: () -> Void
    @EnvironmentObject private var model: LutliAppModel
    @EnvironmentObject private var camera: CameraController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var strengthHeight: CGFloat = 78
    @ScaledMetric(relativeTo: .body) private var glowHeight: CGFloat = 82

    private var preferredHeight: CGFloat {
        56 + (model.diffusion.effect == .off ? 0 : strengthHeight)
            + (model.diffusion.effect == .hdf ? glowHeight : 0)
    }

    private var adjustmentsDisabled: Bool {
        camera.isCapturing || model.countdown != nil || model.isApplyingLook
    }

    var body: some View {
        VStack(spacing: 0) {
            // Selection and Close remain reachable while larger detail rows
            // scroll within the preview on small phones or with large text.
            choices
                .padding(.vertical, 6)
                .fixedSize(horizontal: false, vertical: true)
            if model.diffusion.effect != .off {
                ScrollView(.vertical) {
                    VStack(spacing: 4) {
                        strength
                        if model.diffusion.effect == .hdf { glowColors }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .disabled(adjustmentsDisabled)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("diffusion.details")
            }
        }
        .frame(height: max(0, min(maximumHeight, preferredHeight)))
        .frame(maxWidth: .infinity)
        .background {
            // An opaque hit surface prevents empty tray space from dismissing
            // the tray or focusing the camera beneath it.
            Rectangle()
                .fill(LutliTheme.background.opacity(0.96))
                .contentShape(Rectangle())
                .onTapGesture {}
        }
        .overlay(alignment: .top) { Divider().overlay(.white.opacity(0.18)) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.diffusion.effect)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("diffusion.tray")
    }

    private var choices: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(DiffusionEffect.allCases, id: \.rawValue) { effect in
                            Button {
                                model.selectDiffusion(effect)
                                model.triggerHaptic()
                            } label: {
                                Text(effect.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .background {
                                        if effect == model.diffusion.effect {
                                            Capsule().stroke(.white, lineWidth: 1).padding(.vertical, 4)
                                        }
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(effect.rawValue)
                            .accessibilityLabel(effect == .off ? "Diffusion off" : effect.displayName)
                            .accessibilityIdentifier("diffusion.effect.\(effect.rawValue)")
                            .accessibilityAddTraits(effect == model.diffusion.effect ? [.isSelected] : [])
                        }
                    }
                    .padding(.leading, 6)
                }
                .disabled(adjustmentsDisabled)
                .onChange(of: model.diffusion.effect) { _, effect in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        proxy.scrollTo(effect.rawValue, anchor: .center)
                    }
                }
            }
            IconButton(systemName: "xmark", label: "Close diffusion controls", action: close)
                .accessibilityIdentifier("diffusion.close")
        }
        .padding(.trailing, 6)
    }

    private var strength: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Strength")
                Spacer()
                Text("\(Int((model.diffusion.strength * 100).rounded()))%")
                    .monospacedDigit()
                    .accessibilityIdentifier("diffusion.strengthValue")
            }
            .font(.subheadline)
            Slider(value: Binding(get: { model.diffusion.strength }, set: model.setDiffusionStrength), in: 0...1)
                .frame(minHeight: 44)
                .accessibilityLabel("\(model.diffusion.effect.displayName) filter strength")
                .accessibilityValue("\(Int((model.diffusion.strength * 100).rounded())) percent")
                .accessibilityIdentifier("diffusion.strength")
        }
    }

    private var glowColors: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Glow color")
                Spacer()
                Text(model.diffusion.glowColor.label)
                    .foregroundStyle(LutliTheme.secondary)
                    .accessibilityIdentifier("diffusion.colorName")
            }
            .font(.subheadline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GlowColor.presets, id: \.label) { color in
                        Button { model.setDiffusionGlowColor(color) } label: {
                            glowSwatch(color: color, selected: model.diffusion.glowColor == color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(color.label) glow")
                        .accessibilityIdentifier("diffusion.color.\(color.label.lowercased())")
                        .accessibilityAddTraits(model.diffusion.glowColor == color ? [.isSelected] : [])
                    }
                    customColorPicker
                }
            }
            .accessibilityIdentifier("diffusion.colors")
        }
        .padding(.bottom, 6)
    }

    private func glowSwatch(color: GlowColor, selected: Bool) -> some View {
        ZStack {
            Circle().fill(color.displayColor).frame(width: 28, height: 28)
            if selected {
                Circle().stroke(.white, lineWidth: 1.5).frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color.checkmarkColor)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private var customColorPicker: some View {
        ColorPicker("Custom glow color", selection: Binding(
            get: { model.diffusion.glowColor.displayColor },
            set: { value in
                guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                      let color = UIColor(value).cgColor.converted(to: space, intent: .defaultIntent, options: nil),
                      let components = color.components, components.count >= 3 else { return }
                model.setDiffusionGlowColor(.custom(RGBColor(
                    red: Double(components[0]), green: Double(components[1]), blue: Double(components[2])
                )))
            }
        ), supportsOpacity: false)
        .labelsHidden()
        .frame(width: 44, height: 44)
        .overlay {
            if case .custom = model.diffusion.glowColor {
                Circle().stroke(.white, lineWidth: 1.5).frame(width: 38, height: 38)
                    .allowsHitTesting(false)
            }
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(model.diffusion.glowColor.checkmarkColor)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Custom glow color")
        .accessibilityValue(model.diffusion.glowColor.label)
        .accessibilityIdentifier("diffusion.color.custom")
        .accessibilityAddTraits(isCustomColor ? [.isSelected] : [])
    }

    private var isCustomColor: Bool {
        if case .custom = model.diffusion.glowColor { return true }
        return false
    }
}

extension DiffusionEffect {
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .hdf: return "HDF"
        case .blackMist: return "Black Mist"
        }
    }
}

extension GlowColor {
    var displayColor: Color {
        guard let rgb else { return Color(hex: "EFE6CC") }
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    var checkmarkColor: Color {
        guard let rgb else { return .black }
        return 0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue > 0.5 ? .black : .white
    }
}
