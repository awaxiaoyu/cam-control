import CamControlCore
import Foundation
import SwiftUI
import UIKit

struct GalleryView: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedItem: GalleryItem?
    @State private var previewItem: GalleryItem?
    @State private var sidePanel: MediaPanel = .allClips

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900
            HStack(spacing: 0) {
                mediaSidebar(compact: compact)
                    .frame(width: compact ? 150 : 220)
                Divider().overlay(.white.opacity(0.10))
                mediaWorkspace(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        .refreshable { await controller.refreshGallery() }
        .fullScreenCover(item: $previewItem) { item in
            PicturePreview(item: item)
                .environmentObject(controller)
        }
        // Firmware/update note: this shell follows recovered MediaTab, MediaView, MediaViewSidebar, MediaViewToolbar, MediaSortPanel, MediaUploadToCloudPanel and MediaClipDetails*Panel anchors; media icons use recovered asset names, and future clip formats/status states belong in GalleryItem mapping, not layout chrome.
    }

    private func mediaSidebar(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                BMDAssetIcon(name: "Media", activeName: "Media_active", active: true, fallback: "photo.on.rectangle", color: BlackmagicCamStyle.cyan, size: compact ? 12 : 15)
                Text(sidePanel == .allClips ? "All Clips" : "No project selected - All Clips")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.top, compact ? 9 : 12)
            .padding(.bottom, compact ? 8 : 10)

            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                MediaSourceCard(title: "iPhone 14 Pro Max", subtitle: "All Clips", selected: sidePanel == .allClips, icon: "Media", compact: compact) {
                    sidePanel = .allClips
                }
                VStack(alignment: .leading, spacing: compact ? 5 : 7) {
                    Text("Blackmagic Cloud")
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.64))
                    if sidePanel == .upload {
                        ForEach(["Short Film", "Documentary", "Green Book", "Trailer"], id: \.self) { project in
                            MediaSourceCard(title: project, subtitle: "\(max(0, controller.galleryItems.count)) Clips", selected: selectedCloudProjectTitle == project, icon: "ProjectUpload", compact: compact) {
                                selectedCloudProjectTitle = project
                            }
                        }
                    } else {
                        VStack(spacing: compact ? 6 : 8) {
                            BMDAssetImage(name: "BmdCloudLogo", fallback: "cloud.fill", preserveOriginalColors: true)
                                .frame(width: compact ? 76 : 112, height: compact ? 24 : 36)
                            Text("Log in to Blackmagic Cloud\nto access your projects")
                                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.44))
                            Button { sidePanel = .upload } label: {
                                Text("Log In")
                                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, compact ? 6 : 8)
                                    .background(BlackmagicCamStyle.activeBlue, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(compact ? 9 : 12)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, compact ? 8 : 12)
            Spacer()
        }
        .background(Color.black.opacity(0.92))
        // Firmware/update note: MediaViewSidebar now mirrors Blackmagic 3.x screenshots: simple dark source list, iPhone source card, Cloud login/projects block.
    }

    @State private var selectedCloudProjectTitle = "Short Film"

    private func mediaWorkspace(compact: Bool) -> some View {
        VStack(spacing: 0) {
            mediaToolbar(compact: compact)
            mediaPool(compact: compact)
        }
        .background(Color(red: 0.045, green: 0.048, blue: 0.052))
        // Firmware/update note: main media area follows screenshot grid-only surface; auxiliary panels are represented by toolbar/sidebar states rather than a persistent right drawer.
    }

    private func mediaPool(compact: Bool) -> some View {
        ZStack {
            if controller.galleryItems.isEmpty {
                VStack {
                    Spacer()
                    BMEmptyState(
                        systemImage: "photo.on.rectangle.angled",
                        title: "No Clips",
                        subtitle: "Captured clips appear here. Sort, upload, export, or open clip details from the media pool."
                    )
                    .frame(maxWidth: 560)
                    Spacer()
                }
                .padding(24)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 96 : 132), spacing: compact ? 8 : 10)], spacing: compact ? 10 : 14) {
                        ForEach(controller.galleryItems) { item in
                            Button {
                                withAnimation(.snappy(duration: 0.16)) {
                                    selectedItem = item
                                    sidePanel = .clipDetails
                                }
                            } label: {
                                GalleryCard(item: item, selected: selectedItem?.id == item.id, compact: compact)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Open Clip") { previewItem = item }
                                Button("Upload Original") { sidePanel = .upload }
                                Button("Remove Clip") { selectedItem = item }
                            }
                        }
                    }
                    .padding(compact ? 10 : 14)
                }
            }
        }
    }

    private func mediaToolbar(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            BMDAssetIcon(name: "Media", activeName: "Media_active", active: true, fallback: "photo.on.rectangle", color: BlackmagicCamStyle.cyan, size: compact ? 12 : 15)
            Text(sidePanel == .upload ? "No project selected - All Clips" : "All Clips")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                .foregroundStyle(.white)
            Spacer()
            toolbarIconButton(.allClips, asset: "Media", fallback: "rectangle.grid.2x2", compact: compact)
            toolbarIconButton(.clipDetails, asset: "HdmiPlay", fallback: "play.rectangle", compact: compact)
            toolbarIconButton(.sort, asset: "Sort", fallback: "arrow.up.arrow.down", compact: compact)
            toolbarIconButton(.upload, asset: "UploadToCloud", fallback: "icloud.and.arrow.up", compact: compact)
            Circle()
                .fill(.white.opacity(0.24))
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                .overlay(BMDAssetIcon(name: "Cloud", active: true, fallback: "person.crop.circle", color: .white, size: compact ? 12 : 15))
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(Color.black.opacity(0.76))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .bottom)
        // Firmware/update note: toolbar mirrors MediaViewToolbar screenshot: tiny title on left, icon-only sort/upload/filter controls on the right.
    }

    private func toolbarIconButton(_ panel: MediaPanel, asset: String, fallback: String, compact: Bool) -> some View {
        Button { withAnimation(.snappy(duration: 0.16)) { sidePanel = panel } } label: {
            BMDAssetIcon(name: asset, active: sidePanel == panel, fallback: fallback, color: sidePanel == panel ? .white : .white.opacity(0.70), size: compact ? 12 : 15)
                .frame(width: compact ? 24 : 30, height: compact ? 22 : 28)
                .background(sidePanel == panel ? BlackmagicCamStyle.activeBlue.opacity(0.82) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toolbarButton(_ panel: MediaPanel, _ title: String, _ value: String, asset: String, compact: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) { sidePanel = panel }
        } label: {
            toolbarPill(title, value, asset: asset, fallback: panel.fallbackIcon, compact: compact, active: sidePanel == panel)
        }
        .buttonStyle(.plain)
    }

    private func toolbarPill(_ title: String, _ value: String, asset: String, fallback: String, compact: Bool, active: Bool = false) -> some View {
        HStack(spacing: 7) {
            BMDAssetIcon(name: asset, active: active, fallback: fallback, color: active ? .white : BlackmagicCamStyle.cyan, size: compact ? 13 : 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.50))
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 7)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.28) : .white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(active ? BlackmagicCamStyle.cyan.opacity(0.45) : .white.opacity(0.10), lineWidth: 1))
    }

    @ViewBuilder
    private func mediaSidePanel(compact: Bool) -> some View {
        switch sidePanel {
        case .allClips:
            MediaInfoPanel(title: "All Clips", icon: "Media", rows: [
                ("Clips", "\(controller.galleryItems.count)"),
                ("Sort By", "Date Time"),
                ("Order", "Descending"),
                ("Project", "No project selected - All Clips")
            ], compact: compact)
        case .sort:
            MediaSortPanel(compact: compact)
        case .upload:
            MediaUploadPanel(compact: compact)
        case .clipDetails:
            MediaClipDetailsPanel(item: selectedItem, onOpen: { if let selectedItem { previewItem = selectedItem } }, compact: compact)
        }
    }
}

