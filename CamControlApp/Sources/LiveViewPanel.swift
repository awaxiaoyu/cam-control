import CamControlCore
import Foundation
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
    @Binding var selectedTab: WorkspaceTab
    @AppStorage("liveview.captured_picture_duration") private var capturedPictureDuration = -1
    @AppStorage("picturestream.num_pictures") private var pictureStreamLimit = 6
    @AppStorage("picturestream.show_filename") private var showStreamFilename = true
    @State private var capturedReviewItem: GalleryItem?
    @State private var capturedReviewURL: URL?
    @State private var reviewTask: Task<Void, Never>?
    @State private var streamExpanded = true

    var body: some View {
        ShootingHUDLayout(
            title: deviceName,
            subtitle: controller.snapshot.deviceInfo?.manufacturer ?? "Recording image display",
            timecode: timecodeText,
            topItems: topItems,
            bottomCards: bottomCards,
            navSelection: navSelection,
            isCaptureActive: controller.isBulbActive,
            isLiveActive: controller.isLiveViewActive,
            canCapture: true,
            canFocus: controller.snapshot.capabilities.autofocus,
            canToggleLive: controller.snapshot.capabilities.liveView,
            onCapture: {
                if capturedReviewItem != nil {
                    dismissCapturedReview()
                } else {
                    Task { await controller.capture() }
                }
            },
            onToggleLive: {
                Task { await controller.toggleLiveView() }
            },
            onFocus: {
                Task { await controller.focus() }
            },
            onRefresh: {
                Task { await controller.refreshProperties() }
            },
            onNavigate: navigate
        ) {
            liveViewContent
        }
        .overlay(alignment: .bottomLeading) {
            if selectedTab == .live {
                pictureStreamOverlay
            }
        }
        .background(Color.black)
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
        // Firmware/update note: camera firmware updates usually alter property availability/encoding; update topItems/propertyDisplay mappings before changing HUD layout.
    }

    private var liveViewContent: some View {
        ZStack {
            if let capturedReviewItem {
                capturedReview(for: capturedReviewItem)
            } else if let frame = controller.liveViewFrame {
                liveFrame(frame)
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.76), Color.gray.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 12) {
                    Image(systemName: controller.snapshot.capabilities.liveView ? "viewfinder" : "camera.viewfinder")
                        .font(.system(size: 48, weight: .medium))
                    Text(controller.snapshot.capabilities.liveView ? "Start live view from the right rail" : "Live view is not exposed by this camera")
                        .font(.headline)
                }
                .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func stripLabel(_ title: String, systemImage: String, active: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
        .tracking(0.8)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .blackmagicButtonShell(cornerRadius: 12, active: active)
    }

    @ViewBuilder
    private var pictureStreamOverlay: some View {
        let items = Array(controller.pictureStreamItems.prefix(max(0, pictureStreamLimit)))
        if pictureStreamLimit > 0, !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        streamExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: streamExpanded ? "chevron.down" : "chevron.up")
                        Text("MEDIA POOL")
                        Text("\(items.count)")
                            .foregroundStyle(BlackmagicCamStyle.okGreen)
                    }
                    .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.58), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if streamExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(items) { item in
                                PictureStreamThumbnail(item: item, showFilename: showStreamFilename) {
                                    presentCapturedReview(item, obeyNever: false)
                                }
                                .frame(width: 76, height: 86)
                            }
                        }
                    }
                    .frame(maxWidth: 430)
                }
            }
            .padding(.leading, 18)
            .padding(.bottom, 112)
            .transition(.move(edge: .leading).combined(with: .opacity))
            // Firmware/update note: picture stream overlay now maps Blackmagic MediaPoolView thumbnail behavior without adding an app-style bottom bar under the camera HUD.
        }
    }

    private var topItems: [ShootingHUDTopItem] {
        [
            ShootingHUDTopItem(title: "LENS", value: lensValue),
            ShootingHUDTopItem(title: "FPS", value: frameRateValue),
            ShootingHUDTopItem(title: "SHUTTER", value: propertyDisplay(.shutterSpeed), isAuto: isReadOnly(.shutterSpeed), isMonospaced: true),
            ShootingHUDTopItem(title: "IRIS", value: propertyDisplay(.aperture), isDimmed: property(.aperture) == nil, isMonospaced: true),
            ShootingHUDTopItem(title: "ISO", value: propertyDisplay(.iso), isAuto: isReadOnly(.iso), isMonospaced: true),
            ShootingHUDTopItem(title: "WB", value: whiteBalanceValue, isAuto: isReadOnly(.whiteBalance) || isReadOnly(.colorTemperature)),
            ShootingHUDTopItem(title: "TINT", value: propertyDisplay(.exposureCompensation), isMonospaced: true),
            ShootingHUDTopItem(title: "Format", value: "4K 16:9")
        ]
    }

    private var bottomCards: [ShootingHUDBottomCard] {
        let histogram: [CGFloat]
        if let histogramData = controller.liveViewFrame?.histogram {
            histogram = histogramBars(from: histogramData)
        } else {
            histogram = ShootingHUDFixtures.histogramBars
        }
        let battery = property(.batteryLevel)?.value ?? 0
        let progress = battery > 0 ? min(1, Double(battery) / 100.0) : 0.01
        let shots = property(.availableShots).map { "\($0.value) shots" } ?? "Ready"
        let trailing = battery > 0 ? "\(battery)%" : "--"
        return [
            ShootingHUDBottomCard(title: "Rec.709", kind: .histogram(histogram)),
            ShootingHUDBottomCard(title: "Storage", kind: .storage(primary: shots, progress: progress, trailing: trailing)),
            ShootingHUDBottomCard(title: "Audio", kind: .audio([0.18, 0.16]))
        ]
    }

    private var navSelection: ShootingHUDNavItem {
        switch selectedTab {
        case .live: return .camera
        case .controls: return .settings
        case .gallery: return .media
        case .chat: return .chat
        }
    }

    private var deviceName: String {
        if case .connected(let device) = controller.status {
            return device.name
        }
        return "Camera"
    }

    private var timecodeText: String {
        let seconds = controller.isBulbActive ? controller.bulbElapsedSeconds : 0
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d:00", hours, minutes, secs)
    }

    private var lensValue: String {
        controller.snapshot.deviceInfo?.model ?? "--"
    }

    private var frameRateValue: String {
        if controller.isLiveViewActive { return "Live" }
        return "--"
    }

    private var whiteBalanceValue: String {
        if let colorTemp = property(.colorTemperature) {
            return "\(colorTemp.value)K"
        }
        return propertyDisplay(.whiteBalance)
    }

    private func navigate(_ item: ShootingHUDNavItem) {
        switch item {
        case .camera:
            selectedTab = .live
        case .media:
            selectedTab = .gallery
        case .chat:
            selectedTab = .chat
        case .settings:
            selectedTab = .controls
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
                .font(BlackmagicCamStyle.labelFont(size: 11, weight: .heavy))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.60), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismissCapturedReview()
            } label: {
                stripLabel("LIVE", systemImage: "play.fill", active: true)
            }
            .buttonStyle(.plain)
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
            stripLabel(direction == .near ? "NEAR" : "FAR", systemImage: icon)
        }
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
            stripLabel("REVIEW", systemImage: "timer")
        }
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
            stripLabel("STREAM", systemImage: "film.stack")
        }
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

    private func property(_ key: CameraPropertyKey) -> CameraPropertyState? {
        controller.snapshot.properties.first { $0.key == key }
    }

    private func isReadOnly(_ key: CameraPropertyKey) -> Bool {
        guard let prop = property(key) else { return false }
        return prop.descriptor?.isSettable != true
    }

    private func propertyDisplay(_ key: CameraPropertyKey) -> String {
        guard let prop = property(key) else { return "--" }
        switch key {
        case .batteryLevel:
            return "\(prop.value)%"
        case .colorTemperature:
            return "\(prop.value)K"
        case .availableShots:
            return "\(prop.value)"
        case .exposureCompensation:
            return prop.value == 0 ? "0" : String(format: "%.1f", Double(prop.value) / 100.0)
        case .iso:
            return "\(prop.value)"
        case .aperture:
            if prop.value > 0, prop.value < 1_000 {
                return String(format: "f%.1f", Double(prop.value) / 100.0)
            }
            return rawDisplay(prop.value)
        case .shutterSpeed:
            if prop.value > 0, prop.value <= 8_000 {
                return "1/\(prop.value)"
            }
            return rawDisplay(prop.value)
        default:
            return rawDisplay(prop.value)
        }
    }

    private func rawDisplay(_ value: Int64) -> String {
        "0x\(String(UInt64(bitPattern: value), radix: 16))"
    }

    private func histogramBars(from data: Data, count: Int = 32) -> [CGFloat] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return ShootingHUDFixtures.histogramBars }
        let bucketSize = max(1, bytes.count / count)
        return (0..<count).map { bucket in
            let start = bucket * bucketSize
            let end = min(bytes.count, start + bucketSize)
            guard start < end else { return 0 }
            let sum = bytes[start..<end].reduce(0) { $0 + Int($1) }
            return CGFloat(sum) / CGFloat((end - start) * 255)
        }
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    if let url = item.thumbnailURL ?? item.cachedURL, let image = PlatformImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(BlackmagicCamStyle.mutedText)
                    }
                }
                .frame(width: 90, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))

                if showFilename {
                    Text(item.filename)
                        .font(BlackmagicCamStyle.labelFont(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
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

