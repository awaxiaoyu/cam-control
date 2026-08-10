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

    @State private var activeScroller: BlackmagicHUDScroller?
    @State private var showSlate = false
    @State private var cleanFeed = false

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
            let compact = proxy.size.width < 1_120 || proxy.size.height < 680
            ZStack {
                BlackmagicCamStyle.canvas.ignoresSafeArea()
                previewLayer
                if !cleanFeed {
                    guideLayer(compact: compact)
                    cameraChrome(compact: compact)
                    if let activeScroller {
                        VStack {
                            Spacer()
                            BlackmagicScrollerPanel(scroller: activeScroller, compact: compact) { option in
                                handle(option)
                            } onClose: {
                                withAnimation(.snappy(duration: 0.18)) { self.activeScroller = nil }
                            }
                            .padding(.horizontal, compact ? 78 : 132)
                            .padding(.bottom, compact ? 88 : 126)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(6)
                    }
                    if showSlate {
                        SlateOverlay(compact: compact) {
                            withAnimation(.snappy(duration: 0.18)) { showSlate = false }
                        }
                        .padding(compact ? 24 : 48)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .zIndex(8)
                    }
                } else {
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.snappy(duration: 0.18)) { cleanFeed = false }
                            } label: {
                                HUDAuxIndicator(title: "CLEAN FEED", value: "EXIT", color: BlackmagicCamStyle.okGreen, compact: compact)
                            }
                            .buttonStyle(.plain)
                            .padding(compact ? 8 : 16)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(BlackmagicCamStyle.canvas)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        // Firmware/update note: Blackmagic Cam 3.2.00 exposes HUDCameraControls, HUDTopIndicators, HUDTrailingIndicators, RecordButton, SlateView and the scroller families; rerun reverse_blackmagic_ipa.py before altering this shell for a new IPA.
    }

    private var previewLayer: some View {
        preview
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LinearGradient(colors: [.gray.opacity(0.78), .gray.opacity(0.52), .black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                ZStack {
                    LinearGradient(colors: [.black.opacity(0.58), .clear, .black.opacity(0.58)], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.45)], startPoint: .leading, endPoint: .trailing)
                }
                .allowsHitTesting(false)
            )
            .accessibilityLabel("Blackmagic Cam recording image display")
    }

    private func cameraChrome(compact: Bool) -> some View {
        ZStack {
            VStack(spacing: 0) {
                topHUD(compact: compact)
                    .padding(.horizontal, compact ? 10 : 18)
                    .padding(.top, compact ? 6 : 12)
                Spacer()
                monitorTools(compact: compact)
                    .padding(.horizontal, compact ? 10 : 18)
                    .padding(.bottom, compact ? 6 : 8)
                bottomControls(compact: compact)
                    .padding(.horizontal, compact ? 8 : 16)
                    .padding(.bottom, compact ? 8 : 14)
            }
            HStack {
                leadingIndicators(compact: compact).padding(.leading, compact ? 8 : 16)
                Spacer()
                trailingIndicators(compact: compact).padding(.trailing, compact ? 8 : 16)
            }
            .padding(.top, compact ? 92 : 132)
        }
    }

    private func topHUD(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 6 : 10) {
            topGroup(Array(topItems.prefix(4)), compact: compact)
            Spacer(minLength: 8)
            VStack(spacing: compact ? 2 : 3) {
                Text(timecode)
                    .font(BlackmagicCamStyle.timecodeFont(size: compact ? 34 : 58))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                HStack(spacing: 8) {
                    Circle().fill(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.38)).frame(width: 7, height: 7)
                    Text(isCaptureActive ? "RECORDING" : "STBY")
                    Text("| REC RUN").foregroundStyle(.white.opacity(0.42))
                }
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                .tracking(1.55)
                .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.74))
            }
            .padding(.horizontal, compact ? 10 : 18)
            .padding(.vertical, compact ? 4 : 7)
            .background(.black.opacity(0.30), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
            Spacer(minLength: 8)
            topGroup(Array(topItems.dropFirst(4).prefix(4)), compact: compact)
        }
    }

    private func topGroup(_ items: [ShootingHUDTopItem], compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            ForEach(items) { item in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { activeScroller = scroller(for: item) }
                } label: {
                    TopIndicatorTile(item: item, compact: compact)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 5 : 7)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func guideLayer(compact: Bool) -> some View {
        ZStack {
            RuleOfThirds()
                .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [compact ? 5 : 7, compact ? 8 : 11]))
                .padding(.horizontal, compact ? 72 : 132)
                .padding(.vertical, compact ? 64 : 98)
            RoundedRectangle(cornerRadius: 2)
                .stroke(BlackmagicCamStyle.activeBlue.opacity(0.42), lineWidth: 1)
                .frame(width: compact ? 120 : 184, height: compact ? 72 : 108)
            VStack {
                HStack {
                    FramingGuideLabel(text: "16:9", compact: compact)
                    Spacer()
                    FramingGuideLabel(text: "SAFE AREA", compact: compact)
                }
                Spacer()
                HStack {
                    FalseColorLegend(compact: compact)
                    Spacer()
                    WhiteBalanceOverlay(compact: compact, value: value(forAny: ["WB", "White Balance"]))
                }
            }
            .padding(.horizontal, compact ? 18 : 28)
            .padding(.vertical, compact ? 70 : 106)
        }
        .allowsHitTesting(false)
        // Firmware/update note: overlays mirror reversed HUDGuides, HUDFalseColor and HUDWhiteBalanceOverlay strings; only values should change for new camera firmware.
    }

    private func leadingIndicators(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 11) {
            HUDAuxIndicator(title: "LUT", value: "Rec.709", color: BlackmagicCamStyle.activeBlue, compact: compact)
            HUDAuxIndicator(title: "ZEBRA", value: "75%", color: .white.opacity(0.78), compact: compact)
            HUDAuxIndicator(title: "FOCUS", value: canFocus ? "ASSIST" : "LOCK", color: BlackmagicCamStyle.cyan, compact: compact)
            Button {
                withAnimation(.snappy(duration: 0.18)) { cleanFeed.toggle() }
            } label: {
                HUDAuxIndicator(title: "CLEAN FEED", value: cleanFeed ? "ON" : "OFF", color: BlackmagicCamStyle.okGreen, compact: compact)
            }
            .buttonStyle(.plain)
        }
    }

    private func trailingIndicators(compact: Bool) -> some View {
        VStack(alignment: .trailing, spacing: compact ? 8 : 11) {
            ForEach(ShootingHUDNavItem.allCases) { item in
                Button { onNavigate(item) } label: {
                    FloatingNavPill(item: item, selected: item == navSelection, compact: compact)
                }
                .buttonStyle(.plain)
            }
            Button {
                withAnimation(.snappy(duration: 0.18)) { showSlate = true }
            } label: {
                FloatingNavPill(title: "SLATE", systemImage: "rectangle.and.pencil.and.ellipsis", selected: showSlate, compact: compact)
            }
            .buttonStyle(.plain)
        }
        // Firmware/update note: trailing indicators map reversed HUDLeftNavMenuIndicator/HUDRightNavMenuIndicator plus SlateView.
    }

    private func monitorTools(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            monitorTool("FALSE COLOR", asset: "FalseColor", color: BlackmagicCamStyle.amber, scroller: .falseColor, compact: compact)
            monitorTool("FOCUS ASSIST", asset: "FocusAssist", color: BlackmagicCamStyle.cyan, scroller: .focusAssist, compact: compact)
            monitorTool("GUIDES", asset: "Guides", color: .white.opacity(0.82), scroller: .guides, compact: compact)
            monitorTool("ZEBRA", asset: "Zebra", color: .white.opacity(0.86), scroller: .zebra, compact: compact)
            monitorTool("DISPLAY LUT", asset: "IconLut", color: BlackmagicCamStyle.activeBlue, scroller: .lut, compact: compact)
            monitorTool("CLEAN FEED", asset: "HdmiPlay", color: .white.opacity(0.72), scroller: .monitor, compact: compact)
            Spacer(minLength: 6)
            ForEach(0..<3, id: \.self) { index in
                if bottomCards.indices.contains(index) {
                    BottomHUDPreviewCard(card: bottomCards[index], compact: compact)
                }
            }
        }
    }

    private func monitorTool(_ title: String, asset: String, color: Color, scroller: BlackmagicHUDScroller, compact: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { activeScroller = scroller }
        } label: {
            HStack(spacing: compact ? 5 : 7) {
                BMDAssetIcon(name: asset, active: activeScroller == scroller, color: color, size: compact ? 13 : 15)
                Text(title)
            }
            .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 10, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .background(.black.opacity(0.40), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func bottomControls(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: compact ? 6 : 10) {
            ForEach(bottomControlItems) { item in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { activeScroller = item.scroller }
                } label: {
                    CameraControlCell(item: item, compact: compact, active: activeScroller == item.scroller)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: compact ? 4 : 8)
            Button(action: onToggleLive) { LiveToggleButton(active: isLiveActive, enabled: canToggleLive, compact: compact) }
                .buttonStyle(.plain).disabled(!canToggleLive)
            Button(action: onFocus) { FocusAutoButton(enabled: canFocus, compact: compact) }
                .buttonStyle(.plain).disabled(!canFocus)
            Button(action: onCapture) { RecordButtonView(active: isCaptureActive, enabled: canCapture, compact: compact) }
                .buttonStyle(.plain).disabled(!canCapture)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 7 : 10)
        .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 10)
    }

    private var bottomControlItems: [BottomControlItem] {
        [
            BottomControlItem(title: "LENS", value: value(for: "Lens"), asset: "Camera", scroller: .lens),
            BottomControlItem(title: "FPS", value: value(for: "FPS"), asset: "IconStream", scroller: .fps),
            BottomControlItem(title: "SHUTTER", value: value(for: "Shutter"), asset: "IconAe", scroller: .shutter),
            BottomControlItem(title: "IRIS", value: value(forAny: ["Iris", "Aperture"]), asset: "IconAe", scroller: .iris),
            BottomControlItem(title: "ISO", value: value(for: "ISO"), asset: "IconAe", scroller: .iso),
            BottomControlItem(title: "WB", value: value(forAny: ["WB", "White Balance"]), asset: "IconAwb", scroller: .whiteBalance),
            BottomControlItem(title: "TINT", value: value(for: "Tint"), asset: "IconAwb", scroller: .tint),
            BottomControlItem(title: "LUT", value: "Rec.709", asset: "IconLut", scroller: .lut)
        ]
    }

    private func value(for title: String) -> String {
        topItems.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }?.value ?? "--"
    }

    private func value(forAny titles: [String]) -> String {
        for title in titles {
            let found = value(for: title)
            if found != "--" { return found }
        }
        return "--"
    }

    private func scroller(for item: ShootingHUDTopItem) -> BlackmagicHUDScroller {
        let key = item.title.lowercased()
        if key.contains("fps") { return .fps }
        if key.contains("shutter") { return .shutter }
        if key.contains("iris") || key.contains("aperture") { return .iris }
        if key.contains("iso") { return .iso }
        if key.contains("wb") || key.contains("white") { return .whiteBalance }
        if key.contains("tint") { return .tint }
        if key.contains("format") { return .codec }
        return .lens
    }

    private func handle(_ option: String) {
        if option == "Refresh" { onRefresh() }
        if option == "Live" { onToggleLive() }
        if option == "AF" { onFocus() }
        // Firmware/update note: scroller selections are UI placeholders until CameraController exposes Blackmagic cam_app_control style property writes.
    }
}

