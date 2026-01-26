//
//  CreditsView.swift
//  Haishin
//
//  Created by Haishin on 26.01.26.
//

import SwiftUI

/// A view displaying acknowledgments for third-party libraries and APIs.
struct CreditsView: View {

    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        List {
            apiSection
            librariesSection
        }
        .navigationTitle("Acknowledgments")
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var apiSection: some View {
        Section {
            CreditRow(name: "AniList",
                      description: "Anime database and tracking API",
                      url: URL(string: "https://anilist.co"))
        } header: {
            Text("APIs")
        } footer: {
            Text("Haishin uses AniList for browsing anime, fetching metadata, and tracking your watch progress.")
        }
    }

    private var librariesSection: some View {
        Section {
            CreditRow(name: "Kingfisher",
                      description: "Image downloading and caching library",
                      url: URL(string: "https://github.com/onevcat/Kingfisher"))
        } header: {
            Text("Open Source Libraries")
        } footer: {
            Text("Thank you to all the open source contributors who make projects like this possible.")
        }
    }
}


//#################################################################################
// MARK: - CreditRow
//#################################################################################

/// A row displaying a single credit with name, description, and optional link.
private struct CreditRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let name: String
    let description: String
    let url: URL?


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        if let url {
            Link(destination: url) {
                rowContent
            }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        CreditsView()
    }
}
