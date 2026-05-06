import CamControlCore
import SwiftUI

private struct ReviewDurationOption: Identifiable {
    let value: Int
    let label: String
    var id: Int { value }
}

private let reviewDurationOptions = [
    ReviewDurationOption(value: -2, label: "Never"),
    ReviewDurationOption(value: -1, label: "Manual"),
    ReviewDurationOption(value: 2, label: "2s"),
    ReviewDurationOption(value: 4, label: "4s"),
    ReviewDurationOption(value: 6, label: "6s"),
    ReviewDurationOption(value: 8, label: "8s"),
    ReviewDurationOption(value: 10, label: "10s"),
    ReviewDurationOption(value: 15, label: "15s"),
    ReviewDurationOption(value: 20, label: "20s")
]

private let streamLimitOptions = [0, 2, 4, 6, 8, 10, 15, 20]

struct LiveViewPanel: View {
    @EnvironmentObject private var controller: CameraController
    @AppStorage("liveview.captured_picture_duration") private var capturedPictureDuration = -1
    @AppStorage("picturestream.num_pictures") private var pictureStreamLimit = 6
    @AppStorage("picturestream.show_filename") private var showStreamFilename = true
    @State private var capturedReviewItem: GalleryItem?
    @State private var capturedReviewURL: URL?
    @State private var reviewTask: Task<Void, Never>?
    @State private var streamExpanded = true

    var body: some View {
        VStack(spacing: 12) {
            liveViewStage
            liveControls
            pictureStream
        }
        .onChange(of: controller.pictureStreamItems.first?.id) { _, _ in
            guard let item = controller.pictureStreamItems.first else { return }
            presentCapturedReview(item, obeyNever: true)
        }
        .onChange(of: capturedPictureDuration) { _, _ in
            guard let item = capturedReviewItem else { return }
            presentCapturedReview(item, obeyNever: false)
        }
        .onDisappear {
            reviewTask?.cancel()
        }
    }

