//
//  MainTabView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI

/// The main tab navigation view for the app.
struct MainTabView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var selectedTab: Tab = .browse
    private let sourceManager = SourceManager.shared


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView(
                watchProgressService: WatchProgressService.shared,
                subscriptionService: SubscriptionService.shared,
                sourceManager: sourceManager,
                downloadService: DownloadService.shared,
                userPreferences: UserPreferences.shared
            )
                .tabItem {
                    Label(Tab.library.title, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)

            SearchView(
                sourceManager: sourceManager,
                watchProgressService: WatchProgressService.shared,
                subscriptionService: SubscriptionService.shared,
                downloadService: DownloadService.shared
            )
                .tabItem {
                    Label(Tab.search.title, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

            SourcesView(sourceManager: sourceManager)
                .tabItem {
                    Label(Tab.sources.title, systemImage: Tab.sources.icon)
                }
                .tag(Tab.sources)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .task {
            await sourceManager.loadInstalledSources()
            DownloadService.shared.setSourceManager(sourceManager)
        }
    }
}


//#################################################################################
// MARK: - Tab
//#################################################################################

/// Represents the main tabs in the app.
private enum Tab: String, CaseIterable {
    case browse
    case library
    case search
    case sources
    case settings

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .library: return "Library"
        case .search: return "Search"
        case .sources: return "Sources"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .browse: return "square.grid.2x2"
        case .library: return "books.vertical"
        case .search: return "magnifyingglass"
        case .sources: return "globe"
        case .settings: return "gearshape"
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    MainTabView()
}
