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
            let primaryRailWidth = compact ? CGFloat(92) : min(CGFloat(132), max(CGFloat(118), proxy.size.width * 0.064))
            let navRailWidth = compact ? CGFloat(98) : min(CGFloat(148), max(CGFloat(124), proxy.size.width * 0.072))
            let availableViewportWidth = max(CGFloat(1), proxy.size.width - primaryRailWidth - navRailWidth)
            HStack(spacing: 0) {
                ZStack {
                    BlackmagicCamStyle.canvas
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
            .background(BlackmagicCamStyle.canvas)
        }
        .background(BlackmagicCamStyle.canvas)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private func recordingViewport(compact: Bool) -> some View {
        ZStack {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.72), Color.gray.opacity(0.58), Color.black.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Rectangle())

            monitorGuides(compact: compact)

            VStack(spacing: 0) {
                topStatusBar(compact: compact)
                    .padding(.horizontal, compact ? 10 : 20)
                    .padding(.top, compact ? 8 : 18)
                hudMicroStatusStrip(compact: compact)
                    .padding(.top, compact ? 7 : 10)
                Spacer(minLength: 0)
                monitorToolStrip(compact: compact)
                    .padding(.bottom, compact ? 8 : 12)
                bottomMonitorDeck(compact: compact)
                    .padding(.horizontal, compact ? 10 : 20)
                    .padding(.bottom, compact ? 10 : 18)
            }
        }
        .overlay(Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .background(BlackmagicCamStyle.monitor)
        .accessibilityLabel("Recording image display area")
    }

    private func topStatusBar(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 8 : 12) {
            HStack(spacing: compact ? 8 : 12) {
                ForEach(Array(topItems.prefix(4))) { item in
                    topReadout(item, compact: compact)
                }
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 10)
            .background(Color.black.opacity(0.50), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))

            Spacer(minLength: compact ? 6 : 18)

            VStack(spacing: compact ? 2 : 4) {
                Text(timecode)
                    .font(BlackmagicCamStyle.timecodeFont(size: compact ? 31 : 54))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.65), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isCaptureActive ? "REC ACTIVE" : "STBY")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : BlackmagicCamStyle.mutedText)
            }
            .frame(minWidth: compact ? 170 : 330)

            Spacer(minLength: compact ? 6 : 18)

            HStack(spacing: compact ? 8 : 12) {
                ForEach(Array(topItems.dropFirst(4).prefix(compact ? 2 : 4))) { item in
                    topReadout(item, compact: compact)
                }
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 10)
            .background(Color.black.opacity(0.50), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    private func topReadout(_ item: ShootingHUDTopItem, compact: Bool) -> some View {
        Group {
            if item.isFormatBadge {
                VStack(spacing: compact ? 1 : 2) {
                    Text(item.primaryFormatLine)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 17 : 24, weight: .heavy))
                    Text(item.secondaryFormatLine)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 12, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 11 : 17)
                .padding(.vertical, compact ? 5 : 8)
                .background(BlackmagicCamStyle.activeBlue.opacity(0.32), in: RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                        .stroke(BlackmagicCamStyle.cyan.opacity(0.72), lineWidth: compact ? 1 : 1.5)
                )
            } else {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(item.isDimmed ? .white.opacity(0.28) : BlackmagicCamStyle.mutedText)
                        if item.isAuto {
                            Text("A")
                                .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, compact ? 4 : 5)
                                .padding(.vertical, 1)
                                .background(BlackmagicCamStyle.activeBlue, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    Text(item.value)
                        .font(item.isMonospaced ? BlackmagicCamStyle.readoutFont(size: compact ? 18 : 28, weight: .medium) : BlackmagicCamStyle.labelFont(size: compact ? 18 : 28, weight: .semibold))
                        .foregroundStyle(item.isDimmed ? .white.opacity(0.28) : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(minWidth: compact ? 44 : 82, alignment: .leading)
            }
        }
        // Firmware/update note: add new camera firmware-specific readouts by mapping new CameraPropertyKey values into ShootingHUDTopItem here, not by hardcoding vendor strings in the view body.
    }

    private func hudMicroStatusStrip(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            Text(title.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, compact ? 9 : 12)
                .padding(.vertical, compact ? 6 : 8)
                .background(Color.black.opacity(0.46), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))

            Text(subtitle.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(BlackmagicCamStyle.mutedText)
                .lineLimit(1)

            Spacer(minLength: 8)

            ForEach(hudStatusBadges, id: \.0) { badge in
                HStack(spacing: 5) {
                    Image(systemName: badge.1)
                    Text(badge.0)
                }
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                .foregroundStyle(badge.2)
                .padding(.horizontal, compact ? 7 : 10)
                .padding(.vertical, compact ? 5 : 7)
                .background(Color.black.opacity(0.42), in: Capsule())
                .overlay(Capsule().stroke(badge.2.opacity(0.26), lineWidth: 1))
            }
        }
        .padding(.horizontal, compact ? 10 : 20)
        // Firmware/update note: these badges mirror reversed IconAe/IconAf/IconAwb/IconLock/IconLut/IconStream/IconTimelapse asset families; keep them capability-driven as new firmware exposes state flags.
    }

    private var hudStatusBadges: [(String, String, Color)] {
        [
            ("AE", "a.circle.fill", BlackmagicCamStyle.activeBlue),
            ("AF", "scope", canFocus ? BlackmagicCamStyle.activeBlue : BlackmagicCamStyle.mutedText),
            ("AWB", "sun.max.fill", BlackmagicCamStyle.amber),
            ("LOCK", "lock.fill", BlackmagicCamStyle.mutedText),
            ("LUT", "camera.filters", BlackmagicCamStyle.cyan),
            ("STRM", "dot.radiowaves.left.and.right", isLiveActive ? BlackmagicCamStyle.okGreen : BlackmagicCamStyle.mutedText),
            ("TL", "timer", BlackmagicCamStyle.mutedText)
        ]
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

    private func monitorToolStrip(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            MonitorToolChip(title: "FALSE COLOR", systemImage: "circle.lefthalf.filled", color: BlackmagicCamStyle.amber, compact: compact)
            MonitorToolChip(title: "FOCUS ASSIST", systemImage: "scope", color: BlackmagicCamStyle.cyan, compact: compact, active: canFocus)
            MonitorToolChip(title: "GUIDES", systemImage: "square.grid.3x3", color: .white.opacity(0.74), compact: compact, active: true)
            MonitorToolChip(title: "DISPLAY LUT", systemImage: "camera.filters", color: BlackmagicCamStyle.cyan, compact: compact, active: true)
            MonitorToolChip(title: "CLEAN FEED", systemImage: "rectangle.dashed", color: .white.opacity(0.68), compact: compact)
            MonitorToolChip(title: "HDMI", systemImage: "display", color: .white.opacity(0.58), compact: compact)
        }
        .padding(.horizontal, compact ? 10 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Firmware/update note: monitor tools are UI mirrors for reversed Display Histogram/Audio/Storage/LUT/Focus Assist/Guides/False Color strings; wire live camera support through capabilities later.
    }

    @ViewBuilder
    private func bottomCard(_ card: ShootingHUDBottomCard, compact: Bool) -> some View {
        switch card.kind {
        case .histogram(let bars):
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(card.title.uppercased())
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                        .foregroundStyle(BlackmagicCamStyle.mutedText)
                    Spacer()
                    Text("RGB")
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                        .foregroundStyle(BlackmagicCamStyle.cyan)
                }
                HistogramBars(bars: bars)
                    .frame(height: compact ? 42 : 68)
            }
            .padding(compact ? 8 : 11)
            .frame(width: compact ? 150 : 300, height: compact ? 78 : 120)
            .blackmagicPanel(cornerRadius: 12, borderOpacity: 0.18)
        case .storage(let primary, let progress, let trailing):
            HStack(spacing: compact ? 8 : 14) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: compact ? 25 : 36, weight: .medium))
                    .foregroundStyle(BlackmagicCamStyle.okGreen)
                    .frame(width: compact ? 38 : 56)
                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    Text(primary)
                        .font(BlackmagicCamStyle.readoutFont(size: compact ? 18 : 30, weight: .semibold))
                        .foregroundStyle(.white)
                    ProgressView(value: progress)
                        .tint(BlackmagicCamStyle.okGreen)
                    HStack {
                        Text("Storage")
                        Spacer()
                        Text(trailing)
                    }
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
                }
            }
            .padding(compact ? 8 : 12)
            .frame(width: compact ? 176 : 330, height: compact ? 78 : 120)
            .blackmagicPanel(cornerRadius: 12, borderOpacity: 0.18)
        case .audio(let levels):
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
                    .foregroundStyle(BlackmagicCamStyle.mutedText)
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
                .font(BlackmagicCamStyle.readoutFont(size: compact ? 8 : 11, weight: .semibold))
                .foregroundStyle(BlackmagicCamStyle.mutedText)
            }
            .padding(compact ? 8 : 11)
            .frame(width: compact ? 184 : 300, height: compact ? 78 : 120)
            .blackmagicPanel(cornerRadius: 12, borderOpacity: 0.18)
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
        VStack(spacing: compact ? 12 : 18) {
            railButton(icon: "viewfinder", label: "HUD", compact: compact, action: onRefresh)

            railButton(
                icon: isLiveActive ? "pause.viewfinder" : "camera.viewfinder",
                label: isLiveActive ? "LIVE" : "VIEW",
                compact: compact,
                active: isLiveActive,
                enabled: canToggleLive,
                action: onToggleLive
            )

            railButton(icon: "plus.forwardslash.minus", label: "AF", compact: compact, enabled: canFocus, action: onFocus)

            Button(action: onCapture) {
                recordButton(compact: compact)
            }
            .buttonStyle(.plain)
            .disabled(!canCapture)
            .opacity(canCapture ? 1 : 0.4)
            .accessibilityLabel(isCaptureActive ? "Stop capture" : "Capture")

            railButton(icon: "camera.macro", label: "LENS", compact: compact, active: false, enabled: false, action: {})

            Button(action: {}) {
                VStack(spacing: 5) {
                    Text("LUT")
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 15, weight: .heavy))
                    Text("709")
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(width: compact ? 62 : 78, height: compact ? 50 : 62)
                .blackmagicButtonShell(cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.55)

            Spacer(minLength: 0)

            VStack(spacing: compact ? 5 : 7) {
                Image(systemName: "scope")
                    .font(.system(size: compact ? 25 : 32, weight: .medium))
                Text("TOOLS")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .tracking(1.1)
            }
            .foregroundStyle(BlackmagicCamStyle.cyan)
            .frame(width: compact ? 62 : 78, height: compact ? 54 : 68)
            .blackmagicButtonShell(cornerRadius: 14, active: true)
        }
        .padding(.top, compact ? 16 : 22)
        .padding(.bottom, compact ? 16 : 24)
        .frame(maxWidth: .infinity)
        .background(BlackmagicCamStyle.rail)
        .overlay(Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1), alignment: .leading)
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1), alignment: .trailing)
        // Firmware/update note: keep vendor-specific controls optional and capability-gated so future camera firmware changes only require capability/property mapping updates.
    }

    private func navRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 22) {
            ForEach(ShootingHUDNavItem.allCases) { item in
                Button {
                    onNavigate(item)
                } label: {
                    VStack(spacing: compact ? 6 : 9) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: compact ? 21 : 28, weight: .semibold))
                        Text(item.title)
                            .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 13, weight: .heavy))
                    }
                    .foregroundStyle(navSelection == item ? .white : BlackmagicCamStyle.cyan.opacity(0.74))
                    .frame(width: compact ? 72 : 94, height: compact ? 68 : 94)
                    .blackmagicButtonShell(cornerRadius: 14, active: navSelection == item)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, compact ? 18 : 28)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func monitorGuides(compact: Bool) -> some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.16), lineWidth: compact ? 1 : 1.5)
                .padding(.horizontal, compact ? 46 : 72)
                .padding(.vertical, compact ? 28 : 44)
            Rectangle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .padding(.horizontal, compact ? 78 : 122)
                .padding(.vertical, compact ? 48 : 76)
            RuleOfThirds()
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [6, 8]))
                .padding(.horizontal, compact ? 46 : 72)
                .padding(.vertical, compact ? 28 : 44)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func railButton(
        icon: String,
        label: String,
        compact: Bool,
        active: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: compact ? 4 : 7) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 24 : 32, weight: .semibold))
                Text(label)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .tracking(1.0)
            }
            .foregroundStyle(active ? .white : BlackmagicCamStyle.strongText)
            .frame(width: compact ? 62 : 78, height: compact ? 54 : 70)
            .blackmagicButtonShell(cornerRadius: 14, active: active)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func recordButton(compact: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.96), lineWidth: compact ? 3.5 : 5)
                .frame(width: compact ? 66 : 86, height: compact ? 66 : 86)
            Circle()
                .fill(isCaptureActive ? BlackmagicCamStyle.recordRed : BlackmagicCamStyle.recordRed.opacity(0.62))
                .frame(width: compact ? 38 : 50, height: compact ? 38 : 50)
                .shadow(color: BlackmagicCamStyle.recordRed.opacity(isCaptureActive ? 0.85 : 0.35), radius: isCaptureActive ? 12 : 5)
        }
        .frame(width: compact ? 72 : 92, height: compact ? 72 : 96)
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
        case .camera: return "Camera"
        case .media: return "Media"
        case .chat: return "Chat"
        case .settings: return "Settings"
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

