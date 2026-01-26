//
//  HaishinApp.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI

@main
struct HaishinApp: App {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var userPreferences = UserPreferences.shared


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(userPreferences.appearance.colorScheme)
        }
    }
}
