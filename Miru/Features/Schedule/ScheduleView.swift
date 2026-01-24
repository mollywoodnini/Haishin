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

    let day: ScheduleDay


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            // Day header
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

            // Anime cards for this day
            ForEach(day.items) { item in
                ScheduleAnimeRow(item: item)
            }
        }
    }
}


//#################################################################################
// MARK: - ScheduleAnimeRow
//#################################################################################

/// A row showing an anime in the schedule with air time.
private struct ScheduleAnimeRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let imageWidth: CGFloat = 80
        static let imageHeight: CGFloat = 110
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let item: RecommendingItem


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            // Cover image with episode badge
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: Constants.imageWidth, height: Constants.imageHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

                // Episode badge
                if let caption = item.caption {
                    Text(caption)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: .spacingXXS) {
                // Air time
                if let airDate = item.airDate {
                    Text(formatTime(airDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.highlight)
                }

                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let synopsis = item.synopsis {
                    Text(synopsis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacingXXS)
        }
        .padding(.spacingS)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
