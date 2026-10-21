import SwiftUI
import UIKit

struct AppMenuView: View {
    @EnvironmentObject private var model: LutliAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    NavigationLink {
                        CameraSavingSettingsView()
                    } label: {
                        menuLabel("Camera & saving", symbol: "camera")
                    }
                    NavigationLink {
                        AppPreferencesView()
                    } label: {
                        menuLabel("App preferences", symbol: "slider.horizontal.3")
                    }
                }
                .listRowBackground(LutliTheme.surface)

                Section("Support") {
                    NavigationLink {
                        LutliFeedbackView()
                    } label: {
                        menuLabel("Send feedback", symbol: "bubble.left")
                    }
                    NavigationLink {
                        AboutLutliView()
                    } label: {
                        menuLabel("About Lutli", symbol: "info.circle")
                    }
                }
                .listRowBackground(LutliTheme.surface)

                Section("Legal") {
                    NavigationLink {
                        LutliTermsView()
                    } label: {
                        menuLabel("Terms & conditions", symbol: "doc.text")
                    }
                    NavigationLink {
                        LutliPrivacyView()
                    } label: {
                        menuLabel("Privacy policy", symbol: "hand.raised")
                    }
                }
                .listRowBackground(LutliTheme.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LutliTheme.background)
            .foregroundStyle(.white)
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close app menu")
                }
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func menuLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .frame(minHeight: 44)
    }
}

private struct CameraSavingSettingsView: View {
    @EnvironmentObject private var model: LutliAppModel

    var body: some View {
        Form {
            Section {
                Toggle("Save clean original too", isOn: $model.saveOriginal)
                    .tint(Color(white: 0.45))
            } footer: {
                Text("Saves a second JPEG without the creative look. This is a processed photograph, not a RAW file.")
            }
            .listRowBackground(LutliTheme.surface)

            Section("Composition") {
                Toggle("Show grid", isOn: $model.showGrid)
                    .tint(Color(white: 0.45))
                Picker("Shutter timer", selection: $model.timerSeconds) {
                    Text("Off").tag(0)
                    Text("3 seconds").tag(3)
                    Text("10 seconds").tag(10)
                }
                .accessibilityHint("Waits before taking a photo after you press the shutter")
            }
            .listRowBackground(LutliTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(LutliTheme.background)
        .navigationTitle("Camera & saving")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppPreferencesView: View {
    @EnvironmentObject private var model: LutliAppModel

    var body: some View {
        Form {
            Section {
                Toggle("Remember last look", isOn: $model.rememberLastLook)
                    .tint(Color(white: 0.45))
            } footer: {
                Text("Reopens the camera with the last selected look. When off, the camera starts with Original.")
            }
            .listRowBackground(LutliTheme.surface)

            Section {
                Toggle("Haptic feedback", isOn: $model.haptics)
                    .tint(Color(white: 0.45))
            } footer: {
                Text("Adds a light tap when selecting a look or taking a photo on supported devices.")
            }
            .listRowBackground(LutliTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(LutliTheme.background)
        .navigationTitle("App preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LutliFeedbackView: View {
    @State private var feedback = ""
    @State private var showingShareSheet = false

    var body: some View {
        Form {
            Section {
                Text("Tell us what worked, what felt confusing, or what you would change.")
                    .foregroundStyle(LutliTheme.secondary)
                TextEditor(text: $feedback)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Feedback message")
            }
            .listRowBackground(LutliTheme.surface)

            Section {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share feedback", systemImage: "square.and.arrow.up")
                        .frame(minHeight: 44)
                }
                .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Choose where to send it in the iOS share sheet. Only your message, the app version, and the iOS version are included. Opening this page sends nothing.")
            }
            .listRowBackground(LutliTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(LutliTheme.background)
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [feedbackPayload])
        }
    }

    private var feedbackPayload: String {
        """
        Lutli feedback

        \(feedback.trimmingCharacters(in: .whitespacesAndNewlines))

        App: \(LutliMenuVersion.description)
        iOS: \(UIDevice.current.systemVersion)
        """
    }
}

private struct AboutLutliView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("lutli")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .accessibilityLabel("Lutli")
                Text("Film-inspired color, ready when you shoot.")
                    .font(.title3)
                MenuInformationBlock(
                    title: "Developer preview",
                    text: "Explore live LUT looks, import your own compatible color looks, and make each one recognizable with a custom two-color label. The original starter looks in this preview are still being tuned."
                )
                MenuInformationBlock(
                    title: "Your labels, your names",
                    text: "The words and numbers on a filter label identify its look. A label such as 400 does not set the camera’s ISO."
                )
                Text(LutliMenuVersion.description)
                    .font(.footnote)
                    .foregroundStyle(LutliTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(LutliTheme.background)
        .navigationTitle("About Lutli")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LutliTermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Pre-release information")
                    .font(.title2.weight(.semibold))
                Text("Lutli is currently a developer preview. Final terms for a public release are not available in this build.")
                Text("This page is a placeholder for the release terms and does not represent a finalized agreement. Release terms will be provided before public distribution.")
                    .foregroundStyle(LutliTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(LutliTheme.background)
        .navigationTitle("Terms & conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LutliPrivacyView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy in this preview")
                    .font(.title2.weight(.semibold))
                Text("This describes the current developer preview. The privacy policy for public release is still pending.")
                    .foregroundStyle(LutliTheme.secondary)
                MenuInformationBlock(
                    title: "Camera and photo access",
                    text: "Camera access enables the live view and photo capture. Photos add-only permission lets Lutli save new photographs to your library."
                )
                MenuInformationBlock(
                    title: "Looks stay on your device",
                    text: "Imported LUTs, their labels, and app preferences are stored locally. This preview has no account system, analytics, or cloud synchronization."
                )
                MenuInformationBlock(
                    title: "Sharing is your choice",
                    text: "Photos and feedback leave the app when you choose a destination in the iOS share sheet. Feedback contains the message you write, the app version, and the iOS version. Camera images and imported LUTs are not attached to feedback."
                )
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Manage permissions in Settings", systemImage: "arrow.up.forward.app")
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(LutliTheme.background)
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MenuInformationBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .foregroundStyle(LutliTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum LutliMenuVersion {
    static var description: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Version \(version) (\(build)) · Developer preview"
        }
        return "Version \(version) · Developer preview"
    }
}
