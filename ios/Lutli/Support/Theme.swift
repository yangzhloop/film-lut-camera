import LutliCore
import SwiftUI
import UIKit

enum LutliTheme {
    static let background = Color(red: 0.065, green: 0.065, blue: 0.065)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let secondary = Color.white.opacity(0.62)
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(clean, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}

struct FilterLabelView: View {
    let label: FilterLabel
    var selected = false
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            section(label.topText, color: label.topColor)
            section(label.bottomText, color: label.bottomColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 5 : 8))
        // Reserve the same outline space for every card so selection never resizes a label.
        .padding(4)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: compact ? 8 : 11).stroke(.white, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.topText), \(label.bottomText)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func section(_ title: String, color: LabelColor) -> some View {
        Text(title)
            .font(.system(size: compact ? 15 : 24, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(Color(hex: color.foregroundHex))
            .padding(.horizontal, compact ? 4 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: color.hex))
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QuietPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.black)
            .background(.white.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