struct ShootingHUDTopItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    var isAuto = false
    var isDimmed = false
    var isMonospaced = false
    var isFormatBadge: Bool { title.lowercased() == "format" || value.localizedCaseInsensitiveContains("4k") }
    var primaryFormatLine: String { value.components(separatedBy: " ").first ?? value }
    var secondaryFormatLine: String {
        let trailing = value.components(separatedBy: " ").dropFirst().joined(separator: " ")
        return trailing.isEmpty ? "16:9" : trailing
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
    case camera, media, chat, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .camera: return "CAMERA"
        case .media: return "MEDIA"
        case .chat: return "CHAT"
        case .settings: return "SETTINGS"
        }
    }
    var systemImage: String {
        switch self {
        case .camera: return "video.fill"
        case .media: return "photo.on.rectangle"
        case .chat: return "ellipsis.message.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

private enum BlackmagicHUDScroller: String, Identifiable, CaseIterable {
    case lens, fps, shutter, iris, iso, whiteBalance, tint, codec, lut, focus, focusAssist, falseColor, guides, zebra, monitor, audio, stabilization
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lens: return "LensOptions"
        case .fps: return "FpsOptions"
        case .shutter: return "ShutterScroll"
        case .iris: return "IrisScroll"
        case .iso: return "IsoScroll"
        case .whiteBalance: return "WhiteBalanceScroll"
        case .tint: return "TintScroll"
        case .codec: return "CodecListView"
        case .lut: return "LutScroller"
        case .focus: return "FocusScroll"
        case .focusAssist: return "FocusAssistScroller"
        case .falseColor: return "HUDFalseColor"
        case .guides: return "FramingGuidesScroller"
        case .zebra: return "ZebraScroller"
        case .monitor: return "Monitor"
        case .audio: return "HUDAudioLevelPopUp"
        case .stabilization: return "StabilisationOptions"
        }
    }
    var eyebrow: String {
        switch self {
        case .lens, .fps, .shutter, .iris, .iso, .whiteBalance, .tint, .focus, .stabilization: return "Camera"
        case .codec: return "Record"
        case .lut: return "LUTs"
        case .focusAssist, .falseColor, .guides, .zebra, .monitor: return "Monitor"
        case .audio: return "Audio"
        }
    }
    var options: [String] {
        switch self {
        case .lens: return ["0.5x", "13mm", "24mm", "35mm", "48mm", "77mm", "Front", "Refresh"]
        case .fps: return ["23.98", "24", "25", "29.97", "30", "48", "50", "59.94", "60"]
        case .shutter: return ["1/24", "1/48", "180°", "172.8°", "1/50", "1/60", "1/120", "Auto"]
        case .iris: return ["f1.8", "f2.0", "f2.8", "f4", "f5.6", "f8", "Auto"]
        case .iso: return ["Auto", "100", "200", "400", "800", "1250", "1600", "3200", "6400"]
        case .whiteBalance: return ["Auto", "3200K", "4300K", "4700K", "5600K", "6500K", "7500K", "Lock"]
        case .tint: return ["-50", "-25", "0", "+10", "+25", "+50"]
        case .codec: return ["Apple ProRes 422 HQ", "Apple ProRes 422", "Apple ProRes 422 LT", "Apple ProRes 422 Proxy", "H.265", "4K 16:9", "HD"]
        case .lut: return BlackmagicReverseSpec.lutNames
        case .focus: return ["Near", "Soft", "Medium", "Hard", "Far", "AF", "Transition", "Marker 1", "Marker 2"]
        case .focusAssist: return ["Off", "On", "Focus Assist", "Focus Assist Color", "Blue", "Red", "Green", "White"]
        case .falseColor: return ["Off", "On", "False Color", "Exposure", "Skin", "Mid Grey", "Highlight"]
        case .guides: return ["Off", "Thirds", "Crosshair", "Safe Area", "2.39:1", "1.85:1", "4:3", "Guides Opacity", "Guides Color"]
        case .zebra: return ["Off", "50%", "60%", "70%", "75%", "80%", "90%", "95%", "100%"]
        case .monitor: return BlackmagicReverseSpec.monitorOptions
        case .audio: return BlackmagicReverseSpec.audioLabels + ["None", "iPhone Microphone", "AUDIO GAIN"]
        case .stabilization: return ["Off", "Standard", "Cinematic", "Extreme"]
        }
    }
}