private enum MediaPanel: String, CaseIterable, Identifiable {
    case allClips
    case sort
    case upload
    case clipDetails

    var id: String { rawValue }
    var title: String {
        switch self {
        case .allClips: return "All Clips"
        case .sort: return "Sort By"
        case .upload: return "Upload Status"
        case .clipDetails: return "Clip Details"
        }
    }
    var subtitle: String {
        switch self {
        case .allClips: return "Media"
        case .sort: return "Date Time / Clip Name"
        case .upload: return "Proxy / Original"
        case .clipDetails: return "Selected Clip"
        }
    }
    var asset: String {
        switch self {
        case .allClips: return "Media"
        case .sort: return "Sort"
        case .upload: return "UploadToCloud"
        case .clipDetails: return "Slate"
        }
    }
    var fallbackIcon: String {
        switch self {
        case .allClips: return "rectangle.stack.fill"
        case .sort: return "arrow.up.arrow.down"
        case .upload: return "arrow.up.circle.fill"
        case .clipDetails: return "info.circle.fill"
        }
    }
}

private struct MediaSourceCard: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let icon: String
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 7 : 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer()
                BMDAssetIcon(name: icon, active: selected, fallback: "folder", color: selected ? BlackmagicCamStyle.cyan : .white.opacity(0.45), size: compact ? 11 : 14)
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 7 : 9)
            .background(selected ? BlackmagicCamStyle.activeBlue.opacity(0.26) : .white.opacity(0.075), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(selected ? BlackmagicCamStyle.activeBlue.opacity(0.8) : .white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        // Firmware/update note: source/project cards mirror MediaViewSidebar/MediaViewSidebarCloudLogIn screenshot proportions.
    }
}