private struct MonitorToolChip: View {
    let title: String
    let systemImage: String
    let color: Color
    let compact: Bool
    var active = false

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 11 : 14, weight: .bold))
            Text(title)
                .lineLimit(1)
        }
        .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
        .tracking(0.7)
        .foregroundStyle(active ? .white : color)
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 6 : 8)
        .background((active ? color.opacity(0.22) : Color.black.opacity(0.46)), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                .stroke((active ? color : Color.white).opacity(active ? 0.48 : 0.12), lineWidth: 1)
        )
    }
}

private struct RuleOfThirds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let oneThirdX = rect.minX + rect.width / 3
        let twoThirdX = rect.minX + rect.width * 2 / 3
        let oneThirdY = rect.minY + rect.height / 3
        let twoThirdY = rect.minY + rect.height * 2 / 3

        path.move(to: CGPoint(x: oneThirdX, y: rect.minY))
        path.addLine(to: CGPoint(x: oneThirdX, y: rect.maxY))
        path.move(to: CGPoint(x: twoThirdX, y: rect.minY))
        path.addLine(to: CGPoint(x: twoThirdX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: oneThirdY))
        path.addLine(to: CGPoint(x: rect.maxX, y: oneThirdY))
        path.move(to: CGPoint(x: rect.minX, y: twoThirdY))
        path.addLine(to: CGPoint(x: rect.maxX, y: twoThirdY))
        return path
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