private struct BottomControlItem: Identifiable, Equatable {
    let title: String
    let value: String
    let asset: String
    let scroller: BlackmagicHUDScroller
    var id: String { title }
}

private struct TopIndicatorTile: View {
    let item: ShootingHUDTopItem
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            HStack(spacing: 4) {
                Text(item.title.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .tracking(0.55)
                    .foregroundStyle(item.isDimmed ? .white.opacity(0.32) : .white.opacity(0.66))
                if item.isAuto {
                    Text("A").font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 1).background(BlackmagicCamStyle.activeBlue, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
            }
            if item.isFormatBadge {
                Text(item.primaryFormatLine.uppercased()).font(BlackmagicCamStyle.labelFont(size: compact ? 16 : 22, weight: .heavy)).foregroundStyle(.white)
                Text(item.secondaryFormatLine.uppercased()).font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .heavy)).foregroundStyle(BlackmagicCamStyle.cyan)
            } else {
                Text(item.value)
                    .font(item.isMonospaced ? BlackmagicCamStyle.readoutFont(size: compact ? 17 : 25, weight: .heavy) : BlackmagicCamStyle.labelFont(size: compact ? 17 : 25, weight: .heavy))
                    .foregroundStyle(item.isDimmed ? .white.opacity(0.34) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
        }
        .frame(minWidth: compact ? 52 : 78, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct HUDAuxIndicator: View {
    let title: String
    let value: String
    let color: Color
    let compact: Bool
    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: compact ? 4 : 5, height: compact ? 22 : 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(0.9).foregroundStyle(.white.opacity(0.62))
                Text(value).font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, compact ? 7 : 9).padding(.vertical, compact ? 6 : 8)
        .background(.black.opacity(0.44), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

private struct FloatingNavPill: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let compact: Bool
    init(item: ShootingHUDNavItem, selected: Bool, compact: Bool) {
        self.title = item.title; self.systemImage = item.systemImage; self.selected = selected; self.compact = compact
    }
    init(title: String, systemImage: String, selected: Bool, compact: Bool) {
        self.title = title; self.systemImage = systemImage; self.selected = selected; self.compact = compact
    }
    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Text(title).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(0.9)
            BMDAssetIcon(name: assetName, active: selected, fallback: systemImage, color: selected ? .white : .white.opacity(0.70), size: compact ? 13 : 16)
        }
        .foregroundStyle(selected ? .white : .white.opacity(0.70))
        .padding(.leading, compact ? 9 : 12).padding(.trailing, compact ? 8 : 10).padding(.vertical, compact ? 7 : 9)
        .background(selected ? BlackmagicCamStyle.activeBlue.opacity(0.52) : .black.opacity(0.45), in: Capsule())
        .overlay(Capsule().stroke(selected ? BlackmagicCamStyle.cyan.opacity(0.58) : .white.opacity(0.12), lineWidth: 1))
    }

    private var assetName: String {
        switch title {
        case "CAMERA": return "Camera"
        case "MEDIA": return "Media"
        case "CHAT": return "Cloud"
        case "SETTINGS": return "ControlIcon"
        case "SLATE": return "Slate"
        default: return "Camera"
        }
    }
}

private struct CameraControlCell: View {
    let item: BottomControlItem
    let compact: Bool
    let active: Bool
    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            BMDAssetIcon(name: item.asset, active: active, color: active ? BlackmagicCamStyle.cyan : .white.opacity(0.56), size: compact ? 12 : 15)
            Text(item.title).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(0.8).foregroundStyle(active ? BlackmagicCamStyle.cyan : .white.opacity(0.56))
            Text(item.value)
                .font(item.title == "FPS" || item.title == "ISO" || item.title == "TINT" ? BlackmagicCamStyle.readoutFont(size: compact ? 15 : 21, weight: .heavy) : BlackmagicCamStyle.labelFont(size: compact ? 15 : 21, weight: .heavy))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.55)
        }
        .frame(width: compact ? 62 : 88, height: compact ? 42 : 58)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.20) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.10), lineWidth: 1))
    }
}

