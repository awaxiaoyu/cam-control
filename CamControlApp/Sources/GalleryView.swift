import CamControlCore
import Foundation
import SwiftUI
import UIKit

struct GalleryView: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedItem: GalleryItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    BMSectionHeader(
                        eyebrow: "Media",
                        title: "Clip and still bin",
                        subtitle: "A Blackmagic-style media browser with large thumbnails, file metadata, and direct preview."
                    )
                    Spacer(minLength: 12)
                    BMStatusPill(title: "Items", value: "\(controller.galleryItems.count)", color: controller.galleryItems.isEmpty ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
                }

                if controller.galleryItems.isEmpty {
                    BMEmptyState(
                        systemImage: "photo.on.rectangle.angled",
                        title: "No captured media",
                        subtitle: "Captured objects from the tethered camera will appear here. Pull down to refresh the media object list."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                        ForEach(controller.galleryItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                GalleryCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(BlackmagicCamStyle.studioGradient)
        .refreshable {
            await controller.refreshGallery()
        }
        .fullScreenCover(item: $selectedItem) { item in
            PicturePreview(item: item)
                .environmentObject(controller)
        }
        // Firmware/update note: media tiles consume GalleryItem metadata only; update object-format parsing in the camera driver when firmware adds new media formats.
    }
}

private struct GalleryCard: View {
    let item: GalleryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.38))

                if let url = item.thumbnailURL ?? item.cachedURL, let image = PlatformImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo")
                            .font(.system(size: 38, weight: .medium))
                        Text("NO THUMB")
                            .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                }

                Text(formatCode)
                    .font(BlackmagicCamStyle.readoutFont(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .padding(9)
            }
            .frame(height: 142)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))

            VStack(alignment: .leading, spacing: 7) {
                Text(item.filename)
                    .font(BlackmagicCamStyle.labelFont(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.compressedSize), countStyle: .file))
                    Spacer()
                    Image(systemName: item.cachedURL == nil ? "arrow.down.circle" : "checkmark.circle.fill")
                }
                .font(BlackmagicCamStyle.readoutFont(size: 11, weight: .medium))
                .foregroundStyle(item.cachedURL == nil ? BlackmagicCamStyle.amber : BlackmagicCamStyle.okGreen)
            }
        }
        .padding(12)
        .blackmagicPanel(cornerRadius: 22)
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
        NavigationStack {
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
                        ProgressView()
                            .tint(BlackmagicCamStyle.cyan)
                        Text("LOADING MEDIA")
                            .font(BlackmagicCamStyle.labelFont(size: 12, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(BlackmagicCamStyle.mutedText)
                    }
                    .task {
                        url = await controller.download(item)
                    }
                }
            }
            .navigationTitle(item.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(url == nil)
                    .foregroundStyle(url == nil ? BlackmagicCamStyle.mutedText : BlackmagicCamStyle.cyan)
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let url, let image = PlatformImage(contentsOfFile: url.path) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