private struct MediaSidebarRow: View {
    let panel: MediaPanel
    let count: Int
    let selectedItem: GalleryItem?
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 11) {
            BMDAssetIcon(name: panel.asset, active: active, fallback: panel.fallbackIcon, color: active ? .white : BlackmagicCamStyle.cyan, size: compact ? 15 : 18)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background((active ? BlackmagicCamStyle.activeBlue : BlackmagicCamStyle.cyan.opacity(0.14)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(panel.title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(active ? 0.76 : 0.44))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 9 : 12)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.22) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.45) : .white.opacity(0.08), lineWidth: 1))
    }

    private var value: String {
        switch panel {
        case .allClips: return "\(count) Clips"
        case .sort: return "Date Time"
        case .upload: return "Waiting to Upload"
        case .clipDetails: return selectedItem?.filename ?? "None"
        }
    }
}

private struct MediaInfoPanel: View {
    let title: String
    let icon: String
    let rows: [(String, String)]
    let compact: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader(title: title, subtitle: "Media Tab", icon: icon)
                ForEach(rows, id: \.0) { row in
                    MediaPanelRow(title: row.0, value: row.1, color: BlackmagicCamStyle.cyan)
                }
            }
            .padding(compact ? 14 : 18)
        }
        .background(.black.opacity(0.26))
    }
}

private struct MediaSortPanel: View {
    let compact: Bool
    private let sortRows = [
        ("Sort By", "Date Time", BlackmagicCamStyle.cyan),
        ("Clip Name", "A001_0001", .white.opacity(0.72)),
        ("Created", "Newest First", BlackmagicCamStyle.amber),
        ("Ascending", "Off", .white.opacity(0.62)),
        ("Descending", "On", BlackmagicCamStyle.okGreen)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader(title: "Sort By", subtitle: "Date Time / Clip Name / Created", icon: "Sort")
                ForEach(Array(sortRows.enumerated()), id: \.offset) { _, row in
                    MediaPanelRow(title: row.0, value: row.1, color: row.2)
                }
            }
            .padding(compact ? 14 : 18)
        }
        .background(.black.opacity(0.26))
        // Firmware/update note: rows are sourced from recovered MediaSortPanelSortTypeItem and MediaSortPanelSortOrderItem strings; update row values when sort model becomes live.
    }
}

private struct MediaUploadPanel: View {
    let compact: Bool
    private let rows = [
        ("Upload To", "No project selected - All Clips", BlackmagicCamStyle.amber),
        ("Upload Clips", "Waiting to Upload...", .white.opacity(0.72)),
        ("Upload Original", "Manual", BlackmagicCamStyle.cyan),
        ("Proxy", "Apple ProRes 422 Proxy", BlackmagicCamStyle.okGreen),
        ("Enable Upload Only Over Wi-Fi", "On", .white.opacity(0.70)),
        ("Auto Upload To Selected Project", "Off", .white.opacity(0.58))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader(title: "Upload Status", subtitle: "Proxy / Original", icon: "UploadToCloud")
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    MediaPanelRow(title: row.0, value: row.1, color: row.2)
                }
            }
            .padding(compact ? 14 : 18)
        }
        .background(.black.opacity(0.26))
        // Firmware/update note: panel maps MediaUploadToCloudPanel, MediaUploadFailView and MediaClipUploadStatusText; bind rows to cloud upload state when transport is implemented.
    }
}

