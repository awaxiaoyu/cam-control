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
            let metrics = BlackmagicHUDMetrics(size: proxy.size)
            ZStack {
                BlackmagicCamStyle.canvas.ignoresSafeArea()
                previewLayer
                if !cleanFeed {
                    guideLayer(metrics: metrics)
                    cameraChrome(metrics: metrics)
                    if let activeScroller {
                        VStack {
                            Spacer()
                            BlackmagicScrollerPanel(scroller: activeScroller, compact: metrics.compact) { option in
                                handle(option)
                            } onClose: {
                                withAnimation(.snappy(duration: 0.18)) { self.activeScroller = nil }
                            }
                            .padding(.leading, metrics.safePad)
                            .padding(.trailing, metrics.safePad + (metrics.isLandscape ? metrics.pageTabWidth + 18 : 0))
                            .padding(.bottom, metrics.footerBottomPadding + metrics.footerHeight + 10)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(6)
                    }
                    if showSlate {
                        SlateOverlay(compact: metrics.compact) {
                            withAnimation(.snappy(duration: 0.18)) { showSlate = false }
                        }
                        .padding(metrics.compact ? 20 : 44)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                        .zIndex(8)
                    }
                } else {
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.snappy(duration: 0.18)) { cleanFeed = false }
                            } label: {
                                HUDAuxIndicator(title: "CLEAN FEED", value: "EXIT", color: BlackmagicCamStyle.okGreen, compact: metrics.compact)
                            }
                            .buttonStyle(.plain)
                            .padding(metrics.safePad)
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

    private func cameraChrome(metrics: BlackmagicHUDMetrics) -> some View {
        ZStack {
            VStack(spacing: 0) {
                topHUD(compact: metrics.compact)
                    .padding(.leading, metrics.safePad + (metrics.isLandscape ? 70 : 0))
                    .padding(.trailing, metrics.safePad + metrics.pageTabWidth + 10)
                    .padding(.top, metrics.safePad)
                Spacer()
                bottomScopeStrip(compact: metrics.compact)
                    .padding(.leading, metrics.safePad + (metrics.isLandscape ? 70 : 0))
                    .padding(.trailing, metrics.safePad + metrics.pageTabWidth + 10)
                    .padding(.bottom, metrics.compact ? 6 : 8)
                bottomControls(compact: metrics.compact)
                    .padding(.leading, metrics.safePad + (metrics.isLandscape ? 70 : 0))
                    .padding(.trailing, metrics.safePad + metrics.pageTabWidth + 10)
                    .padding(.bottom, metrics.footerBottomPadding)
            }

            HStack(alignment: .top) {
                leftMonitorRail(compact: metrics.compact)
                    .padding(.leading, metrics.safePad)
                Spacer()
                rightPageNavigationRail(compact: metrics.compact)
                    .frame(width: metrics.pageTabWidth)
                    .padding(.trailing, metrics.safePad)
            }
            .padding(.top, metrics.isLandscape ? (metrics.compact ? 76 : 104) : metrics.size.height * 0.24)
        }
        // Firmware/update note: layout follows recovered MainViewLayoutData pageTabWidth/footerHeight/sidebar anchors; 3.2.00 uses right-edge pageCamera/pageMedia/pageChat/pageSettings and left-edge HUD monitor functions, so do not move page navigation back to the left rail on future IPA updates.
    }

    private func topHUD(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 8 : 12) {
            topLeftIndicators(compact: compact)
            Spacer(minLength: 8)
            recordTimerBar(compact: compact)
            Spacer(minLength: 8)
            topRightIndicators(compact: compact)
        }
    }

    private func topLeftIndicators(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            HUDStatusChip(title: "CAM", value: subtitle.uppercased(), asset: "Camera", color: .white.opacity(0.82), compact: compact)
            HUDStatusChip(title: "LUT", value: "Rec.709", asset: "IconLut", color: BlackmagicCamStyle.activeBlue, compact: compact)
            HUDStatusChip(title: "TC", value: "TOD", asset: "IconLock", color: .white.opacity(0.74), compact: compact)
        }
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, compact ? 5 : 7)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: top-left cluster follows recovered HUDTopLeftIndicators, HUDLutIndicator and timecode mode labels; keep it as compact operator readouts rather than an app title banner when updating for a new IPA.
    }

    private func recordTimerBar(compact: Bool) -> some View {
        VStack(spacing: compact ? 2 : 3) {
            Text(timecode)
                .font(BlackmagicCamStyle.timecodeFont(size: compact ? 34 : 58))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            HStack(spacing: 8) {
                HUDTallyDot(active: isCaptureActive, compact: compact)
                Text(isCaptureActive ? "REC" : "STBY")
                Text("REC RUN").foregroundStyle(.white.opacity(0.42))
                Text("24 FPS").foregroundStyle(.white.opacity(0.42))
            }
            .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
            .tracking(1.55)
            .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.74))
        }
        .padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 3 : 5)
        // Firmware/update note: this is the visible MainControlRecordTimer/RecordTimerTextIndicator mapping; 3.2.00 renders it as monitor overlay text, not an iOS capsule control.
    }

    private func topRightIndicators(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            HUDStatusChip(title: "BAT", value: "82%", asset: "BatteryIndicator", color: BlackmagicCamStyle.okGreen, compact: compact)
            HUDStatusChip(title: "STOR", value: "09:00", asset: "StorageIphone", color: .white.opacity(0.80), compact: compact)
            HUDStatusChip(title: "UP", value: "WAIT", asset: "UploadToCloud", color: BlackmagicCamStyle.amber, compact: compact)
        }
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 6 : 8)
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
        // Firmware/update note: right cluster follows StorageStatusHUD, UploadStatusHUD and BatteryIndicator assets recovered from the IPA.
    }

    private func guideLayer(metrics: BlackmagicHUDMetrics) -> some View {
        let compact = metrics.compact
        return ZStack {
            RuleOfThirds()
                .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [compact ? 5 : 7, compact ? 8 : 11]))
                .padding(.leading, metrics.isLandscape ? metrics.safePad + (compact ? 42 : 66) : (compact ? 48 : 72))
                .padding(.trailing, metrics.isLandscape ? metrics.pageTabWidth + metrics.safePad + (compact ? 78 : 104) : (compact ? 48 : 72))
                .padding(.vertical, metrics.isLandscape ? (compact ? 58 : 86) : (compact ? 108 : 132))
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
            .padding(.leading, metrics.isLandscape ? metrics.safePad + (compact ? 10 : 16) : (compact ? 18 : 28))
            .padding(.trailing, metrics.isLandscape ? metrics.pageTabWidth + metrics.safePad + (compact ? 84 : 112) : (compact ? 18 : 28))
            .padding(.top, metrics.isLandscape ? (compact ? 70 : 106) : (compact ? 126 : 154))
            .padding(.bottom, metrics.isLandscape ? (compact ? 96 : 128) : (compact ? 126 : 154))
        }
        .allowsHitTesting(false)
        // Firmware/update note: overlays mirror reversed HUDGuides, HUDSafeAreas, HUDFalseColor and HUDWhiteBalanceOverlay strings; only values should change for new camera firmware.
    }

    private func leftQuickAccessRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            quickAccessButton(title: "SETTINGS", asset: "ControlIcon", color: BlackmagicCamStyle.cyan, compact: compact) {
                onNavigate(.settings)
            }
            quickAccessButton(title: "MEDIA", asset: "Media", color: .white.opacity(0.86), compact: compact) {
                onNavigate(.media)
            }
            quickAccessButton(title: "CHAT", asset: "Chat", color: BlackmagicCamStyle.activeBlue, compact: compact) {
                onNavigate(.chat)
            }
            quickAccessButton(title: "SLATE", asset: "Slate", color: BlackmagicCamStyle.amber, compact: compact) {
                withAnimation(.snappy(duration: 0.18)) { showSlate = true }
            }
            quickAccessButton(title: "PRESET", asset: "Sync", color: BlackmagicCamStyle.okGreen, compact: compact) {
                withAnimation(.snappy(duration: 0.18)) { activeScroller = .preset }
            }
        }
        .padding(.vertical, compact ? 7 : 10)
        .padding(.horizontal, compact ? 4 : 6)
        .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: compact ? 15 : 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 15 : 20, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.38), radius: 18, x: 0, y: 10)
        // Firmware/update note: this maps recovered HUDLeftNavMenuIndicator, PresetScrollListView, SlateView and pageCamera/pageMedia/pageChat/pageSettings symbols; update asset order from IPA strings on future app changes.
    }

    private func rightPageNavigationRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            BlackmagicRootPageRail(selection: navSelection, compact: compact, onNavigate: onNavigate)
            Button {
                withAnimation(.snappy(duration: 0.18)) { showSlate = true }
            } label: {
                monitorIconShell(asset: "Slate", color: BlackmagicCamStyle.amber, active: showSlate, compact: compact)
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.snappy(duration: 0.18)) { activeScroller = .preset }
            } label: {
                monitorIconShell(asset: "Sync", color: BlackmagicCamStyle.okGreen, active: activeScroller == .preset, compact: compact)
            }
            .buttonStyle(.plain)
        }
        // Firmware/update note: right rail is the recovered BmdTabView/BmdVTabView pageCamera/pageMedia/pageChat/pageSettings rail with Slate/Preset secondary controls; future IPA changes must be diffed against page symbols before reordering.
    }

    private func quickAccessButton(title: String, asset: String, color: Color, compact: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: compact ? 2 : 3) {
                BMDAssetIcon(name: asset, active: false, fallback: BlackmagicReverseSpec.assetFallbackSystemImages[asset] ?? "circle", color: color, size: compact ? 15 : 18)
                Text(title)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 6, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(width: compact ? 38 : 48, height: compact ? 38 : 50)
            .background(.white.opacity(0.052), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func leftMonitorRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            monitorIconButton(asset: "FalseColor", color: BlackmagicCamStyle.amber, scroller: .falseColor, compact: compact)
            monitorIconButton(asset: "FocusAssist", color: BlackmagicCamStyle.cyan, scroller: .focusAssist, compact: compact)
            monitorIconButton(asset: "Guides", color: .white.opacity(0.82), scroller: .guides, compact: compact)
            monitorIconButton(asset: "Zebra", color: .white.opacity(0.86), scroller: .zebra, compact: compact)
            monitorIconButton(asset: "IconLut", color: BlackmagicCamStyle.activeBlue, scroller: .lut, compact: compact)
            Button {
                withAnimation(.snappy(duration: 0.18)) { cleanFeed.toggle() }
            } label: {
                monitorIconShell(asset: "HdmiPlay", color: cleanFeed ? BlackmagicCamStyle.okGreen : .white.opacity(0.72), active: cleanFeed, compact: compact)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, compact ? 7 : 10)
        .padding(.horizontal, compact ? 4 : 6)
        .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: compact ? 15 : 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 15 : 20, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.38), radius: 18, x: 0, y: 10)
        // Firmware/update note: icon-only monitor rail maps HUDLeadingIndicators plus FocusAssistScroller/FramingGuidesScroller/SafeAreaScroller/ZebraScroller/LutScroller; update asset names from asset_ui_names_unique.txt for new IPA versions.
    }

    private func monitorIconButton(asset: String, color: Color, scroller: BlackmagicHUDScroller, compact: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { activeScroller = scroller }
        } label: {
            monitorIconShell(asset: asset, color: color, active: activeScroller == scroller, compact: compact)
        }
        .buttonStyle(.plain)
    }

    private func monitorIconShell(asset: String, color: Color, active: Bool, compact: Bool) -> some View {
        BMDAssetIcon(name: asset, active: active, color: active ? .white : color, size: compact ? 17 : 20)
            .frame(width: compact ? 38 : 48, height: compact ? 38 : 50)
            .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.58) : .white.opacity(0.052), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.50) : .white.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
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
        .padding(.vertical, compact ? 7 : 10)
        .padding(.horizontal, compact ? 4 : 6)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 16 : 22, style: .continuous).stroke(.white.opacity(0.11), lineWidth: 1))
        .shadow(color: .black.opacity(0.40), radius: 18, x: 0, y: 10)
        // Firmware/update note: trailing indicators map reversed HUDLeftNavMenuIndicator/HUDRightNavMenuIndicator plus SlateView and page tab layout data.
    }

    private func bottomScopeStrip(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            ForEach(0..<3, id: \.self) { index in
                if bottomCards.indices.contains(index) {
                    BottomHUDPreviewCard(card: bottomCards[index], compact: compact)
                }
            }
            Spacer(minLength: 8)
            HUDAuxIndicator(title: "LUT", value: "Rec.709", color: BlackmagicCamStyle.activeBlue, compact: compact)
            HUDAuxIndicator(title: "FOCUS", value: canFocus ? "ASSIST" : "LOCK", color: BlackmagicCamStyle.cyan, compact: compact)
            HUDAuxIndicator(title: "CLEAN", value: cleanFeed ? "ON" : "FEED", color: cleanFeed ? BlackmagicCamStyle.okGreen : .white.opacity(0.74), compact: compact)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 13 : 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: bottom scope strip maps HUDHistogramPopUpView, HUDAudioLevelPopUpView, StorageStatusHUD and UploadStatusHUD without app-style labeled monitor buttons.
    }

    private func bottomControls(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: compact ? 7 : 11) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: compact ? 6 : 10) {
                    ForEach(bottomControlItems) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) { activeScroller = item.scroller }
                        } label: {
                            BmdAdjustmentDialCell(item: item, compact: compact, active: activeScroller == item.scroller)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, compact ? 2 : 4)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(.white.opacity(0.14)).frame(height: compact ? 52 : 76)

            Button(action: onToggleLive) { LiveToggleButton(active: isLiveActive, enabled: canToggleLive, compact: compact) }
                .buttonStyle(.plain).disabled(!canToggleLive)
            Button(action: onFocus) { FocusAutoButton(enabled: canFocus, compact: compact) }
                .buttonStyle(.plain).disabled(!canFocus)
            Button(action: onCapture) { RecordButtonView(active: isCaptureActive, enabled: canCapture, compact: compact) }
                .buttonStyle(.plain).disabled(!canCapture)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 7 : 10)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 10)
        // Firmware/update note: footer split maps L/PHUD footer elements plus persistent RecordButton; keep record/live/focus fixed while control dials scroll.
    }

    private var bottomControlItems: [BottomControlItem] {
        [
            BottomControlItem(title: "LENS", value: value(for: "Lens"), asset: "Camera", scroller: .lens),
            BottomControlItem(title: "FPS", value: value(for: "FPS"), asset: "IconTimelapse", scroller: .fps),
            BottomControlItem(title: "SHUTTER", value: value(for: "Shutter"), asset: "Exposure", scroller: .shutter),
            BottomControlItem(title: "IRIS", value: value(forAny: ["Iris", "Aperture"]), asset: "Exposure", scroller: .iris),
            BottomControlItem(title: "ISO", value: value(for: "ISO"), asset: "Exposure", scroller: .iso),
            BottomControlItem(title: "WB", value: value(forAny: ["WB", "White Balance"]), asset: "IconAwb", scroller: .whiteBalance),
            BottomControlItem(title: "TINT", value: value(for: "Tint"), asset: "IconAwb", scroller: .tint)
        ]
        // Firmware/update note: footer controls are constrained to recovered camera HUD short labels LENS/FPS/SHUTTER/IRIS/ISO/WB/TINT; Zoom, Exposure, Stabilization and LUT stay in scrollers/side controls unless a future IPA exposes them as HUD footer labels.
    }

    private func value(for title: String) -> String {
        topItems.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }?.value ?? "--"
    }

    private func value(forAny titles: [String], fallback: String = "--") -> String {
        for title in titles {
            let found = value(for: title)
            if found != "--" { return found }
        }
        return fallback
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
        // Firmware/update note: scroller labels are reverse-derived from CameraAppToolbox HUD/AppIntent strings; bind selection actions to cam_app_control properties when the controller layer exposes those writes.
    }
}

