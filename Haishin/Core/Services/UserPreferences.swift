//
//  UserPreferences.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import Foundation

/// Manages user preferences and settings stored in UserDefaults.
@Observable
final class UserPreferences {

    //#################################################################################
    // MARK: - Shared Instance
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = UserPreferences()


    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Keys {
        static let selectedSourceId = "selectedSourceId"
        static let showNSFW = "showNSFW"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The currently selected global source ID.
    var selectedSourceId: String? {
        didSet {
            if let sourceId = selectedSourceId {
                userDefaults.set(sourceId, forKey: Keys.selectedSourceId)
            } else {
                userDefaults.removeObject(forKey: Keys.selectedSourceId)
            }
        }
    }

    /// Whether to show NSFW (adult) content.
    var showNSFW: Bool {
        didSet {
            userDefaults.set(showNSFW, forKey: Keys.showNSFW)
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
        self.selectedSourceId = userDefaults.string(forKey: Keys.selectedSourceId)
        self.showNSFW = userDefaults.bool(forKey: Keys.showNSFW)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Clears all user preferences.
    func clearAll() {
        selectedSourceId = nil
        showNSFW = false
    }
}
