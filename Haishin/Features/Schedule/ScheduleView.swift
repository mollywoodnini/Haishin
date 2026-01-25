//
//  ScheduleView.swift
//  Miru
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - ScheduleView
//#################################################################################

/// A view showing the full weekly anime schedule grouped by day.
struct ScheduleView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel = ScheduleViewModel()


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.scheduleDays.isEmpty {
                ProgressView()
            } else if let error = viewModel.error, viewModel.scheduleDays.isEmpty {
                errorView(error: error)
            } else {
                scheduleList
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadSchedule()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var scheduleList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                ForEach(viewModel.scheduleDays) { day in
                    ScheduleDaySection(day: day)
                }
            }
            .padding(.spacingS)
        }
    }

    private func errorView(error: Error) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.loadSchedule()
                }
            }
        }
    }
}


//#################################################################################
// MARK: - ScheduleDaySection
//#################################################################################

/// A section showing all anime airing on a specific day.
private struct ScheduleDaySection: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let day: ScheduleDay


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new schedule day section.
    /// - Parameter day: The schedule day to display.
    init(day: ScheduleDay) {
        self.day = day
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            dayHeader
            
            ForEach(day.items) { item in
                AnimeListRow(item: item, mode: .schedule)
            }
        }
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            HStack(spacing: .spacingXS) {
                Text(day.dayOfWeek)
                    .font(.title2)
                    .fontWeight(.bold)

                if day.isToday {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(Color.highlight)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                }
            }

            Text(day.formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