private struct BlackmagicHUDMetrics {
    let size: CGSize
    var isLandscape: Bool { size.width >= size.height }
    var compact: Bool { size.width < 980 || size.height < 620 }
    var safePad: CGFloat { compact ? 8 : 14 }
    var pageTabWidth: CGFloat { compact ? 52 : 64 }
    var footerHeight: CGFloat { compact ? 74 : 96 }
    var footerBottomPadding: CGFloat { compact ? 8 : 14 }
    // Firmware/update note: values are reverse-derived approximations of MainViewLayoutData pageTabWidth/footerHeight/navMenuEdgePadding; refresh from IPA symbols when Blackmagic changes layout data.
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
    /// Firmware/update note: page names come from pageCamera/pageMedia/pageChat/pageSettings; glyphs use recovered Camera/Media/Chat/ControlIcon assets from CameraAppToolbox Assets.car.
    var assetName: String {
        switch self {
        case .camera: return "Camera"
        case .media: return "Media"
        case .chat: return "Cloud"
        case .settings: return "ControlIcon"
        }
    }
}

private enum BlackmagicHUDScroller: String, Identifiable, CaseIterable {
    case lens, zoom, fps, shutter, iris, iso, exposure, whiteBalance, tint, codec, lut, focus, focusAssist, falseColor, guides, zebra, monitor, audio, stabilization, preset
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lens: return "Lens"
        case .zoom: return "ZOOM"
        case .fps: return "FPS"
        case .shutter: return "SHUTTER"
        case .iris: return "IRIS"
        case .iso: return "ISO"
        case .whiteBalance: return "WHITE BALANCE"
        case .exposure: return "EXPOSURE"
        case .tint: return "TINT"
        case .codec: return "CODEC / RESOLUTION"
        case .lut: return "LUT SELECTION"
        case .focus: return "FOCUS"
        case .focusAssist: return "FOCUS ASSIST"
        case .falseColor: return "FALSE COLOR"
        case .guides: return "FRAMING GUIDES"
        case .zebra: return "ZEBRA"
        case .monitor: return "MONITOR"
        case .audio: return "AUDIO METERS"
        case .stabilization: return "STABILIZATION"
        case .preset: return "PRESET SELECTION"
        }
    }
    var eyebrow: String {
        switch self {
        case .lens, .zoom, .fps, .shutter, .iris, .iso, .exposure, .whiteBalance, .tint, .focus, .stabilization: return "Camera"
        case .codec: return "Record"
        case .lut: return "LUTs"
        case .focusAssist, .falseColor, .guides, .zebra, .monitor: return "Monitor"
        case .audio: return "Audio"
        case .preset: return "Presets"
        }
    }
    var options: [String] {
        switch self {
        case .lens: return ["0.5x", "13mm", "24mm", "35mm", "48mm", "77mm", "Front", "Refresh"]
        case .zoom: return ["0.5x", "1.0x", "2.0x", "3.0x", "5.0x", "Refresh"]
        case .fps: return ["23.98", "24", "25", "29.97", "30", "48", "50", "59.94", "60"]
        case .shutter: return ["1/24", "1/48", "180\u{00B0}", "172.8\u{00B0}", "1/50", "1/60", "1/120", "Auto"]
        case .iris: return ["f1.8", "f2.0", "f2.8", "f4", "f5.6", "f8", "Auto"]
        case .iso: return ["Auto", "100", "200", "400", "800", "1250", "1600", "3200", "6400"]
        case .exposure: return ["Auto", "Shutter", "ISO", "Shutter + ISO", "-2.0", "-1.0", "0.0", "+1.0", "+2.0"]
        case .whiteBalance: return ["Auto", "3200K", "4300K", "4700K", "5600K", "6500K", "7500K", "Lock"]
        case .tint: return ["-50", "-25", "0", "+10", "+25", "+50"]
        case .codec: return BlackmagicReverseSpec.recordCodecOptions + BlackmagicReverseSpec.recordResolutionOptions + BlackmagicReverseSpec.recordTimecodeOptions
        case .lut: return BlackmagicReverseSpec.lutNames
        case .focus: return ["Near", "Soft", "Medium", "Hard", "Far", "AF", "Transition", "Marker 1", "Marker 2"]
        case .focusAssist: return ["Off", "On", "Focus Assist", "Focus Assist Color", "Blue", "Red", "Green", "White"]
        case .falseColor: return ["Off", "On", "False Color", "Exposure", "Skin", "Mid Grey", "Highlight"]
        case .guides: return ["Off", "Thirds", "Crosshair", "Safe Area", "2.39:1", "1.85:1", "4:3", "Guides Opacity", "Guides Color"]
        case .zebra: return ["Off", "50%", "60%", "70%", "75%", "80%", "90%", "95%", "100%"]
        case .monitor: return BlackmagicReverseSpec.monitorOptions
        case .audio: return BlackmagicReverseSpec.audioLabels + ["None", "iPhone Microphone"]
        case .stabilization: return ["Off", "Standard", "Cinematic", "Extreme", "Optical"]
        case .preset: return BlackmagicReverseSpec.presetSelectionOptions + ["Sync Presets to Cloud Project"]
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

private struct HUDStatusChip: View {
    let title: String
    let value: String
    let asset: String
    let color: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            BMDAssetIcon(name: asset, active: true, fallback: nil, color: color, size: compact ? 11 : 13)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 7, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.45))
                Text(value)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 4 : 5)
        .background(.white.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.20), lineWidth: 1))
    }
}

