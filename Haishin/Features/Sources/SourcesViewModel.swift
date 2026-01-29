//
//  SourcesViewModel.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// ViewModel for the sources management screen.
@Observable
final class SourcesViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Installed sources from the source manager.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }

    /// Available repositories.
    var repositories: [SourceRepository] {
        sourceManager.repositories
    }

    /// Sources that have updates available.
    var availableUpdates: [String: SourceInfo] {
        sourceManager.availableUpdates
    }

    /// Whether there are any updates available.
    var hasUpdates: Bool {
        !availableUpdates.isEmpty
    }

    /// Number of available updates.
    var updateCount: Int {
        availableUpdates.count
    }

    /// Whether an operation is in progress.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// The source manager instance.
    let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new sources view model.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads saved repositories from storage.
    func loadRepositories() async {
        isLoading = true
        defer { isLoading = false }

        await sourceManager.loadSavedRepositories()
    }

    /// Refreshes all repositories to check for updates.
    func refreshRepositories() async {
        isLoading = true
        defer { isLoading = false }

        await sourceManager.refreshRepositories()
    }

    /// Adds a repository from a URL string.
    /// - Parameter urlString: The repository URL as a string.
    func addRepository(urlString: String) async {
        guard let url = URL(string: urlString) else {
            error = SourceError.invalidScript
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await sourceManager.addRepository(url: url)
        } catch {
            self.error = error
        }
    }

    /// Removes a repository.
    /// - Parameter repository: The repository to remove.
    func removeRepository(_ repository: SourceRepository) {
        sourceManager.removeRepository(repository)
    }
    
    /// Installs a source from a direct URL.
    /// - Parameter urlString: The URL to the source JavaScript file.
    func installSourceFromURL(urlString: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await sourceManager.installSource(fromURL: urlString)
        } catch {
            self.error = error
        }
    }
    
    /// Installs a source from a local file.
    /// - Parameter fileURL: The file URL to the source JavaScript file.
    func installSourceFromFile(fileURL: URL) async {
        Log.debug(.sources, "Installing from file: \(fileURL)")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Start accessing the security-scoped resource
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            Log.debug(.sources, "Security scoped access: \(accessing)")
            
            // Use the file path directly
            try await sourceManager.installSource(fromURL: fileURL.path)
            
            Log.info(.sources, "Installation successful!")
        } catch {
            Log.error(.sources, "Installation failed: \(error)")
            self.error = error
        }
    }

    /// Installs a source from a repository.
    /// - Parameters:
    ///   - source: The source to install.
    ///   - repository: The repository containing the source.
    func installSource(_ source: SourceInfo, from repository: SourceRepository) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await sourceManager.installSource(source, from: repository)
        } catch {
            self.error = error
        }
    }

    /// Uninstalls a source.
    /// - Parameter source: The source to uninstall.
    func uninstallSource(_ source: InstalledSource) {
        do {
            try sourceManager.uninstallSource(sourceId: source.id)
        } catch {
            self.error = error
        }
    }

    /// Checks if a source is already installed.
    /// - Parameter source: The source to check.
    /// - Returns: Whether the source is installed.
    func isInstalled(_ source: SourceInfo) -> Bool {
        installedSources.contains { $0.info.id == source.id }
    }

    /// Checks if an update is available for a source.
    /// - Parameter sourceId: The source ID to check.
    /// - Returns: The new version info if available.
    func getAvailableUpdate(for sourceId: String) -> SourceInfo? {
        sourceManager.getAvailableUpdate(for: sourceId)
    }

    /// Updates a single source.
    /// - Parameter sourceId: The source ID to update.
    func updateSource(sourceId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await sourceManager.updateSource(sourceId: sourceId)
        } catch {
            self.error = error
        }
    }

    /// Updates all sources that have updates available.
    func updateAllSources() async {
        isLoading = true
        defer { isLoading = false }

        await sourceManager.updateAllSources()
    }
}
