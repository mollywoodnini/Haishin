//
//  SourcesViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
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

    /// Whether an operation is in progress.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    private let sourceManager: SourceManaging


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
        print("[SourcesViewModel] Installing from file: \(fileURL)")
        print("[SourcesViewModel] File path: \(fileURL.path)")
        
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
            
            print("[SourcesViewModel] Security scoped access: \(accessing)")
            
            // Use the file path directly
            try await sourceManager.installSource(fromURL: fileURL.path)
            
            print("[SourcesViewModel] Installation successful!")
        } catch {
            print("[SourcesViewModel] Installation failed: \(error)")
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

    /// Toggles whether a source is enabled.
    /// - Parameter source: The source to toggle.
    func toggleSource(_ source: InstalledSource) {
        if sourceManager.installedSources.contains(where: { $0.id == source.id }) {
            // Note: This would need to be updated to properly mutate the source manager
            // For now, this is a simplified implementation
            print("[SourcesViewModel] Toggle source: \(source.info.name)")
        }
    }

    /// Checks if a source is already installed.
    /// - Parameter source: The source to check.
    /// - Returns: Whether the source is installed.
    func isInstalled(_ source: SourceInfo) -> Bool {
        installedSources.contains { $0.info.id == source.id }
    }
}
