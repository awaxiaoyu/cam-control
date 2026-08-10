import CamControlCore
import SwiftUI

struct ShootingHUDLayout<Preview: View>: View {
    let preview: Preview
    let title: String
    let subtitle: String
    let timecode: String
    let topItems: [ShootingHUDTopItem]
    let bottomCards: [ShootingHUDBottomCard]
    let navSelection: ShootingHUDNavItem
    let onCapture: () -> Void
    let onToggleLive: () -> Void
    let onFocus: () -> Void
    let onRefresh: () -> Void
    let onNavigate: (ShootingHUDNavItem) -> Void
    let isCaptureActive: Bool
    let isLiveActive: Bool
    let canCapture: Bool
    let canFocus: Bool
    let canToggleLive: Bool

    init(
        title: String,
        subtitle: String,
        timecode: String,
        topItems: [ShootingHUDTopItem],
        bottomCards: [ShootingHUDBottomCard],
        navSelection: ShootingHUDNavItem,
        isCaptureActive: Bool,
        isLiveActive: Bool,
        canCapture: Bool,
        canFocus: Bool,
        canToggleLive: Bool,
        onCapture: @escaping () -> Void,
        onToggleLive: @escaping () -> Void,
        onFocus: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onNavigate: @escaping (ShootingHUDNavItem) -> Void,
        @ViewBuilder preview: () -> Preview
    ) {
        self.title = title
        self.subtitle = subtitle
        self.timecode = timecode
        self.topItems = topItems
        self.bottomCards = bottomCards
        self.navSelection = navSelection
        self.isCaptureActive = isCaptureActive
        self.isLiveActive = isLiveActive
        self.canCapture = canCapture
        self.canFocus = canFocus
        self.canToggleLive = canToggleLive
        self.onCapture = onCapture
        self.onToggleLive = onToggleLive
        self.onFocus = onFocus
        self.onRefresh = onRefresh
        self.onNavigate = onNavigate
        self.preview = preview()
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1_200 || proxy.size.height < 700
            let primaryRailWidth = compact ? CGFloat(88) : min(CGFloat(138), max(CGFloat(118), proxy.size.width * 0.066))
            let navRailWidth = compact ? CGFloat(104) : min(CGFloat(156), max(CGFloat(128), proxy.size.width * 0.074))
            let availableViewportWidth = max(CGFloat(1), proxy.size.width - primaryRailWidth - navRailWidth)
            HStack(spacing: 0) {
                ZStack {
                    Color.black
                    recordingViewport(compact: compact)
                        .frame(width: availableViewportWidth, height: proxy.size.height)
                    edgeHandles
                        .frame(width: availableViewportWidth, height: proxy.size.height)
                }
                .frame(width: availableViewportWidth, height: proxy.size.height)

                controlRail(compact: compact)
                    .frame(width: primaryRailWidth, height: proxy.size.height)

                navRail(compact: compact)
                    .frame(width: navRailWidth, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(Color.black)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private func recordingViewport(compact: Bool) -> some View {
        ZStack {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient(colors: [Color.gray.opacity(0.72), Color.gray.opacity(0.58)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Rectangle())

            VStack(spacing: 0) {
                topStatusBar(compact: compact)
                    .padding(.horizontal, compact ? 10 : 22)
                    .padding(.top, compact ? 8 : 24)
                Spacer(minLength: 0)
                bottomMonitorDeck(compact: compact)
                    .padding(.horizontal, compact ? 10 : 22)
                    .padding(.bottom, compact ? 10 : 22)
            }
        }
        .background(Color.gray.opacity(0.65))
        .accessibilityLabel("Recording image display area")
    }

    private func topStatusBar(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 9 : 20) {
            ForEach(Array(topItems.prefix(4))) { item in
                topReadout(item, compact: compact)
            }

            Spacer(minLength: compact ? 6 : 18)

            Text(timecode)
                .font(.system(size: compact ? 30 : 52, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: compact ? 170 : 360)

            Spacer(minLength: compact ? 6 : 18)

            ForEach(Array(topItems.dropFirst(4).prefix(compact ? 2 : 4))) { item in
                topReadout(item, compact: compact)
            }
        }
    }

    private func topReadout(_ item: ShootingHUDTopItem, compact: Bool) -> some View {
        Group {
            if item.isFormatBadge {
                VStack(spacing: compact ? 1 : 2) {
                    Text(item.primaryFormatLine)
                        .font(.system(size: compact ? 17 : 24, weight: .heavy))
                    Text(item.secondaryFormatLine)
                        .font(.system(size: compact ? 8 : 12, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 11 : 17)
                .padding(.vertical, compact ? 5 : 8)
                .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 5 : 7, style: .continuous)
                        .stroke(.white.opacity(0.92), lineWidth: compact ? 1 : 1.5)
                )
            } else {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(.system(size: compact ? 11 : 15, weight: .semibold))
                            .foregroundStyle(item.isDimmed ? .black.opacity(0.45) : .white.opacity(0.94))
                        if item.isAuto {
                            Text("A")
                                .font(.system(size: compact ? 9 : 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, compact ? 4 : 5)
                                .padding(.vertical, 1)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    Text(item.value)
                        .font(.system(size: compact ? 18 : 30, weight: .medium, design: item.isMonospaced ? .monospaced : .default))
                        .foregroundStyle(item.isDimmed ? .black.opacity(0.45) : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(minWidth: compact ? 44 : 82, alignment: .leading)
            }
        }
        // Firmware/update note: add new camera firmware-specific readouts by mapping new CameraPropertyKey values into ShootingHUDTopItem here, not by hardcoding vendor strings in the view body.
    }

    private func bottomMonitorDeck(compact: Bool) -> some View {
        HStack(alignment: .bottom, spacing: compact ? 10 : 16) {
            if bottomCards.indices.contains(0) {
                bottomCard(bottomCards[0], compact: compact)
            }
            Spacer(minLength: compact ? 10 : 48)
            if bottomCards.indices.contains(1) {
                bottomCard(bottomCards[1], compact: compact)
            }
            Spacer(minLength: compact ? 10 : 48)
            if bottomCards.indices.contains(2) {
                bottomCard(bottomCards[2], compact: compact)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func bottomCard(_ card: ShootingHUDBottomCard, compact: Bool) -> some View {
        switch card.kind {
        case .histogram(let bars):
            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                HistogramBars(bars: bars)
                    .frame(height: compact ? 42 : 68)
            }
            .padding(compact ? 8 : 11)
            .frame(width: compact ? 150 : 300, height: compact ? 78 : 120)
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .storage(let primary, let progress, let trailing):
            HStack(spacing: compact ? 8 : 14) {
                Image(systemName: "iphone")
                    .font(.system(size: compact ? 25 : 36, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: compact ? 38 : 56)
                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    Text(primary)
                        .font(.system(size: compact ? 18 : 30, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    ProgressView(value: progress)
                        .tint(.blue)
                    HStack {
                        Text("Battery")
                        Spacer()
                        Text(trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(compact ? 8 : 12)
            .frame(width: compact ? 176 : 330, height: compact ? 78 : 120)
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .audio(let levels):
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                VStack(spacing: compact ? 4 : 7) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        AudioMeterRow(channel: index + 1, level: level)
                    }
                }
                HStack {
                    ForEach(["-45", "-30", "-20", "-10", "-3", "0", "3"], id: \.self) { label in
                        Text(label)
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: compact ? 8 : 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.84))
            }
            .padding(compact ? 8 : 11)
            .frame(width: compact ? 184 : 300, height: compact ? 78 : 120)
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var edgeHandles: some View {
        HStack {
            DragHandleDots()
                .padding(.leading, 12)
            Spacer()
            DragHandleDots()
                .padding(.trailing, 12)
        }
    }

    private func controlRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 28) {
            Button(action: onRefresh) {
                Image(systemName: "viewfinder")
                    .hudRailIcon(size: compact ? 32 : 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh camera state")

            Button(action: onToggleLive) {
                Image(systemName: isLiveActive ? "pause.viewfinder" : "camera.viewfinder")
                    .hudRailIcon(size: compact ? 34 : 46)
                Text("A")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canToggleLive)
            .opacity(canToggleLive ? 1 : 0.35)
            .accessibilityLabel(isLiveActive ? "Stop live view" : "Start live view")

            Button(action: onFocus) {
                Image(systemName: "plus.forwardslash.minus")
                    .hudRailIcon(size: compact ? 32 : 42)
                Text("A")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canFocus)
            .opacity(canFocus ? 1 : 0.35)
            .accessibilityLabel("Autofocus")

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: compact ? 4 : 6)
                        .frame(width: compact ? 60 : 88, height: compact ? 60 : 88)
                    Circle()
                        .fill(isCaptureActive ? Color.red.opacity(0.95) : Color.red.opacity(0.55))
                        .frame(width: compact ? 36 : 50, height: compact ? 36 : 50)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canCapture)
            .opacity(canCapture ? 1 : 0.4)
            .accessibilityLabel(isCaptureActive ? "Stop capture" : "Capture")

            Button(action: {}) {
                Image(systemName: "camera.macro")
                    .hudRailIcon(size: compact ? 31 : 40)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.55)

            Button(action: {}) {
                Text("LUT")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.9), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.55)

            Spacer(minLength: 0)

            Image(systemName: "scope")
                .hudRailIcon(size: compact ? 34 : 44)
        }
        .padding(.top, compact ? 16 : 22)
        .padding(.bottom, compact ? 16 : 24)
        .background(Color(red: 0.02, green: 0.045, blue: 0.075))
        // Firmware/update note: keep vendor-specific controls optional and capability-gated so future camera firmware changes only require capability/property mapping updates.
    }

    private func navRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 34) {
            ForEach(ShootingHUDNavItem.allCases) { item in
                Button {
                    onNavigate(item)
                } label: {
                    VStack(spacing: compact ? 5 : 9) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: compact ? 22 : 31, weight: .medium))
                        Text(item.title)
                            .font(.system(size: compact ? 11 : 16, weight: .semibold))
                    }
                    .foregroundStyle(navSelection == item ? .blue : Color(red: 0.45, green: 0.66, blue: 0.94))
                    .frame(width: compact ? 72 : 96, height: compact ? 70 : 106)
                    .background(navSelection == item ? Color.blue.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, compact ? 18 : 28)
        .background(Color.black)
    }
}

struct ShootingHUDTopItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    var isAuto = false
    var isDimmed = false
    var isMonospaced = false

    var isFormatBadge: Bool {
        title == "格式" || title == "Format"
    }

    var primaryFormatLine: String {
        value.split(separator: " ").first.map(String.init) ?? value
    }

    var secondaryFormatLine: String {
        let parts = value.split(separator: " ")
        return parts.dropFirst().first.map(String.init) ?? "16:9"
    }
}

struct ShootingHUDBottomCard: Identifiable {
    let id = UUID()
    let title: String
    let kind: Kind

    enum Kind {
        case histogram([CGFloat])
        case storage(primary: String, progress: Double, trailing: String)
        case audio([Double])
    }
}

enum ShootingHUDNavItem: String, CaseIterable, Identifiable {
    case camera
    case media
    case chat
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return "摄影机"
        case .media: return "媒体"
        case .chat: return "聊天"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: return "video"
        case .media: return "play.rectangle"
        case .chat: return "ellipsis.message"
        case .settings: return "gearshape"
        }
    }
}

private struct DragHandleDots: View {
    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 7)
        .background(.black.opacity(0.45), in: Capsule())
        .accessibilityHidden(true)
    }
}

private struct HistogramBars: View {
    let bars: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            let values = bars.isEmpty ? ShootingHUDFixtures.histogramBars : bars
            let width = max(1, proxy.size.width / CGFloat(values.count))
            ZStack(alignment: .bottomLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.2))
                }
                .stroke(.white.opacity(0.55), lineWidth: 1)

                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        Capsule()
                            .fill(index.isMultiple(of: 3) ? Color.blue.opacity(0.86) : Color.white.opacity(0.74))
                            .frame(width: max(1, width - 1), height: max(2, proxy.size.height * value))
                    }
                }
            }
        }
        .accessibilityLabel("Histogram")
    }
}

