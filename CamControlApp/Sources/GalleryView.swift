import CamControlCore
import SwiftUI
import UIKit

struct GalleryView: View {
    @EnvironmentObject private var controller: CameraController
    @State private var selectedItem: GalleryItem?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(controller.galleryItems) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemGroupedBackground))
                                if let url = item.thumbnailURL ?? item.cachedURL, let image = PlatformImage(contentsOfFile: url.path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(item.filename)
                                .font(.caption)
                                .lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(item.compressedSize), countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .refreshable {
            await controller.refreshGallery()
        }
        .sheet(item: $selectedItem) { item in
            PicturePreview(item: item)
                .environmentObject(controller)
        }
    }
}

private struct PicturePreview: View {
    @EnvironmentObject private var controller: CameraController
    @Environment(\.dismiss) private var dismiss
    let item: GalleryItem
    @State private var url: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let url, let image = PlatformImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                } else {
                    ProgressView()
                        .task {
                            url = await controller.download(item)
                        }
                }
            }
            .navigationTitle(item.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(url == nil)
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let url, let image = PlatformImage(contentsOfFile: url.path) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
