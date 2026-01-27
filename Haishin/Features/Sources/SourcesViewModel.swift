//
//  SourcesViewModel.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
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

    /// Selects a source as the active source.
    /// - Parameter source: The source to select.
    func selectSource(_ source: InstalledSource) {
        sourceManager.selectSource(sourceId: source.id)
    }

    /// Checks if a source is already installed.
    /// - Parameter source: The source to check.
    /// - Returns: Whether the source is installed.
    func isInstalled(_ source: SourceInfo) -> Bool {
        installedSources.contains { $0.info.id == source.id }
    }
}