private struct LiveToggleButton: View {
    let active: Bool
    let enabled: Bool
    let compact: Bool
    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            BMDAssetIcon(name: "HdmiPlay", activeName: "HdmiPlay_active", active: active, fallback: active ? "pause.fill" : "play.fill", color: .white, size: compact ? 14 : 18)
            Text(active ? "LIVE" : "VIEW").font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(0.8)
        }
        .foregroundStyle(enabled ? .white : .white.opacity(0.34))
        .frame(width: compact ? 48 : 62, height: compact ? 42 : 58)
        .background(active ? BlackmagicCamStyle.okGreen.opacity(0.28) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(active ? BlackmagicCamStyle.okGreen.opacity(0.50) : .white.opacity(0.10), lineWidth: 1))
    }
}

private struct FocusAutoButton: View {
    let enabled: Bool
    let compact: Bool
    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            BMDAssetIcon(name: "IconAf", activeName: "IconAf_active", active: enabled, fallback: "scope", color: enabled ? BlackmagicCamStyle.cyan : .white.opacity(0.34), size: compact ? 14 : 18)
            Text("AF").font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(0.8)
        }
        .foregroundStyle(enabled ? BlackmagicCamStyle.cyan : .white.opacity(0.34))
        .frame(width: compact ? 48 : 62, height: compact ? 42 : 58)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(enabled ? BlackmagicCamStyle.cyan.opacity(0.42) : .white.opacity(0.10), lineWidth: 1))
    }
}

