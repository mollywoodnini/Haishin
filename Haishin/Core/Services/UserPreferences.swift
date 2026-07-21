//
//  UserPreferences.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - AppearanceMode
//#################################################################################

/// The app appearance mode.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}


//#################################################################################
// MARK: - UserPreferencesProtocol
//#################################################################################

/// Protocol for user preferences management.
@MainActor
protocol UserPreferencesProtocol: AnyObject {
    /// The app appearance mode (system, light, dark).
    var appearance: AppearanceMode { get set }

    /// Whether to show NSFW (adult) content.
    var showNSFW: Bool { get set }

    /// The currently selected source ID.
    var selectedSourceId: String? { get set }

    /// Clears all user preferences to their defaults.
    func clearAll()
}


//#################################################################################
// MARK: - UserPreferences
//#################################################################################

/// Manages user preferences and settings stored in UserDefaults.
@Observable
@MainActor
final class UserPreferences: UserPreferencesProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

        private struct Keys {
        static let appearance = "appearance"
        static let showNSFW = "showNSFW"
        static let selectedSourceId = "selectedSourceId"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = UserPreferences()

    /// The app appearance mode.
    var appearance: AppearanceMode {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    /// Whether to show NSFW (adult) content.
    var showNSFW: Bool {
        didSet {
            userDefaults.set(showNSFW, forKey: Keys.showNSFW)
        }
    }

    /// The currently selected source ID.
    var selectedSourceId: String? {
        didSet {
            userDefaults.set(selectedSourceId, forKey: Keys.selectedSourceId)
        }
    }

    private let userDefaults: UserDefaults


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new user preferences manager.
    /// - Parameter userDefaults: The UserDefaults instance to use.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load existing preferences
        if let appearanceRaw = userDefaults.string(forKey: Keys.appearance),
           let loadedAppearance = AppearanceMode(rawValue: appearanceRaw) {
            self.appearance = loadedAppearance
        } else {
            self.appearance = .system
        }

        showNSFW = userDefaults.bool(forKey: Keys.showNSFW)
        selectedSourceId = userDefaults.string(forKey: Keys.selectedSourceId)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func clearAll() {
        appearance = .system
        showNSFW = false
        selectedSourceId = nil
    }
}
