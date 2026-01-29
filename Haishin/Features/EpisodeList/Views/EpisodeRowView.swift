//
//  EpisodeRowView.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - EpisodeRowView
//#################################################################################

/// A row displaying an episode with watch progress and download status.
struct EpisodeRowView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let episode: Episode
    private let progress: WatchProgress?
    private let downloadState: DownloadState?
    private let onTap: () -> Void
    private let onDownload: (() -> Void)?
    private let onCancelDownload: (() -> Void)?
    private let onDelete: (() -> Void)?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episode row view for online mode with download functionality.
    /// - Parameters:
    ///   - episode: The episode to display.
    ///   - progress: The watch progress for this episode, if any.
    ///   - downloadState: The download state for this episode, if any.
    ///   - onTap: Action to perform when the row is tapped.
    ///   - onDownload: Action to perform when the download button is tapped.
    ///   - onCancelDownload: Action to perform when download is cancelled.
    init(episode: Episode,
         progress: WatchProgress?,
         downloadState: DownloadState?,
         onTap: @escaping () -> Void,
         onDownload: @escaping () -> Void,
         onCancelDownload: @escaping () -> Void) {
        self.episode = episode
        self.progress = progress
        self.downloadState = downloadState
        self.onTap = onTap
        self.onDownload = onDownload
        self.onCancelDownload = onCancelDownload
        self.onDelete = nil
    }

    /// Creates a new episode row view for offline mode (downloaded episodes).
    /// - Parameters:
    ///   - episode: The episode to display.
    ///   - progress: The watch progress for this episode, if any.
    ///   - onTap: Action to perform when the row is tapped.
    ///   - onDelete: Action to perform when the delete button is tapped.
    init(episode: Episode,
         progress: WatchProgress?,
         onTap: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.episode = episode
        self.progress = progress
        self.downloadState = nil
        self.onTap = onTap
        self.onDownload = nil
        self.onCancelDownload = nil
        self.onDelete = onDelete
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            HStack(spacing: .spacingS) {
                episodeNumberBadge
                episodeInfo
                Spacer()
                actionButton
                completionCheckmark
            }

            progressBar
        }
        .padding(.horizontal, .spacingS)
        .padding(.vertical, .spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var episodeNumberBadge: some View {
        Text("\(episode.number)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 32)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
    }

    private var episodeInfo: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            Text(episodeTitle)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            subtitleText
        }
    }

    private var episodeTitle: String {
        guard let title = episode.title, title != "\(episode.number)" else {
            return "Episode \(episode.number)"
        }
        return title
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let downloadState, case .downloading(let downloadProgress) = downloadState {
            Text("Downloading (\(Int(downloadProgress * 100))% complete)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let progress {
            if progress.isCompleted {
                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(Int((1 - progress.progress) * 100))% left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if onDelete != nil {
            Text("Not watched")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Start Now")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let onDelete {
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        } else {
            switch downloadState {
            case .downloading(let downloadProgress):
                downloadingIndicator(progress: downloadProgress)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

            case .pending:
                ProgressView()
                    .frame(width: 24, height: 24)

            case .failed, .cancelled, nil:
                Button {
                    onDownload?()
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func downloadingIndicator(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))

            Image(systemName: "stop.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.accentColor)
        }
        .onTapGesture {
            onCancelDownload?()
        }
    }

    @ViewBuilder
    private var completionCheckmark: some View {
        if let progress, progress.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if let downloadState, case .downloading(let downloadProgress) = downloadState {
            ProgressBarView(progress: downloadProgress)
        } else if let progress, !progress.isCompleted, progress.progress > 0 {
            ProgressBarView(progress: progress.progress)
        }
    }
}