private struct HUDTallyDot: View {
    let active: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(active ? BlackmagicCamStyle.recordRed.opacity(0.22) : .white.opacity(0.08))
                .frame(width: compact ? 13 : 16, height: compact ? 13 : 16)
            Circle()
                .fill(active ? BlackmagicCamStyle.recordRed : .white.opacity(0.38))
                .frame(width: compact ? 7 : 8, height: compact ? 7 : 8)
        }
        .shadow(color: active ? BlackmagicCamStyle.recordRed.opacity(0.8) : .clear, radius: 5)
        // Firmware/update note: visual state maps recovered HUDTallyIndicator; change only when recording-state semantics change.
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
        ZStack(alignment: .trailing) {
            BMDAssetIcon(name: assetName, active: selected, fallback: systemImage, color: selected ? .white : .white.opacity(0.64), size: compact ? 18 : 22)
                .frame(width: compact ? 40 : 50, height: compact ? 40 : 52)
                .background(selected ? BlackmagicCamStyle.activeBlue.opacity(0.58) : .white.opacity(0.052), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(selected ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.08), lineWidth: 1))
            if selected {
                Capsule()
                    .fill(BlackmagicCamStyle.cyan)
                    .frame(width: 3, height: compact ? 20 : 26)
                    .offset(x: compact ? 4 : 5)
            }
        }
        .accessibilityLabel(title)
        // Firmware/update note: page tabs map recovered pageCamera/pageMedia/pageChat/pageSettings and MainViewLayoutData tabButton size; they are icon-first like the 3.2.00 root rail.
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