private struct AudioMeterRow: View {
    let channel: Int
    let level: Double

    var body: some View {
        HStack(spacing: 7) {
            Text("\(channel)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 10)
            GeometryReader { proxy in
                let value = CGFloat(max(0, min(level, 1)))
                let greenWidth = proxy.size.width * min(value, 0.62)
                let yellowWidth = proxy.size.width * max(0, min(value - 0.62, 0.24))
                let redWidth = proxy.size.width * max(0, min(value - 0.86, 0.14))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.green.opacity(0.22))
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.green).frame(width: greenWidth)
                        Rectangle().fill(Color.yellow.opacity(0.55)).frame(width: yellowWidth)
                        Rectangle().fill(Color.red.opacity(0.75)).frame(width: redWidth)
                    }
                    ForEach([CGFloat(0.62), CGFloat(0.86), CGFloat(0.96)], id: \.self) { tick in
                        Rectangle()
                            .fill(.black.opacity(0.85))
                            .frame(width: 2)
                            .offset(x: proxy.size.width * tick)
                    }
                }
            }
            .frame(height: 12)
        }
    }
}

private extension Image {
    func hudRailIcon(size: CGFloat) -> some View {
        self
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size + 14, height: size + 14)
    }
}

enum ShootingHUDFixtures {
    static let histogramBars: [CGFloat] = [
        0.06, 0.05, 0.05, 0.06, 0.07, 0.09, 0.14, 0.26,
        0.48, 0.74, 0.96, 0.72, 0.42, 0.24, 0.16, 0.11,
        0.08, 0.06, 0.05, 0.05, 0.05, 0.04, 0.04, 0.04,
        0.04, 0.04, 0.05, 0.05, 0.06, 0.05, 0.05, 0.05
    ]
}

