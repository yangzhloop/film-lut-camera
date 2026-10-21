import LutliCore
import SwiftUI
import UniformTypeIdentifiers

struct LooksLibraryView: View {
    @EnvironmentObject private var model: LutliAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var collection: Collection = .custom
    @State private var editor: LabelEditorDraft?
    @State private var showsImporter = false
    @State private var importPurpose: ImportPurpose = .new
    @State private var deleteCandidate: CustomLook?
    @State private var isBusy = false
    @State private var errorMessage: String?

    private enum Collection: String, CaseIterable, Identifiable {
        case builtIn = "Built-in"
        case custom = "My LUTs"
        var id: String { rawValue }
    }

    private enum ImportPurpose {
        case new
        case replace(UUID)
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabs
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if collection == .custom {
                            customCollection
                        } else {
                            builtInCollection
                        }
                    }
                    .padding(20)
                }
                if collection == .custom { importFooter }
            }
            .background(LutliTheme.background)
            .navigationTitle("Your looks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Camera", systemImage: "chevron.left") }
                }
            }
            .overlay {
                if isBusy {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView("Preparing your look…")
                            .padding(24)
                            .background(LutliTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .sheet(item: $editor) { draft in FilterLabelEditor(draft: draft) }
            .fileImporter(isPresented: $showsImporter, allowedContentTypes: [UTType(filenameExtension: "cube") ?? .data], allowsMultipleSelection: false) { result in
                receiveImport(result)
            }
            .confirmationDialog("Delete this look?", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ), titleVisibility: .visible, presenting: deleteCandidate) { look in
                Button("Delete look", role: .destructive) {
                    Task {
                        do { try await model.deleteLook(id: look.id) }
                        catch { errorMessage = error.localizedDescription }
                        deleteCandidate = nil
                    }
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            } message: { _ in
                Text("Its saved LUT and label will be removed from Lutli. The original imported file is not changed.")
            }
            .alert("Could not update your looks", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Please try again.") }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Collection.allCases) { item in
                Button { collection = item } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(collection == item ? .semibold : .regular))
                        .foregroundStyle(collection == item ? Color.white : LutliTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(collection == item ? Color.white : .clear).frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(collection == item ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var customCollection: some View {
        Text("\(model.customLooks.count) of \(model.customLookLimit) slots used")
            .font(.footnote)
            .foregroundStyle(LutliTheme.secondary)
        if model.isLoadingLibrary {
            ProgressView("Opening your looks…").frame(maxWidth: .infinity)
        } else if model.libraryIssue != nil {
            ContentUnavailableView {
                Label("Your looks are unavailable", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("Existing files have been preserved. Built-in looks are still available.")
            }
        } else {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(model.customLooks) { look in
                    VStack(spacing: 4) {
                        Button {
                            model.triggerHaptic()
                            Task {
                                await model.select(.custom(look.id))
                                dismiss()
                            }
                        } label: {
                            FilterLabelView(label: look.label, selected: model.selection == .custom(look.id))
                                .aspectRatio(1.25, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        HStack {
                            Spacer()
                            Menu {
                                Button("Edit label", systemImage: "pencil") {
                                    editor = LabelEditorDraft(purpose: .edit(id: look.id), label: look.label)
                                }
                                Button("Replace LUT", systemImage: "arrow.triangle.2.circlepath") {
                                    importPurpose = .replace(look.id)
                                    showsImporter = true
                                }
                                Button("Delete look", systemImage: "trash", role: .destructive) {
                                    deleteCandidate = look
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Manage \(look.label.topText) \(look.label.bottomText)")
                        }
                    }
                }
                if model.canImport { importTile }
            }
            if model.customLooks.isEmpty {
                Text("Bring your own color. Import a compatible .cube LUT, then give it a label.")
                    .font(.subheadline)
                    .foregroundStyle(LutliTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var builtInCollection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Original color studies for everyday shooting.")
                .font(.footnote)
                .foregroundStyle(LutliTheme.secondary)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(BuiltInLook.allCases, id: \.rawValue) { look in
                    Button {
                        model.triggerHaptic()
                        Task {
                            await model.select(.builtIn(look))
                            dismiss()
                        }
                    } label: {
                        FilterLabelView(label: look.label, selected: model.selection == .builtIn(look))
                            .aspectRatio(1.25, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var importTile: some View {
        Button {
            importPurpose = .new
            showsImporter = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle").font(.system(size: 29, weight: .light))
                Text("Import LUT").font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.25, contentMode: .fit)
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4])) }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 40)
    }

    private var importFooter: some View {
        VStack(spacing: 12) {
            Text(model.customLooks.count < model.customLookLimit
                 ? "\(model.customLookLimit - model.customLooks.count) slots available"
                 : "Replace or delete a look to import another.")
                .font(.footnote)
                .foregroundStyle(LutliTheme.secondary)
            Button {
                importPurpose = .new
                showsImporter = true
            } label: {
                Text("Import .cube")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(model.canImport ? 1 : 0.3), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(!model.canImport)
            Text("3D LUTs · 17 or 33 points · SDR sRGB · up to 8 MB")
                .font(.caption2)
                .foregroundStyle(LutliTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }

    private func receiveImport(_ result: Result<[URL], Error>) {
        let purpose = importPurpose
        Task {
            do {
                guard let url = try result.get().first else { return }
                isBusy = true
                defer { isBusy = false }
                switch purpose {
                case .new:
                    editor = try await model.importedDraft(from: url)
                case .replace(let id):
                    try await model.replaceLook(id: id, from: url)
                }
            } catch {
                if (error as NSError).code != NSUserCancelledError { errorMessage = error.localizedDescription }
            }
        }
    }
}