private struct RecordButtonView: View {
    let active: Bool
    let enabled: Bool
    let compact: Bool
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.82), lineWidth: compact ? 3 : 4).frame(width: compact ? 54 : 78, height: compact ? 54 : 78)
            Circle().fill(active ? BlackmagicCamStyle.recordRed : BlackmagicCamStyle.recordRed.opacity(enabled ? 0.90 : 0.35)).frame(width: compact ? 40 : 58, height: compact ? 40 : 58).shadow(color: active ? BlackmagicCamStyle.recordRed.opacity(0.70) : .clear, radius: 13)
            if active {
                RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.95)).frame(width: compact ? 16 : 22, height: compact ? 16 : 22)
            } else {
                BMDAssetIcon(name: "Record", activeName: "Record_active", active: active, fallback: "record.circle", color: .white.opacity(0.86), size: compact ? 18 : 24)
            }
        }
        .accessibilityLabel(active ? "Stop Recording" : "Start Recording")
    }
}

private struct BlackmagicScrollerPanel: View {
    let scroller: BlackmagicHUDScroller
    let compact: Bool
    let onSelect: (String) -> Void
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scroller.eyebrow.uppercased()).font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy)).tracking(1.4).foregroundStyle(BlackmagicCamStyle.cyan)
                    Text(scroller.title).font(BlackmagicCamStyle.labelFont(size: compact ? 17 : 22, weight: .heavy)).foregroundStyle(.white)
                }
                Spacer()
                Text(BlackmagicReverseSpec.sourceBundle).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 9, weight: .bold)).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: compact ? 12 : 14, weight: .heavy)).foregroundStyle(.white).frame(width: compact ? 28 : 34, height: compact ? 28 : 34).background(.white.opacity(0.10), in: Circle()) }.buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 7 : 10) {
                    ForEach(Array(scroller.options.enumerated()), id: \.offset) { index, option in
                        Button { onSelect(option) } label: {
                            VStack(spacing: compact ? 3 : 5) {
                                Text(option).font(BlackmagicCamStyle.labelFont(size: compact ? 12 : 15, weight: index == 0 ? .heavy : .bold)).foregroundStyle(index == 0 ? .white : .white.opacity(0.82)).lineLimit(1).minimumScaleFactor(0.72)
                                Capsule().fill(index == 0 ? BlackmagicCamStyle.activeBlue : .white.opacity(0.12)).frame(width: index == 0 ? (compact ? 34 : 44) : (compact ? 20 : 26), height: index == 0 ? 3 : 2)
                            }
                            .frame(minWidth: compact ? 86 : 116)
                            .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 10 : 13)
                            .background(index == 0 ? BlackmagicCamStyle.activeBlue.opacity(0.24) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous).stroke(index == 0 ? BlackmagicCamStyle.cyan.opacity(0.45) : .white.opacity(0.10), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(compact ? 13 : 18)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
        // Firmware/update note: options are reverse-derived stand-ins for FpsOptions, ShutterScroll, IsoScroll, LutScroller and Monitor scrollers.
    }
}

private struct BottomHUDPreviewCard: View {
    let card: ShootingHUDBottomCard
    let compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 5) {
            Text(card.title.uppercased()).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 9, weight: .heavy)).tracking(0.8).foregroundStyle(.white.opacity(0.58))
            switch card.kind {
            case .histogram(let bars): HistogramBars(bars: bars).frame(width: compact ? 66 : 86, height: compact ? 26 : 32)
            case .storage(let primary, let progress, let trailing):
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) { Text(primary); Text(trailing).foregroundStyle(BlackmagicCamStyle.amber) }.font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 10, weight: .heavy))
                    ProgressView(value: progress).tint(BlackmagicCamStyle.okGreen).frame(width: compact ? 66 : 86)
                }
            case .audio(let levels):
                VStack(spacing: 3) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { _, level in AudioMeterRow(level: level).frame(width: compact ? 66 : 86, height: compact ? 5 : 6) }
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 10).padding(.vertical, compact ? 6 : 7)
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
    }
}

