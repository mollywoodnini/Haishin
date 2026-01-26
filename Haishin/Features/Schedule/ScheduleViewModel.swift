//
//  ScheduleViewModel.swift
//  Miru
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - ScheduleViewModel
//#################################################################################

/// ViewModel for the full weekly schedule view.
@Observable
final class ScheduleViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Schedule days grouped by date.
    private(set) var scheduleDays: [ScheduleDay] = []

    /// Whether content is currently loading.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    private let aniListService: AniListServicing
    private let userPreferences: UserPreferencesProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new schedule view model.
    /// - Parameters:
    ///   - aniListService: The AniList service for fetching schedule data.
    ///   - userPreferences: The user preferences for settings like NSFW.
    init(aniListService: AniListServicing,
         userPreferences: UserPreferencesProtocol) {
        self.aniListService = aniListService
        self.userPreferences = userPreferences
    }

    /// Creates a new schedule view model with default services.
    @MainActor
    convenience init() {
        self.init(aniListService: AniListService(),
                  userPreferences: UserPreferences.shared)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the full weekly schedule.
    func loadSchedule() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let items = try await aniListService.fetchThisWeek(showNSFW: userPreferences.showNSFW)
            let grouped = groupByDay(items)
            await MainActor.run {
                scheduleDays = grouped
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    /// Refreshes the schedule.
    func refresh() async {
        scheduleDays = []
        await loadSchedule()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func groupByDay(_ items: [RecommendingItem]) -> [ScheduleDay] {
        let calendar = Calendar.current

        // Group items by start of day
        var dayMap: [Date: [RecommendingItem]] = [:]

        for item in items {
            guard let airDate = item.airDate else { continue }
            let startOfDay = calendar.startOfDay(for: airDate)

            if dayMap[startOfDay] == nil {
                dayMap[startOfDay] = []
            }
            dayMap[startOfDay]?.append(item)
        }

        // Sort days and create ScheduleDay objects
        let sortedDays = dayMap.keys.sorted()

        return sortedDays.map { date in
            let items = dayMap[date]?.sorted { ($0.airDate ?? .distantPast) < ($1.airDate ?? .distantPast) } ?? []
            return ScheduleDay(date: date, items: items)
        }
    }
}


//#################################################################################
// MARK: - ScheduleDay
//#################################################################################

/// A day in the schedule containing anime airing that day.
struct ScheduleDay: Identifiable {

    /// Unique identifier (the date).
    var id: Date { date }

    /// The date for this schedule day.
    let date: Date

    /// Anime airing on this day, sorted by air time.
    let items: [RecommendingItem]

    /// Formatted day of week (e.g., "Monday").
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Formatted date (e.g., "Jan 25, 2026").
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Whether this day is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