private struct BmdAdjustmentDialCell: View {
    let item: BottomControlItem
    let compact: Bool
    let active: Bool

    private var autoLabel: String? {
        item.value.caseInsensitiveCompare("auto") == .orderedSame || item.value.hasPrefix("A ") ? "AUTO" : nil
    }

    var body: some View {
        ZStack {
            BmdAdjustmentDialShape()
                .fill(active ? BlackmagicCamStyle.activeBlue.opacity(0.24) : Color.black.opacity(0.58))
            BmdAdjustmentDialShape()
                .stroke(active ? BlackmagicCamStyle.cyan.opacity(0.52) : .white.opacity(0.13), lineWidth: 1)
            BmdDialHDivider()
                .stroke(.white.opacity(active ? 0.22 : 0.11), lineWidth: 1)
                .padding(.horizontal, compact ? 10 : 12)
            BmdDialVDivider()
                .stroke(.white.opacity(active ? 0.20 : 0.09), lineWidth: 1)
                .padding(.vertical, compact ? 9 : 11)

            VStack(spacing: compact ? 3 : 5) {
                HStack(spacing: 5) {
                    BMDAssetIcon(name: item.asset, active: active, color: active ? BlackmagicCamStyle.cyan : .white.opacity(0.68), size: compact ? 11 : 13)
                    Text(item.title)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                        .tracking(0.9)
                        .foregroundStyle(active ? BlackmagicCamStyle.cyan : .white.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Text(item.value)
                    .font(item.title == "FPS" || item.title == "ISO" || item.title == "TINT" ? BlackmagicCamStyle.readoutFont(size: compact ? 18 : 24, weight: .heavy) : BlackmagicCamStyle.labelFont(size: compact ? 17 : 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)

                BmdDialMarkerRow(active: active, compact: compact)
            }
            .padding(.horizontal, compact ? 8 : 10)

            if let autoLabel {
                Text(autoLabel)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 6, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(BlackmagicCamStyle.activeBlue.opacity(0.92), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, compact ? 5 : 7)
                    .padding(.trailing, compact ? 6 : 8)
            }
        }
        .frame(width: compact ? 84 : 108, height: compact ? 62 : 78)
        .shadow(color: active ? BlackmagicCamStyle.activeBlue.opacity(0.36) : .black.opacity(0.26), radius: active ? 10 : 5, x: 0, y: 4)
        .contentShape(BmdAdjustmentDialShape())
        .accessibilityLabel("Camera HUD \(item.title) \(item.value)")
        // Firmware/update note: footer readout is derived from BmdAdjustmentDial, BmdAdjustmentDialMarker, BmdDialVDivider/BmdDialHDivider and Camera HUD Lens/FPS/Shutter/IRIS/ISO/WB/TINT strings; update only if those symbols change in a new IPA.
    }
}

private struct BmdAdjustmentDialShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.22
        let notch = min(rect.width, rect.height) * 0.12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - notch * 0.45, y: rect.midY), control: CGPoint(x: rect.maxX - notch * 0.15, y: rect.midY - notch * 0.45))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY + notch), control: CGPoint(x: rect.maxX - notch * 0.15, y: rect.midY + notch * 0.45))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        path.addQuadCurve(to: CGPoint(x: rect.minX + notch * 0.45, y: rect.midY), control: CGPoint(x: rect.minX + notch * 0.15, y: rect.midY + notch * 0.45))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY - notch), control: CGPoint(x: rect.minX + notch * 0.15, y: rect.midY - notch * 0.45))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct BmdDialHDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct BmdDialVDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct BmdDialMarkerRow: View {
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(index == 3 ? (active ? BlackmagicCamStyle.cyan : .white.opacity(0.58)) : .white.opacity(active ? 0.28 : 0.18))
                    .frame(width: index == 3 ? (compact ? 10 : 14) : (compact ? 4 : 5), height: compact ? 2 : 3)
            }
        }
        .accessibilityHidden(true)
        // Firmware/update note: marker ticks mirror the recovered BmdAdjustmentDialMarker affordance; if Blackmagic changes dial mechanics, adjust only this marker row/shape pair.
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
                Text("SWIPE TO SELECT").font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 9, weight: .heavy)).tracking(1.1).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
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
        // Firmware/update note: option strips mirror recovered FpsOptions, ShutterScroll, IsoScroll, ZoomScroll, ExposureScroll, LutScroller and Monitor scroller families.
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
        case "PRODUCTION NAME": return "No project selected - All Clips"
        case "DIRECTOR": return "--"
        case "CAMERA": return "A"
        case "CAMERA OPERATOR": return "Blackmagic Camera"
        case "SLATE FOR": return "A001"
        case "SCENE": return "001"
        case "TAKE": return "1"
        case "REEL": return "A"
        case "LENS DATA": return "24mm / f1.8 / 16:9"
        case "Good Take Last Clip": return "Off"
        case "Interior", "Exterior", "Day", "Night": return "--"
        case "Next Clip": return "A002"
        default: return "--"
        }
        // Firmware/update note: values mirror Camera > Slate > Project Info / Clip Info labels recovered from Localizable.strings.
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