private struct FramingGuideLabel: View {
    let text: String
    let compact: Bool
    var body: some View {
        Text(text).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(1.1).foregroundStyle(.white.opacity(0.62)).padding(.horizontal, compact ? 7 : 9).padding(.vertical, compact ? 4 : 5).background(.black.opacity(0.30), in: Capsule())
    }
}

private struct FalseColorLegend: View {
    let compact: Bool
    private let stops: [(Color, String)] = [(.purple, "LOW"), (.blue, "18%"), (.green, "MID"), (.yellow, "SKIN"), (.red, "HIGH")]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { _, stop in
                VStack(spacing: 3) {
                    Rectangle().fill(stop.0).frame(width: compact ? 24 : 34, height: compact ? 5 : 6)
                    Text(stop.1).font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 7, weight: .heavy)).foregroundStyle(.white.opacity(0.62))
                }
            }
        }
        .padding(6)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WhiteBalanceOverlay: View {
    let compact: Bool
    let value: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill").foregroundStyle(BlackmagicCamStyle.amber)
            Text(value).font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy))
            Text("TINT 0").font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, compact ? 8 : 10).padding(.vertical, compact ? 6 : 8)
        .background(.black.opacity(0.34), in: Capsule())
        .foregroundStyle(.white)
    }
}

