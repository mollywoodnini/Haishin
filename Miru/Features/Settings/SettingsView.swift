//
//  SettingsView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// The settings view for app configuration.
struct SettingsView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("autoPlay") private var autoPlay = true
    @AppStorage("showNSFW") private var showNSFW = false


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                playbackSection
                contentSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        } header: {
            Text("Appearance")
        }
    }

    private var playbackSection: some View {
        Section {
            Toggle("Auto-play next episode", isOn: $autoPlay)
        } header: {
            Text("Playback")
        }
    }

    private var contentSection: some View {
        Section {
            Toggle("Show NSFW sources", isOn: $showNSFW)
        } header: {
            Text("Content")
        } footer: {
            Text("NSFW sources will be hidden from the sources list when disabled.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/example/miru")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("About")
        }
    }
}


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
}


//#################################################################################
// MARK: - Bundle Extension
//#################################################################################

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SettingsView()
}
