//
//  CloudSyncService.swift
//  Haishin
//
//  Created by OpenCode on 26.01.26.
//

import Foundation

/// Protocol for cloud sync functionality.
@MainActor
protocol CloudSyncServiceProtocol {
    /// Whether iCloud sync is enabled.
    var isSyncEnabled: Bool { get set }

    /// Whether iCloud is available on this device.
    var isCloudAvailable: Bool { get }

    /// Syncs all local data to iCloud.
    func syncToCloud()

    /// Pulls data from iCloud and merges with local data.
    func syncFromCloud()

    /// Forces a full sync (upload local data to iCloud).
    func forceUpload()
}


//#################################################################################
// MARK: - CloudSyncService
//#################################################################################

/// Service for syncing app data to iCloud using NSUbiquitousKeyValueStore.
/// Syncs subscriptions, watch progress, and recents across devices.
@Observable
@MainActor
final class CloudSyncService: CloudSyncServiceProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let syncEnabledKey = "iCloudSyncEnabled"

        // iCloud keys (prefixed to avoid conflicts)
        static let subscribedVideoKey = "sync_subscribedVideo"
        static let watchProgressKey = "sync_watchProgress"
        static let recentVideoKey = "sync_recentVideo"

        // Local UserDefaults keys (matching existing services)
        static let localSubscribedVideoKey = "subscribedVideo"
        static let localWatchProgressKey = "watchProgress"
        static let localRecentVideoKey = "recentVideo"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    static let shared = CloudSyncService()

    var isSyncEnabled: Bool {
        didSet {
            userDefaults.set(isSyncEnabled, forKey: Constants.syncEnabledKey)
            if isSyncEnabled {
                // First pull from cloud (in case there's existing data), then push local
                syncFromCloud()
                syncToCloud()
            }
        }
    }

    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private let userDefaults: UserDefaults
    private let cloudStore: NSUbiquitousKeyValueStore


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new cloud sync service.
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance for local storage.
    ///   - cloudStore: The iCloud key-value store.
    init(userDefaults: UserDefaults = .standard,
         cloudStore: NSUbiquitousKeyValueStore = .default) {
        self.userDefaults = userDefaults
        self.cloudStore = cloudStore
        self.isSyncEnabled = userDefaults.bool(forKey: Constants.syncEnabledKey)

        setupCloudChangeObserver()

        // Initial sync from cloud if enabled
        if isSyncEnabled && isCloudAvailable {
            cloudStore.synchronize()
            syncFromCloud()
        }
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func syncToCloud() {
        guard isSyncEnabled && isCloudAvailable else {
            Log.debug(.sync, "syncToCloud skipped - enabled: \(self.isSyncEnabled), available: \(self.isCloudAvailable)")
            return
        }

        // Sync subscribed videos
        if let data = userDefaults.data(forKey: Constants.localSubscribedVideoKey) {
            cloudStore.set(data, forKey: Constants.subscribedVideoKey)
            Log.debug(.sync, "Uploaded \(data.count) bytes of subscribed videos to cloud")
        } else {
            Log.debug(.sync, "No local subscribed video data to upload")
        }

        // Sync watch progress
        if let data = userDefaults.data(forKey: Constants.localWatchProgressKey) {
            cloudStore.set(data, forKey: Constants.watchProgressKey)
            Log.debug(.sync, "Uploaded \(data.count) bytes of watch progress to cloud")
        }

        // Sync recent videos
        if let data = userDefaults.data(forKey: Constants.localRecentVideoKey) {
            cloudStore.set(data, forKey: Constants.recentVideoKey)
            Log.debug(.sync, "Uploaded \(data.count) bytes of recent videos to cloud")
        }

        let syncResult = cloudStore.synchronize()
        Log.info(.sync, "Synced local data to iCloud, synchronize result: \(syncResult)")
    }

    func syncFromCloud() {
        guard isSyncEnabled && isCloudAvailable else {
            Log.debug(.sync, "syncFromCloud skipped - enabled: \(self.isSyncEnabled), available: \(self.isCloudAvailable)")
            return
        }

        // Force a sync to get latest cloud data
        let syncResult = cloudStore.synchronize()
        Log.debug(.sync, "cloudStore.synchronize() result: \(syncResult)")

        // Merge subscribed videos
        mergeSubscribedVideo()

        // Merge watch progress
        mergeWatchProgress()

        // Merge recent videos
        mergeRecentVideo()

        Log.info(.sync, "Synced data from iCloud")
    }

    func forceUpload() {
        guard isCloudAvailable else { return }

        // Upload all local data to iCloud (overwrite)
        if let data = userDefaults.data(forKey: Constants.localSubscribedVideoKey) {
            cloudStore.set(data, forKey: Constants.subscribedVideoKey)
        }

        if let data = userDefaults.data(forKey: Constants.localWatchProgressKey) {
            cloudStore.set(data, forKey: Constants.watchProgressKey)
        }

        if let data = userDefaults.data(forKey: Constants.localRecentVideoKey) {
            cloudStore.set(data, forKey: Constants.recentVideoKey)
        }

        cloudStore.synchronize()
        Log.info(.sync, "Force uploaded local data to iCloud")
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func setupCloudChangeObserver() {
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: cloudStore,
                                               queue: .main) { [weak self] notification in
            guard let self else { return }
            // Extract Sendable value from notification before crossing isolation boundary
            let changeReason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            Task { @MainActor [weak self] in
                self?.handleCloudChange(changeReason: changeReason)
            }
        }
    }

    private func handleCloudChange(changeReason: Int?) {
        guard isSyncEnabled else { return }

        guard let changeReason else { return }

        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Data changed on another device or initial sync
            syncFromCloud()

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            Log.warning(.sync, "iCloud quota exceeded")

        case NSUbiquitousKeyValueStoreAccountChange:
            // iCloud account changed, re-sync
            syncFromCloud()

        default:
            break
        }
    }

    private func mergeSubscribedVideo() {
        let cloudData = cloudStore.data(forKey: Constants.subscribedVideoKey)
        Log.debug(.sync, "Cloud subscribed video data: \(cloudData?.count ?? 0) bytes")
        
        guard let cloudData,
              let cloudItems = try? JSONDecoder().decode([SubscribedVideo].self, from: cloudData) else {
            Log.debug(.sync, "No cloud subscribed video data found or decode failed")
            return
        }
        
        Log.debug(.sync, "Found \(cloudItems.count) subscribed videos in cloud")

        var localItems: [SubscribedVideo] = []
        if let localData = userDefaults.data(forKey: Constants.localSubscribedVideoKey),
           let decoded = try? JSONDecoder().decode([SubscribedVideo].self, from: localData) {
            localItems = decoded
        }

        // Merge: combine both lists, keep the one with the latest subscribedAt date for duplicates
        var mergedDict: [String: SubscribedVideo] = [:]

        for item in localItems {
            mergedDict[item.id] = item
        }

        for cloudItem in cloudItems {
            if let existing = mergedDict[cloudItem.id] {
                // Keep the newer one
                if cloudItem.subscribedAt > existing.subscribedAt {
                    mergedDict[cloudItem.id] = cloudItem
                }
            } else {
                mergedDict[cloudItem.id] = cloudItem
            }
        }

        let merged = Array(mergedDict.values)

        if let encoded = try? JSONEncoder().encode(merged) {
            userDefaults.set(encoded, forKey: Constants.localSubscribedVideoKey)
        }
    }

    private func mergeWatchProgress() {
        guard let cloudData = cloudStore.data(forKey: Constants.watchProgressKey),
              let cloudProgress = try? JSONDecoder().decode([String: WatchProgress].self, from: cloudData) else {
            return
        }

        var localProgress: [String: WatchProgress] = [:]
        if let localData = userDefaults.data(forKey: Constants.localWatchProgressKey),
           let decoded = try? JSONDecoder().decode([String: WatchProgress].self, from: localData) {
            localProgress = decoded
        }

        // Merge: for each key, keep the one with the latest lastUpdated date
        var merged = localProgress

        for (key, cloudItem) in cloudProgress {
            if let existing = merged[key] {
                // Keep the newer one
                if cloudItem.lastUpdated > existing.lastUpdated {
                    merged[key] = cloudItem
                }
            } else {
                merged[key] = cloudItem
            }
        }

        if let encoded = try? JSONEncoder().encode(merged) {
            userDefaults.set(encoded, forKey: Constants.localWatchProgressKey)
        }
    }

    private func mergeRecentVideo() {
        guard let cloudData = cloudStore.data(forKey: Constants.recentVideoKey),
              let cloudItems = try? JSONDecoder().decode([RecentVideo].self, from: cloudData) else {
            return
        }

        var localItems: [RecentVideo] = []
        if let localData = userDefaults.data(forKey: Constants.localRecentVideoKey),
           let decoded = try? JSONDecoder().decode([RecentVideo].self, from: localData) {
            localItems = decoded
        }

        // Merge: combine both lists, keep the one with the latest lastWatchedAt date for duplicates
        var mergedDict: [String: RecentVideo] = [:]

        for item in localItems {
            mergedDict[item.id] = item
        }

        for cloudItem in cloudItems {
            if let existing = mergedDict[cloudItem.id] {
                // Keep the newer one
                if cloudItem.lastWatchedAt > existing.lastWatchedAt {
                    mergedDict[cloudItem.id] = cloudItem
                }
            } else {
                mergedDict[cloudItem.id] = cloudItem
            }
        }

        let merged = Array(mergedDict.values)

        if let encoded = try? JSONEncoder().encode(merged) {
            userDefaults.set(encoded, forKey: Constants.localRecentVideoKey)
        }
    }
}