private struct SlateOverlay: View {
    let compact: Bool
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SLATE FOR").font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: .heavy)).tracking(1.5).foregroundStyle(BlackmagicCamStyle.cyan)
                    Text("Blackmagic Camera Metadata").font(BlackmagicCamStyle.labelFont(size: compact ? 24 : 34, weight: .heavy)).foregroundStyle(.white)
                }
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: compact ? 14 : 18, weight: .heavy)).foregroundStyle(.white).frame(width: compact ? 34 : 42, height: compact ? 34 : 42).background(.white.opacity(0.10), in: Circle()) }.buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 8 : 12), count: 2), spacing: compact ? 8 : 12) {
                ForEach(BlackmagicReverseSpec.slateFields, id: \.self) { field in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(field).font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy)).tracking(1.0).foregroundStyle(.white.opacity(0.52))
                        Text(defaultSlateValue(for: field)).font(BlackmagicCamStyle.labelFont(size: compact ? 14 : 17, weight: .heavy)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(compact ? 10 : 13)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
                }
            }
        }
        .padding(compact ? 18 : 26)
        .frame(maxWidth: compact ? 640 : 840)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: compact ? 22 : 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 22 : 30, style: .continuous).stroke(BlackmagicCamStyle.cyan.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.60), radius: 30, x: 0, y: 18)
        // Firmware/update note: Slate fields mirror reversed SlateViewProjectInfo, SlateViewClipInfo and SlateViewLensInfo strings.
    }
    private func defaultSlateValue(for field: String) -> String {
        switch field {
        case "SLATE FOR": return "A001"
        case "PROJECT": return "No project selected - All Clips"
        case "SCENE": return "001"
        case "TAKE": return "1"
        case "REEL": return "A"
        case "CAMERA OPERATOR": return "Blackmagic Camera"
        case "LENS DATA": return "24mm / f1.8"
        case "GOOD TAKE": return "OFF"
        default: return "--"
        }
    }
}

