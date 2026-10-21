import LutliCore
import SwiftUI

struct FilterLabelEditor: View {
    let draft: LabelEditorDraft
    @EnvironmentObject private var model: LutliAppModel
    @EnvironmentObject private var camera: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var topText: String
    @State private var bottomText: String
    @State private var topColor: LabelColor
    @State private var bottomColor: LabelColor
    @State private var showsLivePreview = false
    @State private var draftLUT: CubeLUT?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDiscard = false
    @FocusState private var focusedField: TextField?

    private enum TextField: Hashable { case top, bottom }

    init(draft: LabelEditorDraft) {
        self.draft = draft
        _topText = State(initialValue: draft.label.topText)
        _bottomText = State(initialValue: draft.label.bottomText)
        _topColor = State(initialValue: draft.label.topColor)
        _bottomColor = State(initialValue: draft.label.bottomColor)
    }

    private var label: FilterLabel {
        FilterLabel(topText: topText, bottomText: bottomText, topColor: topColor, bottomColor: bottomColor)
    }

    private var hasChanges: Bool { label != draft.label }

    private var isValid: Bool { (try? label.validated()) != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    FilterLabelView(label: label)
                        .frame(width: 208, height: 150)
                        .padding(.top, 10)
                    if draftLUT != nil {
                        DisclosureGroup("Preview look on camera", isExpanded: $showsLivePreview) {
                            if camera.isRunning {
                                PreviewSurface(image: camera.previewImage)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.top, 10)
                            } else {
                                Text("A live camera is needed to preview the imported look. Your label can still be saved.")
                                    .font(.footnote)
                                    .foregroundStyle(LutliTheme.secondary)
                                    .padding(.top, 8)
                            }
                        }
                        .font(.subheadline)
                    }
                    textAndColorSection(title: "Top", text: $topText, color: $topColor, field: .top)
                    Divider()
                    textAndColorSection(title: "Bottom", text: $bottomText, color: $bottomColor, field: .bottom)
                    Text("Both sections can contain words or numbers. Label text does not change camera settings.")
                        .font(.caption)
                        .foregroundStyle(LutliTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(isSaving)
            .background(LutliTheme.background)
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard !isSaving, isValid else { return }
                    let savedLabel = label
                    isSaving = true
                    focusedField = nil
                    Task {
                        defer { isSaving = false }
                        do {
                            try await model.saveLabel(savedLabel, draft: draft)
                            model.triggerHaptic()
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }
                } label: {
                    Group {
                        if isSaving { ProgressView().tint(.black) }
                        else { Text("Save filter") }
                    }
                }
                .buttonStyle(QuietPrimaryButton())
                .disabled(!isValid || isSaving)
                .opacity(isValid ? 1 : 0.45)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(LutliTheme.background)
            }
            .navigationTitle("Customize label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showDiscard = true }
                        else { dismiss() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .task {
                do { draftLUT = try await model.previewLUT(for: draft) }
                catch { errorMessage = error.localizedDescription }
            }
            .onChange(of: showsLivePreview) { _, visible in
                if visible, let draftLUT { camera.setLUT(draftLUT) }
                else { model.restoreSelectedPreview() }
            }
            .onDisappear { model.restoreSelectedPreview() }
            .interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog("Discard label changes?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Your saved collection will not change.")
            }
            .alert("Could not save this look", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Please try again.") }
        }
    }

    private func textAndColorSection(title: String, text: Binding<String>, color: Binding<LabelColor>, field: TextField) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(title) text").font(.subheadline)
                Spacer()
                Text("\(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(FilterLabel.maxTextLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(validationMessage(for: text.wrappedValue) != nil ? .red : LutliTheme.secondary)
            }
            SwiftUI.TextField(title == "Top" ? "DAYLIGHT" : "400", text: text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(field == .top ? .next : .done)
                .focused($focusedField, equals: field)
                .onSubmit { focusedField = field == .top ? .bottom : nil }
                .padding(14)
                .background(LutliTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15), lineWidth: 1) }
                .accessibilityLabel("\(title) label text")
            if let message = validationMessage(for: text.wrappedValue) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("\(title) text: \(message)")
            }
            Text("\(title) color").font(.subheadline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(LabelColor.allCases, id: \.rawValue) { item in
                    Button { color.wrappedValue = item } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: item.hex))
                            .frame(height: 44)
                            .padding(3)
                            .overlay {
                                if item == color.wrappedValue {
                                    RoundedRectangle(cornerRadius: 9).stroke(.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) color, \(item.rawValue)")
                    .accessibilityAddTraits(item == color.wrappedValue ? [.isSelected] : [])
                }
            }
        }
    }

    private func validationMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter a word or number for this section." }
        if trimmed.count > FilterLabel.maxTextLength { return "Use \(FilterLabel.maxTextLength) characters or fewer." }
        let forbidden = CharacterSet.controlCharacters.union(.newlines)
        if trimmed.unicodeScalars.contains(where: { forbidden.contains($0) }) { return "Use one line of text." }
        return nil
    }
}
