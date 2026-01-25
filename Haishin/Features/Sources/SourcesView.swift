//
//  SourcesView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for managing anime sources.
struct SourcesView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: SourcesViewModel
    @State private var showingAddRepository = false
    @State private var showingInstallFromURL = false
    @State private var showingFilePicker = false
    @State private var repositoryURL = ""
    @State private var sourceURL = ""


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new sources view.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: SourcesViewModel(sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            List {
                installedSourcesSection

                if !viewModel.repositories.isEmpty {
                    repositoriesSection
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddRepository = true
                        } label: {
                            Label("Add Repository", systemImage: "plus.rectangle.on.folder")
                        }
                        
                        Button {
                            showingInstallFromURL = true
                        } label: {
                            Label("Install from URL", systemImage: "link.badge.plus")
                        }
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("Install from Files", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Repository", isPresented: $showingAddRepository) {
                TextField("Repository URL", text: $repositoryURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {
                    repositoryURL = ""
                }

                Button("Add") {
                    Task {
                        await viewModel.addRepository(urlString: repositoryURL)
                        repositoryURL = ""
                    }
                }
            } message: {
                Text("Enter the URL of a source repository.")
            }
            .alert("Install from URL", isPresented: $showingInstallFromURL) {
                TextField("Source URL", text: $sourceURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                Button("Cancel", role: .cancel) {
                    sourceURL = ""
                }

                Button("Install") {
                    Task {
                        await viewModel.installSourceFromURL(urlString: sourceURL)
                        sourceURL = ""
                    }
                }
            } message: {
                Text("Enter the URL to a source JavaScript file.")
            }
            .fileImporter(isPresented: $showingFilePicker,
                          allowedContentTypes: [.javaScript],
                          allowsMultipleSelection: false) { result in
                print("[SourcesView] File picker result received")
                switch result {
                case .success(let urls):
                    print("[SourcesView] Success with \(urls.count) URLs")
                    guard let url = urls.first else {
                        print("[SourcesView] No URL in array")
                        return
                    }
                    
                    print("[SourcesView] Selected file: \(url)")
                    
                    Task {
                        await viewModel.installSourceFromFile(fileURL: url)
                    }
                case .failure(let error):
                    print("[SourcesView] File picker failed: \(error)")
                }
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var installedSourcesSection: some View {
        Section {
            if viewModel.installedSources.isEmpty {
                ContentUnavailableView {
                    Label("No Sources Installed", systemImage: "globe.badge.chevron.backward")
                } description: {
                    Text("Add a repository and install sources to get started.")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.installedSources) { source in
                    InstalledSourceRow(source: source) {
                        viewModel.toggleSource(source)
                    } onDelete: {
                        viewModel.uninstallSource(source)
                    }
                }
            }
        } header: {
            Text("Installed")
        }
    }

    private var repositoriesSection: some View {
        ForEach(viewModel.repositories) { repo in
            Section {
                ForEach(repo.sources) { source in
                    RepositorySourceRow(source: source,
                                        isInstalled: viewModel.isInstalled(source)) {
                        Task {
                            await viewModel.installSource(source, from: repo)
                        }
                    }
                }
            } header: {
                Text(repo.name)
            }
        }
    }
}


//#################################################################################
// MARK: - InstalledSourceRow
//#################################################################################

/// A row displaying an installed source.
private struct InstalledSourceRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let source: InstalledSource
    let onToggle: () -> Void
    let onDelete: () -> Void


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            AsyncImage(url: source.info.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(source.info.name)
                    .font(.body)

                HStack(spacing: .spacingXXS) {
                    Text("v\(source.info.version)")
                    Text("•")
                    Text(source.info.language.uppercased())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}


//#################################################################################
// MARK: - RepositorySourceRow
//#################################################################################

/// A row displaying a source from a repository.
private struct RepositorySourceRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let source: SourceInfo
    let isInstalled: Bool
    let onInstall: () -> Void


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            AsyncImage(url: source.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                HStack {
                    Text(source.name)
                        .font(.body)

                    if source.isNSFW {
                        Text("18+")
                            .font(.caption2)
                            .padding(.horizontal, .spacingXXS)
                            .background(Capsule().fill(.red))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: .spacingXXS) {
                    Text("v\(source.version)")
                    Text("•")
                    Text(source.language.uppercased())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    onInstall()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
            }
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SourcesView(sourceManager: SourceManager())
}