private struct RuleOfThirds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let oneThirdX = rect.minX + rect.width / 3
        let twoThirdX = rect.minX + rect.width * 2 / 3
        let oneThirdY = rect.minY + rect.height / 3
        let twoThirdY = rect.minY + rect.height * 2 / 3
        path.move(to: CGPoint(x: oneThirdX, y: rect.minY)); path.addLine(to: CGPoint(x: oneThirdX, y: rect.maxY))
        path.move(to: CGPoint(x: twoThirdX, y: rect.minY)); path.addLine(to: CGPoint(x: twoThirdX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: oneThirdY)); path.addLine(to: CGPoint(x: rect.maxX, y: oneThirdY))
        path.move(to: CGPoint(x: rect.minX, y: twoThirdY)); path.addLine(to: CGPoint(x: rect.maxX, y: twoThirdY))
        return path
    }
}

private struct HistogramBars: View {
    let bars: [CGFloat]
    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 1).fill(histogramColor(index: index)).frame(height: max(2, proxy.size.height * min(1, max(0.04, value))))
                }
            }
        }
    }
    private func histogramColor(index: Int) -> Color {
        switch index % 3 {
        case 0: return .red.opacity(0.72)
        case 1: return .green.opacity(0.72)
        default: return .blue.opacity(0.72)
        }
    }
}

private struct AudioMeterRow: View {
    let level: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.11))
                HStack(spacing: 0) {
                    Capsule().fill(BlackmagicCamStyle.okGreen).frame(width: proxy.size.width * min(level, 0.72))
                    Capsule().fill(BlackmagicCamStyle.amber).frame(width: proxy.size.width * max(0, min(level - 0.72, 0.16)))
                    Capsule().fill(BlackmagicCamStyle.recordRed).frame(width: proxy.size.width * max(0, level - 0.88))
                }
            }
        }
    }
}

enum ShootingHUDFixtures {
    static let histogramBars: [CGFloat] = [0.10, 0.18, 0.22, 0.15, 0.25, 0.38, 0.52, 0.44, 0.62, 0.74, 0.56, 0.43, 0.68, 0.82, 0.70, 0.48, 0.37, 0.28, 0.20, 0.16, 0.12, 0.09, 0.07, 0.05]
}