private struct MediaClipDetailsPanel: View {
    let item: GalleryItem?
    let onOpen: () -> Void
    let compact: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader(title: "Clip Details", subtitle: item?.filename ?? "No clip selected", icon: "Slate")
                if let item {
                    MediaPanelRow(title: "Clip Name", value: item.filename, color: .white)
                    MediaPanelRow(title: "Files", value: ByteCountFormatter.string(fromByteCount: Int64(item.compressedSize), countStyle: .file), color: BlackmagicCamStyle.cyan)
                    MediaPanelRow(title: "Format", value: String(format: "0x%04X", Int(item.objectFormat)), color: BlackmagicCamStyle.amber)
                    MediaPanelRow(title: "Upload", value: item.cachedURL == nil ? "Waiting to Upload..." : "Proxy uploaded", color: item.cachedURL == nil ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                    Button(action: onOpen) {
                        HStack {
                            Text("OPEN CLIP")
                            Spacer()
                            BMDAssetIcon(name: "HdmiPlay", activeName: "HdmiPlay_active", active: true, fallback: "play.fill", color: .white, size: 18)
                        }
                        .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(BlackmagicCamStyle.activeBlue.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BlackmagicCamStyle.cyan.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Select a clip to view Clip Name, Files, Format, Upload and metadata details.")
                        .font(BlackmagicCamStyle.labelFont(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(compact ? 14 : 18)
        }
        .background(.black.opacity(0.26))
        // Firmware/update note: panel follows recovered MediaClipDetailsLandscapePanel/PortraitPanel and MediaClipView symbols; add video scrubber only when clip playback is available.
    }
}

private func panelHeader(title: String, subtitle: String, icon: String) -> some View {
    HStack(spacing: 10) {
        BMDAssetIcon(name: icon, active: true, fallback: "info.circle.fill", color: BlackmagicCamStyle.cyan, size: 20)
            .frame(width: 38, height: 38)
            .background(BlackmagicCamStyle.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(BlackmagicCamStyle.cyan)
            Text(subtitle)
                .font(BlackmagicCamStyle.labelFont(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }
}

private struct MediaPanelRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(.white.opacity(0.50))
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
        }
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
    }
}

private struct GalleryCard: View {
    let item: GalleryItem
    let selected: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 11) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .fill(.black.opacity(0.42))

                if let url = item.thumbnailURL ?? item.cachedURL, let image = PlatformImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 9) {
                        BMDAssetIcon(name: "Media", fallback: "photo", color: BlackmagicCamStyle.mutedText, size: compact ? 28 : 38)
                        Text("NO THUMB")
                            .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                }

                Text(formatCode)
                    .font(BlackmagicCamStyle.readoutFont(size: compact ? 8 : 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.62), in: Capsule())
                    .padding(8)
            }
            .frame(height: compact ? 112 : 144)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous).stroke(selected ? BlackmagicCamStyle.cyan.opacity(0.70) : .white.opacity(0.12), lineWidth: selected ? 2 : 1))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.filename)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.compressedSize), countStyle: .file))
                    Spacer()
                    BMDAssetIcon(name: item.cachedURL == nil ? "UploadToCloud" : "UploadedToCloud", activeName: item.cachedURL == nil ? "UploadToCloud_active" : "UploadedToCloud", active: item.cachedURL != nil, fallback: item.cachedURL == nil ? "arrow.down.circle" : "checkmark.circle.fill", color: item.cachedURL == nil ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen, size: 16)
                }
                .font(BlackmagicCamStyle.readoutFont(size: compact ? 9 : 11, weight: .medium))
                .foregroundStyle(item.cachedURL == nil ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
            }
        }
        .padding(compact ? 10 : 12)
        .background(selected ? BlackmagicCamStyle.activeBlue.opacity(0.18) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous).stroke(selected ? BlackmagicCamStyle.cyan.opacity(0.55) : .white.opacity(0.12), lineWidth: 1))
    }

    private var formatCode: String {
        String(format: "0x%04X", Int(item.objectFormat))
    }
}

private struct PicturePreview: View {
    @EnvironmentObject private var controller: CameraController
    @Environment(\.dismiss) private var dismiss
    let item: GalleryItem
    @State private var url: URL?

    var body: some View {
        ZStack {
            BlackmagicCamStyle.canvas.ignoresSafeArea()
            if let url, let image = PlatformImage(contentsOfFile: url.path) {
                ZoomableFrame {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView().tint(BlackmagicCamStyle.cyan)
                    Text("LOADING MEDIA")
                        .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(BlackmagicCamStyle.mutedText)
                }
                .task { url = await controller.download(item) }
            }

            VStack {
                HStack {
                    Button("DONE") { dismiss() }
                        .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.58), in: Capsule())
                    Spacer()
                    Text(item.filename)
                        .font(BlackmagicCamStyle.labelFont(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.58), in: Capsule())
                    Button {
                        saveToPhotos()
                    } label: {
                        HStack(spacing: 7) {
                            BMDAssetIcon(name: "MediaSync", activeName: "MediaSync_active", active: true, fallback: "square.and.arrow.down", color: .white, size: 14)
                            Text("SAVE")
                        }
                    }
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(url == nil ? BlackmagicCamStyle.mutedText : BlackmagicCamStyle.cyan)
                    .disabled(url == nil)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.58), in: Capsule())
                }
                .padding(18)
                Spacer()
            }
        }
    }

    private func saveToPhotos() {
        guard let url, let image = PlatformImage(contentsOfFile: url.path) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
