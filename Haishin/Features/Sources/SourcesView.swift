//
//  SourcesView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// View for managing video sources.
struct SourcesView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: SourcesViewModel


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
                if viewModel.hasUpdates {
                    updatesSection
                }

                installedSourcesSection

                if !viewModel.repositories.isEmpty {
                    repositoriesSection
                }
            }
            .navigationTitle("Sources")
            .refreshable {
                await viewModel.refreshRepositories()
            }
            .task {
                await viewModel.loadRepositories()
            }
            .modifier(SourceAddFlowModifier(viewModel: viewModel))
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var updatesSection: some View {
        Section {
            ForEach(viewModel.installedSources.filter { viewModel.getAvailableUpdate(for: $0.id) != nil }) { source in
                if let update = viewModel.getAvailableUpdate(for: source.id) {
                    UpdateAvailableRow(
                        source: source,
                        newVersion: update.version
                    ) {
                        Task {
                            await viewModel.updateSource(sourceId: source.id)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Updates Available")
                Spacer()
                Button("Update All") {
                    Task {
                        await viewModel.updateAllSources()
                    }
                }
                .font(.caption)
            }
        }
    }

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
                    InstalledSourceRow(
                        source: source,
                        hasUpdate: viewModel.getAvailableUpdate(for: source.id) != nil,
                        onDelete: { viewModel.uninstallSource(source) }
                    )
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
                    RepositorySourceRow(
                        source: source,
                        isInstalled: viewModel.isInstalled(source),
                        hasUpdate: viewModel.getAvailableUpdate(for: source.id) != nil
                    ) {
                        Task {
                            await viewModel.installSource(source, from: repo)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(repo.name)
                    Spacer()
                    Button {
                        viewModel.removeRepository(repo)
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                    }
                }
            }
        }
    }
}


//#################################################################################
// MARK: - UpdateAvailableRow
//#################################################################################

/// A row displaying an available update.
private struct UpdateAvailableRow: View {

    private let source: InstalledSource
    private let newVersion: String
    private let onUpdate: () -> Void

    init(source: InstalledSource, newVersion: String, onUpdate: @escaping () -> Void) {
        self.source = source
        self.newVersion = newVersion
        self.onUpdate = onUpdate
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(source.info.name)
                    .font(.body)

                Text("v\(source.info.version) → v\(newVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onUpdate()
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}


//#################################################################################
// MARK: - SourceAddFlowModifier
//#################################################################################

private struct SourceAddFlowModifier: ViewModifier {

    @State private var showingAddRepository = false
    @State private var showingInstallFromURL = false
    @State private var showingFilePicker = false
    @State private var repositoryURL = ""
    @State private var sourceURL = ""

    private let viewModel: SourcesViewModel

    init(viewModel: SourcesViewModel) {
        self.viewModel = viewModel
    }

    func body(content: Content) -> some View {
        content
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

                        #if DEBUG
                        Divider()

                        Button {
                            Task {
                                await viewModel.installGoGoAnimeSource()
                            }
                        } label: {
                            Label("Add GoGoAnime (Debug)", systemImage: "ladybug")
                        }

                        Divider()

                        Button {
                            Task {
                                await viewModel.installHiAnimeSource()
                            }
                        } label: {
                            Label("Add HiAnime (Debug)", systemImage: "ladybug")
                        }
                        #endif

                        if viewModel.hasUpdates {
                            Divider()

                            Button {
                                Task {
                                    await viewModel.updateAllSources()
                                }
                            } label: {
                                Label("Update All (\(viewModel.updateCount))", systemImage: "arrow.down.circle.fill")
                            }
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
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.javaScript],
                allowsMultipleSelection: false
            ) { result in
                Log.debug(.sources, "File picker result received")
                switch result {
                case .success(let urls):
                    Log.debug(.sources, "Success with \(urls.count) URLs")
                    guard let url = urls.first else {
                        Log.warning(.sources, "No URL in array")
                        return
                    }

                    Log.debug(.sources, "Selected file: \(url)")

                    Task {
                        await viewModel.installSourceFromFile(fileURL: url)
                    }
                case .failure(let error):
                    Log.error(.sources, "File picker failed: \(error)")
                }
            }
    }
}


#Preview {
    SourcesView(sourceManager: SourceManager())
}
