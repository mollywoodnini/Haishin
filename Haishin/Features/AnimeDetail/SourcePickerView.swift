//
//  SourcePickerView.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import SwiftUI

/// A view for selecting a source to watch anime from.
struct SourcePickerView: View {
    
    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    private let animeTitle: String
    private let onSourceSelected: () -> Void
    private let sources: [InstalledSource]

    @Binding private var selectedSourceId: String?
    @Environment(\.dismiss) private var dismiss


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new source picker view.
    /// - Parameters:
    ///   - animeTitle: The anime title being selected for.
    ///   - selectedSourceId: Binding to the selected source ID.
    ///   - onSourceSelected: Callback when a source is selected.
    ///   - sources: The list of available sources to display.
    init(animeTitle: String,
         selectedSourceId: Binding<String?>,
         onSourceSelected: @escaping () -> Void,
         sources: [InstalledSource]) {
        self.animeTitle = animeTitle
        self._selectedSourceId = selectedSourceId
        self.onSourceSelected = onSourceSelected
        self.sources = sources
    }

    /// Creates a new source picker view with a source manager.
    /// - Parameters:
    ///   - animeTitle: The anime title being selected for.
    ///   - selectedSourceId: Binding to the selected source ID.
    ///   - onSourceSelected: Callback when a source is selected.
    ///   - sourceManager: The source manager for fetching sources.
    init(animeTitle: String,
         selectedSourceId: Binding<String?>,
         onSourceSelected: @escaping () -> Void,
         sourceManager: SourceManaging) {
        self.init(animeTitle: animeTitle,
                  selectedSourceId: selectedSourceId,
                  onSourceSelected: onSourceSelected,
                  sources: sourceManager.installedSources)
    }
    
    
    //#################################################################################
    // MARK: - Body
    //#################################################################################
    
    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    emptyState
                } else {
                    sourcesList
                }
            }
            .navigationTitle("Select Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    
    //#################################################################################
    // MARK: - Subviews
    //#################################################################################
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Sources Available", systemImage: "globe.badge.chevron.backward")
        } description: {
            Text("Install sources to watch \"\(animeTitle)\"")
        } actions: {
            Button("Manage Sources") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var sourcesList: some View {
        List {
            Section {
                ForEach(sources.filter(\.isEnabled)) { source in
                    Button {
                        selectedSourceId = source.id
                        onSourceSelected()
                    } label: {
                        HStack(spacing: .spacingS) {
                            AsyncImage(url: source.info.iconURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image(systemName: "globe")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                            
                            VStack(alignment: .leading, spacing: .spacingXXS) {
                                Text(source.info.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                HStack(spacing: .spacingXXS) {
                                    Text("v\(source.info.version)")
                                    Text("•")
                                    Text(source.info.language.uppercased())
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedSourceId == source.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("Available Sources")
            } footer: {
                if sources.allSatisfy({ !$0.isEnabled }) {
                    Text("All sources are disabled. Enable sources in Settings.")
                }
            }
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SourcePickerView(animeTitle: "Attack on Titan",
                     selectedSourceId: .constant(nil),
                     onSourceSelected: {},
                     sources: [])
}
