//
//  FolderManagerSheet.swift
//  mqtee
//

import SwiftUI

struct FolderManagerSheet: View {
    @Bindable var store: ConnectionStore
    @Environment(\.dismiss) private var dismiss

    @State private var newFolderName = ""
    @State private var newFolderColor: FolderColor = .blue
    @State private var renamingFolderId: UUID?
    @State private var renamingFolderName: String = ""

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macOSBody: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(width: 400, height: 450)
    }

    private var header: some View {
        HStack {
            Text("Folders")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.sortedFolders) { folder in
                    folderRow(folder)
                }

                if !store.sortedFolders.isEmpty {
                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("New Folder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Folder name", text: $newFolderName)

                    colorPicker(selection: $newFolderColor)

                    Button("Add Folder") {
                        addFolder()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    #endif

    // MARK: - iOS Body

    #if !os(macOS)
    private var iOSBody: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sortedFolders) { folder in
                        folderRow(folder)
                    }
                }

                Section {
                    TextField("Folder name", text: $newFolderName)

                    colorPicker(selection: $newFolderColor)

                    Button("Add Folder") {
                        addFolder()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("New Folder")
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    #endif

    // MARK: - Folder Row

    @ViewBuilder
    private func folderRow(_ folder: ConnectionFolder) -> some View {
        if renamingFolderId == folder.id {
            HStack(spacing: 8) {
                Circle()
                    .fill(folder.color.color)
                    .frame(width: 12, height: 12)

                TextField("Folder name", text: $renamingFolderName)
                    .onSubmit { commitRename(folder) }

                Button {
                    commitRename(folder)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button {
                    renamingFolderId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 8) {
                Circle()
                    .fill(folder.color.color)
                    .frame(width: 12, height: 12)

                Text(folder.name)

                Spacer()

                Menu {
                    Button {
                        renamingFolderName = folder.name
                        renamingFolderId = folder.id
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Menu("Color") {
                        ForEach(FolderColor.allCases, id: \.self) { color in
                            Button {
                                var updated = folder
                                updated.color = color
                                store.updateFolder(updated)
                            } label: {
                                HStack {
                                    Image(systemName: folder.color == color ? "checkmark.circle.fill" : "circle.fill")
                                    Text(color.localizedName)
                                }
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        store.deleteFolder(folder)
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Color Picker

    private func colorPicker(selection: Binding<FolderColor>) -> some View {
        HStack(spacing: 8) {
            ForEach(FolderColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if selection.wrappedValue == color {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture {
                        selection.wrappedValue = color
                    }
            }
        }
    }

    // MARK: - Helpers

    private func addFolder() {
        let folder = ConnectionFolder(name: newFolderName, color: newFolderColor)
        store.addFolder(folder)
        newFolderName = ""
        newFolderColor = .blue
    }

    private func commitRename(_ folder: ConnectionFolder) {
        let trimmed = renamingFolderName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            var updated = folder
            updated.name = trimmed
            store.updateFolder(updated)
        }
        renamingFolderId = nil
    }
}
