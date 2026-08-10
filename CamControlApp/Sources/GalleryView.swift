import CamControlCore
import Foundation
import SwiftUI
import UIKit

struct GalleryView: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedItem: GalleryItem?
    @State private var sidePanel = "All Clips"

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 900
            HStack(spacing: 0) {
                mediaSidebar(compact: compact)
                    .frame(width: compact ? 172 : 230)
                Divider().overlay(.white.opacity(0.10))
                mediaPool(compact: compact)
            }
            .background(BlackmagicCamStyle.canvas)
        }
        .refreshable {
            await controller.refreshGallery()
        }
        .fullScreenCover(item: $selectedItem) { item in
            PicturePreview(item: item)
                .environmentObject(controller)
        }
        // Firmware/update note: this maps reversed MediaViewSidebar, MediaPoolView, MediaViewToolbar and MediaClipDetails panels; add firmware-specific formats in GalleryItem parsing, not the media shell.
    }

    private func mediaSidebar(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MEDIA")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text("All Clips")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 18 : 22, weight: .heavy))
                    .foregroundStyle(.white)
                Text("No project selected - All Clips")
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.top, compact ? 14 : 20)
            .padding(.bottom, compact ? 10 : 14)

            ForEach(mediaSections, id: \.0) { item in
                Button {
                    withAnimation(.snappy(duration: 0.16)) { sidePanel = item.0 }
                } label: {
                    MediaSidebarRow(title: item.0, value: item.1, icon: item.2, active: sidePanel == item.0, compact: compact)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, compact ? 8 : 12)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                BMStatusPill(title: "Clips", value: "\(controller.galleryItems.count)", color: controller.galleryItems.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                BMStatusPill(title: "Upload", value: "Waiting", color: BlackmagicCamStyle.amber)
            }
            .padding(compact ? 12 : 18)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.94), BlackmagicCamStyle.rail.opacity(0.94)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var mediaSections: [(String, String, String)] {
        [
            ("All Clips", "\(controller.galleryItems.count)", "rectangle.stack.fill"),
            ("Project", "No project", "folder.fill"),
            ("External Drive", "Private Storage", "externaldrive.fill"),
            ("Upload Queue", "Proxy / Original", "arrow.up.circle.fill"),
            ("Clip Details", selectedItem?.filename ?? "None", "info.circle.fill")
        ]
    }

    private func mediaPool(compact: Bool) -> some View {
        VStack(spacing: 0) {
            mediaToolbar(compact: compact)
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 140 : 190), spacing: compact ? 10 : 14)], spacing: compact ? 10 : 14) {
                        ForEach(controller.galleryItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                GalleryCard(item: item, selected: selectedItem?.id == item.id, compact: compact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(compact ? 14 : 22)
                }
            }
        }
        .background(BlackmagicCamStyle.studioGradient)
    }

    private func mediaToolbar(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MediaViewToolbar".uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(BlackmagicCamStyle.cyan)
                Text(sidePanel)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 22 : 28, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()
            toolbarPill("Sort", "Date Time", icon: "arrow.up.arrow.down")
            toolbarPill("Filter", "All", icon: "line.3.horizontal.decrease.circle")
            toolbarPill("Upload", "Proxy", icon: "arrow.up.circle")
            Button {
                Task { await controller.refreshGallery() }
            } label: {
                toolbarPill("Refresh", "Media", icon: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 10 : 14)
        .background(.black.opacity(0.62))
        .overlay(Rectangle().fill(.white.opacity(0.10)).frame(height: 1), alignment: .bottom)
    }

    private func toolbarPill(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.50))
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

private struct MediaSidebarRow: View {
    let title: String
    let value: String
    let icon: String
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 11) {
            BMDAssetIcon(name: assetName, active: active, fallback: icon, color: active ? .white : BlackmagicCamStyle.cyan, size: compact ? 15 : 18)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background((active ? BlackmagicCamStyle.activeBlue : BlackmagicCamStyle.cyan.opacity(0.14)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
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

    private var assetName: String {
        switch title {
        case "All Clips": return "Media"
        case "Project": return "ProjectUpload"
        case "External Drive": return "StorageDrive"
        case "Upload Queue": return "UploadToCloud"
        case "Clip Details": return "Slate"
        default: return "Media"
        }
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
                        Image(systemName: "photo")
                            .font(.system(size: compact ? 28 : 38, weight: .medium))
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
                    Image(systemName: item.cachedURL == nil ? "arrow.down.circle" : "checkmark.circle.fill")
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
                        Label("SAVE", systemImage: "square.and.arrow.down")
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