    private var liveViewStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
            if let capturedReviewItem {
                capturedReview(for: capturedReviewItem)
            } else if let frame = controller.liveViewFrame {
                liveFrame(frame)
            } else {
                Image(systemName: "viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .padding(.horizontal)
    }

    private var liveControls: some View {
        HStack(spacing: 10) {
            Button {
                if capturedReviewItem != nil {
                    dismissCapturedReview()
                } else {
                    Task { await controller.toggleLiveView() }
                }
            } label: {
                Label(controller.isLiveViewActive ? "Stop" : "Live", systemImage: controller.isLiveViewActive ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!controller.snapshot.capabilities.liveView && capturedReviewItem == nil)

            Button {
                Task { await controller.focus() }
            } label: {
                Label("AF", systemImage: "scope")
            }
            .buttonStyle(.bordered)
            .disabled(!controller.snapshot.capabilities.autofocus)

            lensMenu(direction: .near, icon: "minus.magnifyingglass")
            lensMenu(direction: .far, icon: "plus.magnifyingglass")
            reviewMenu
            streamMenu
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var pictureStream: some View {
        let items = Array(controller.pictureStreamItems.prefix(max(0, pictureStreamLimit)))
        if pictureStreamLimit > 0, !items.isEmpty {
            VStack(spacing: 8) {
                HStack {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            streamExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: streamExpanded ? "chevron.down" : "chevron.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text("Picture stream")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                if streamExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(items) { item in
                                PictureStreamThumbnail(item: item, showFilename: showStreamFilename) {
                                    presentCapturedReview(item, obeyNever: false)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    private func liveFrame(_ frame: LiveViewFrame) -> some View {
        ZoomableFrame(onTapNormalized: { point in
            Task { await controller.setLiveViewAfArea(x: point.x, y: point.y) }
        }) {
            ZStack {
                LiveImage(data: frame.jpegData)
                AutofocusOverlay(frame: frame)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if controller.snapshot.capabilities.histogram, let histogram = frame.histogram {
                HistogramOverlay(histogram: histogram)
                    .padding(10)
            }
        }
    }

    private func capturedReview(for item: GalleryItem) -> some View {
        ZStack {
            if let capturedReviewURL, let image = PlatformImage(contentsOfFile: capturedReviewURL.path) {
                ZoomableFrame {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .task {
                        await loadCapturedReviewImage(for: item)
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            Text(item.filename)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismissCapturedReview()
            } label: {
                Label("Live", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(10)
        }
    }

    private func lensMenu(direction: DriveLensDirection, icon: String) -> some View {
        Menu {
            Button("Soft") {
                Task { await controller.driveLens(direction: direction, step: .soft) }
            }
            Button("Medium") {
                Task { await controller.driveLens(direction: direction, step: .medium) }
            }
            Button("Hard") {
                Task { await controller.driveLens(direction: direction, step: .hard) }
            }
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(.bordered)
        .disabled(!controller.snapshot.capabilities.driveLens)
    }

    private var reviewMenu: some View {
        Menu {
            Picker("Review", selection: $capturedPictureDuration) {
                ForEach(reviewDurationOptions) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } label: {
            Image(systemName: "timer")
        }
        .buttonStyle(.bordered)
    }

    private var streamMenu: some View {
        Menu {
            Picker("Count", selection: $pictureStreamLimit) {
                ForEach(streamLimitOptions, id: \.self) { value in
                    Text(value == 0 ? "Off" : "\(value)").tag(value)
                }
            }
            Toggle("Filenames", isOn: $showStreamFilename)
        } label: {
            Image(systemName: "film.stack")
        }
        .buttonStyle(.bordered)
    }

    private func presentCapturedReview(_ item: GalleryItem, obeyNever: Bool) {
        reviewTask?.cancel()
        guard !(obeyNever && capturedPictureDuration == -2) else {
            dismissCapturedReview()
            return
        }
        capturedReviewItem = item
        capturedReviewURL = item.cachedURL ?? item.thumbnailURL
        Task {
            await loadCapturedReviewImage(for: item)
        }
        guard capturedPictureDuration > 0 else { return }
        reviewTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(capturedPictureDuration) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if capturedReviewItem?.id == item.id {
                    capturedReviewItem = nil
                    capturedReviewURL = nil
                }
            }
        }
    }

    private func loadCapturedReviewImage(for item: GalleryItem) async {
        var url = item.cachedURL
        if url == nil {
            url = await controller.download(item)
        }
        if url == nil {
            url = item.thumbnailURL
        }
        await MainActor.run {
            if capturedReviewItem?.id == item.id {
                capturedReviewURL = url
            }
        }
    }

    private func dismissCapturedReview() {
        reviewTask?.cancel()
        capturedReviewItem = nil
        capturedReviewURL = nil
    }
}

private struct LiveImage: View {
    let data: Data

    var body: some View {
        if let image = PlatformImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }
}

private struct PictureStreamThumbnail: View {
    let item: GalleryItem
    let showFilename: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemGroupedBackground))
                    if let url = item.thumbnailURL ?? item.cachedURL, let image = PlatformImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if showFilename {
                    Text(item.filename)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: 90, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AutofocusOverlay: View {
    let frame: LiveViewFrame

    var body: some View {
        GeometryReader { proxy in
            if let autofocusFrame = frame.autofocusFrame, let whole = frame.wholeSize, whole.width > 0, whole.height > 0 {
                Rectangle()
                    .stroke(.yellow, lineWidth: 2)
                    .frame(
                        width: autofocusFrame.width / whole.width * proxy.size.width,
                        height: autofocusFrame.height / whole.height * proxy.size.height
                    )
                    .position(
                        x: autofocusFrame.midX / whole.width * proxy.size.width,
                        y: autofocusFrame.midY / whole.height * proxy.size.height
                    )
            }
        }
    }
}

private struct HistogramOverlay: View {
    let histogram: Data

    var body: some View {
        let bars = barHeights()
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: max(2, 44 * value))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(width: 150, height: 64, alignment: .bottom)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func barHeights(count: Int = 48) -> [CGFloat] {
        let bytes = [UInt8](histogram)
        guard !bytes.isEmpty else { return [] }
        let bucketSize = max(1, bytes.count / count)
        var values: [CGFloat] = []
        values.reserveCapacity(count)
        for bucket in 0..<count {
            let start = bucket * bucketSize
            let end = min(bytes.count, start + bucketSize)
            guard start < end else {
                values.append(0)
                continue
            }
            let sum = bytes[start..<end].reduce(0) { $0 + Int($1) }
            values.append(CGFloat(sum) / CGFloat((end - start) * 255))
        }
        return values
    }
}
