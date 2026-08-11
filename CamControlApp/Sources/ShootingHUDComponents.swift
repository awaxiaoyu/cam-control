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
    @State private var stealthHUD = false

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
                if !cleanFeed && !stealthHUD {
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
                            .padding(.trailing, metrics.safePad + (metrics.isLandscape ? metrics.pageTabWidth + 8 : 0))
                            .padding(.bottom, metrics.footerBottomPadding + metrics.footerHeight + 4)
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
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.snappy(duration: 0.18)) {
                                    cleanFeed = false
                                    stealthHUD = false
                                }
                            } label: {
                                HUDAuxIndicator(title: cleanFeed ? "CLEAN FEED" : "STEALTH HUD", value: "EXIT", color: cleanFeed ? BlackmagicCamStyle.okGreen : BlackmagicCamStyle.cyan, compact: metrics.compact)
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
        Group {
            if metrics.isLandscape {
                landscapeCameraChrome(metrics: metrics)
            } else {
                portraitCameraChrome(metrics: metrics)
            }
        }
        // Firmware/update note: MainViewLayoutData exposes separate landscape/portrait/stealth layout data plus PSHUDTimecodeBar/PHUDCameraControls; keep this branch explicit when updating for a new IPA.
    }

    private func landscapeCameraChrome(metrics: BlackmagicHUDMetrics) -> some View {
        ZStack {
            VStack(spacing: 0) {
                officialTopReadoutBar(compact: metrics.compact)
                    .padding(.leading, metrics.safePad + 24)
                    .padding(.trailing, metrics.safePad + metrics.landscapeRightChromeWidth + 8)
                    .padding(.top, metrics.safePad + 3)
                Spacer()
                HStack(alignment: .bottom) {
                    if let histogram = bottomCards.first {
                        BottomHUDPreviewCard(card: histogram, compact: metrics.compact)
                    }
                    Spacer()
                    if bottomCards.count > 2 {
                        BottomHUDPreviewCard(card: bottomCards[2], compact: metrics.compact)
                    }
                }
                .padding(.leading, metrics.safePad + 28)
                .padding(.trailing, metrics.safePad + metrics.landscapeRightChromeWidth + 12)
                .padding(.bottom, metrics.compact ? 9 : 13)
            }

            VStack(spacing: 0) {
                Spacer(minLength: metrics.compact ? 18 : 24)
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    rightControlRail(compact: metrics.compact)
                        .frame(width: metrics.rightControlRailWidth)
                    rightPageNavigationRail(compact: metrics.compact, horizontal: false)
                        .frame(width: metrics.rightPageRailWidth)
                }
                Spacer(minLength: metrics.compact ? 18 : 24)
            }
            .padding(.trailing, metrics.safePad)
        }
        // Firmware/update note: landscape branch is rebuilt from F:\Blackmagic Cam_3.2.00.ipa + App Store screenshots: full preview, one top readout row, histogram/audio overlays, right utility strip, and separate page tab strip.
    }

    private func portraitCameraChrome(metrics: BlackmagicHUDMetrics) -> some View {
        ZStack {
            VStack(spacing: 0) {
                officialPortraitTopCluster(compact: true)
                    .padding(.top, metrics.safePad + 18)
                    .padding(.horizontal, metrics.safePad + 14)
                Spacer()
                HStack(alignment: .bottom) {
                    if let histogram = bottomCards.first {
                        BottomHUDPreviewCard(card: histogram, compact: true)
                    }
                    Spacer()
                    if bottomCards.count > 2 {
                        BottomHUDPreviewCard(card: bottomCards[2], compact: true)
                    }
                }
                .padding(.horizontal, metrics.safePad + 16)
                .padding(.bottom, metrics.portraitControlBarHeight + metrics.pageTabHeight + 12)
            }

            VStack(spacing: 0) {
                Spacer()
                portraitControlDock(compact: true)
                    .frame(height: metrics.portraitControlBarHeight)
                rightPageNavigationRail(compact: true, horizontal: true)
                    .frame(height: metrics.pageTabHeight)
            }
        }
        // Firmware/update note: portrait branch follows the 3.2.00 portrait screenshot: top iOS-safe readout cluster, bottom black capture toolbar, then pageCamera/pageMedia/pageChat/pageSettings tab bar.
    }

    private func portraitTimecodeBar(compact: Bool) -> some View {
        HStack(spacing: 8) {
            HUDTallyDot(active: isCaptureActive, compact: true)
            Text(timecode)
                .font(BlackmagicCamStyle.timecodeFont(size: compact ? 20 : 24))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(isCaptureActive ? "REC" : "STBY")
                .font(BlackmagicCamStyle.labelFont(size: 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.50))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.34), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
        // Firmware/update note: explicit PSHUDTimecodeBar representation for portrait/small-screen mode; update only if recovered portrait timecode symbols change.
    }

    private func topHUD(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 8 : 12) {
            topLeftStatus(compact: compact)
            Spacer(minLength: compact ? 8 : 16)
            recordTimerBar(compact: compact)
            Spacer(minLength: compact ? 8 : 16)
            topStatusIcons(compact: compact)
        }
    }

    private func portraitStatusRow(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            topLeftStatus(compact: compact)
            Spacer(minLength: 6)
            topStatusIcons(compact: compact)
        }
        // Firmware/update note: portrait uses PSHUDTimecodeBar for timecode, so this row deliberately excludes RecordTimerTextIndicator to avoid duplicating the portrait timecode bar.
    }

    private func officialTopReadoutBar(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 13 : 20) {
            ForEach(bottomControlItems) { item in
                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    Text(item.title)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                        .tracking(0.55)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(item.value)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(minWidth: compact ? 26 : 36, alignment: .leading)
            }
            Spacer(minLength: compact ? 6 : 12)
            HStack(spacing: compact ? 4 : 6) {
                BMDAssetIcon(name: "BatteryIndicator", fallback: "battery.100", color: .white, size: compact ? 11 : 14)
                BMDAssetIcon(name: "StorageIphone", fallback: "sdcard", color: .white, size: compact ? 11 : 14)
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: compact ? 1 : 2) {
                Text("Short Films")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.vertical, compact ? 1 : 2)
                    .background(BlackmagicCamStyle.activeBlue, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                Text(timecode)
                    .font(BlackmagicCamStyle.timecodeFont(size: compact ? 17 : 25))
                    .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.90))
                    .shadow(color: .black.opacity(0.75), radius: 1, x: 0, y: 1)
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 4)
        // Firmware/update note: top readout order and project/timecode badge are copied from Blackmagic Cam 3.2.00 screenshots and symbol names MainControlRecordTimer/HUDTopIndicators.
    }

    private func officialPortraitTopCluster(compact: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Spacer()
                Text("Short Films")
                    .font(BlackmagicCamStyle.labelFont(size: 6, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(BlackmagicCamStyle.activeBlue, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                Text("97%")
                    .font(BlackmagicCamStyle.labelFont(size: 7, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                Spacer()
            }
            Text(timecode)
                .font(BlackmagicCamStyle.timecodeFont(size: 25))
                .foregroundStyle(BlackmagicCamStyle.recordRed.opacity(0.95))
            HStack(alignment: .top, spacing: 12) {
                ForEach(bottomControlItems) { item in
                    VStack(spacing: 1) {
                        Text(item.title)
                            .font(BlackmagicCamStyle.labelFont(size: 6, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.72))
                        Text(item.value)
                            .font(BlackmagicCamStyle.labelFont(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 5)
        // Firmware/update note: portrait top cluster matches 3.2.00 screenshot: blue project chip, red timecode, then LENS/FPS/SHUTTER/IRIS/ISO/WB/TINT.
    }

    private func portraitControlDock(compact: Bool) -> some View {
        HStack(spacing: 0) {
            monitorIconButton(asset: "Slate", color: .white.opacity(0.78), scroller: .preset, compact: true)
            Spacer()
            monitorIconButton(asset: "Focus", color: .white.opacity(0.78), scroller: .focus, compact: true)
            monitorIconButton(asset: "Exposure", color: .white.opacity(0.78), scroller: .exposure, compact: true)
            Spacer()
            Button(action: onCapture) {
                RecordButtonView(active: isCaptureActive, enabled: canCapture, compact: false)
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .disabled(!canCapture)
            Spacer()
            monitorIconButton(asset: "IconAf", color: .white.opacity(0.78), scroller: .focusAssist, compact: true)
            monitorIconButton(asset: "Guides", color: .white.opacity(0.78), scroller: .guides, compact: true)
            monitorIconButton(asset: "FalseColor", color: .white.opacity(0.78), scroller: .falseColor, compact: true)
        }
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.94))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .top)
        // Firmware/update note: portrait bottom control dock mirrors the 3.2.00 screenshot's clapper/focus/exposure, central record button, and monitor tools above the page tab bar.
    }

    private func topLeftStatus(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            HUDCameraLightIndicator(title: isLiveActive ? "CAM" : "STBY", asset: "Camera", active: isLiveActive, compact: compact, color: BlackmagicCamStyle.cyan)
            HUDCameraLightIndicator(title: isCaptureActive ? "REC" : "READY", asset: "Record", active: isCaptureActive, compact: compact, color: BlackmagicCamStyle.recordRed)
            Text(subtitle.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                .tracking(0.55)
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.50)
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(.black.opacity(0.16), in: Capsule())
        // Firmware/update note: top overlay is status-only per recovered HUDTopLeftIndicators/HUDTopIndicators; LENS/FPS/SHUTTER/IRIS/ISO/WB/TINT must remain in the footer dial strip when the IPA changes.
    }

    private func recordTimerBar(compact: Bool) -> some View {
        VStack(spacing: compact ? 1 : 2) {
            HStack(spacing: compact ? 3 : 5) {
                HUDTallyDot(active: isCaptureActive, compact: compact)
                Text(timecode)
                    .font(BlackmagicCamStyle.timecodeFont(size: compact ? 17 : 24))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.95), radius: 1, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            Text(isCaptureActive ? "REC" : "00:00:00:00")
                .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(isCaptureActive ? BlackmagicCamStyle.recordRed : .white.opacity(0.48))
        }
        .padding(.horizontal, compact ? 3 : 5)
        .padding(.vertical, compact ? 1 : 2)
        // Firmware/update note: MainControlRecordTimer/RecordTimerTextIndicator is a monitor overlay centered near the top; keep it transparent and compact.
    }

    private func topStatusIcons(compact: Bool) -> some View {
        HStack(spacing: compact ? 4 : 6) {
            TopHudGlyph(asset: "IconLock", text: "TC", color: .white.opacity(0.70), compact: compact)
            TopHudGlyph(asset: "IconStream", text: "OFF", color: .white.opacity(0.68), compact: compact)
            TopHudGlyph(asset: "IconTimelapse", text: "TL", color: BlackmagicCamStyle.amber.opacity(0.82), compact: compact)
            TopHudGlyph(asset: "BatteryIndicator", text: "82", color: BlackmagicCamStyle.okGreen, compact: compact)
            TopHudGlyph(asset: "StorageIphone", text: "09", color: .white.opacity(0.82), compact: compact)
            TopHudGlyph(asset: "UploadToCloud", text: "--", color: BlackmagicCamStyle.amber, compact: compact)
        }
        .padding(.horizontal, compact ? 3 : 5)
        .padding(.vertical, compact ? 2 : 3)
        .background(.black.opacity(0.18), in: Capsule())
        // Firmware/update note: top-right cluster maps StorageStatusHUD/UploadStatusHUD/BatteryIndicator from the IPA; Blackmagic screenshots show tiny status glyphs rather than pill cards.
    }

    private func guideLayer(metrics: BlackmagicHUDMetrics) -> some View {
        let compact = metrics.compact
        let previewLeading = metrics.isLandscape ? metrics.safePad + 28 : metrics.safePad + 16
        let previewTrailing = metrics.isLandscape ? metrics.landscapeRightChromeWidth + metrics.safePad + 12 : metrics.safePad + 16
        return ZStack {
            if activeScroller == .guides {
                RuleOfThirds()
                    .stroke(.white.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [compact ? 5 : 7, compact ? 8 : 11]))
                    .padding(.leading, previewLeading)
                    .padding(.trailing, previewTrailing)
                    .padding(.vertical, metrics.isLandscape ? (compact ? 42 : 62) : (compact ? 108 : 132))
                VStack {
                    HStack {
                        FramingGuideLabel(text: "16:9", compact: compact)
                        Spacer()
                        FramingGuideLabel(text: "SAFE AREA", compact: compact)
                    }
                    Spacer()
                }
                .padding(.leading, previewLeading)
                .padding(.trailing, previewTrailing)
                .padding(.top, metrics.isLandscape ? (compact ? 44 : 64) : (compact ? 126 : 154))
            }

            if activeScroller == .focus || activeScroller == .focusAssist {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(activeScroller == .focusAssist ? BlackmagicCamStyle.okGreen.opacity(0.78) : BlackmagicCamStyle.activeBlue.opacity(0.70), lineWidth: activeScroller == .focusAssist ? 2 : 1)
                    .frame(width: compact ? 120 : 184, height: compact ? 72 : 108)
            }

            if activeScroller == .falseColor {
                VStack {
                    Spacer()
                    HStack {
                        FalseColorLegend(compact: compact)
                        Spacer()
                    }
                }
                .padding(.leading, previewLeading)
                .padding(.bottom, metrics.isLandscape ? (compact ? 42 : 58) : metrics.portraitControlBarHeight + metrics.pageTabHeight + 18)
            }

            if activeScroller == .whiteBalance {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        WhiteBalanceOverlay(compact: compact, value: value(forAny: ["WB", "White Balance"]))
                    }
                }
                .padding(.trailing, previewTrailing)
                .padding(.bottom, metrics.isLandscape ? (compact ? 42 : 58) : metrics.portraitControlBarHeight + metrics.pageTabHeight + 18)
            }

            if activeScroller == .zebra {
                ZebraOverlay(compact: compact)
                    .padding(.leading, previewLeading)
                    .padding(.trailing, previewTrailing)
                    .padding(.vertical, metrics.isLandscape ? (compact ? 42 : 62) : (compact ? 108 : 132))
            }
        }
        .allowsHitTesting(false)
        // Firmware/update note: Blackmagic Cam 3.2.00 screenshots show guides/false color/focus/zebra only when their recovered HUDLeadingIndicators tools are active; default preview is clean aside from top readouts and histogram/audio overlays.
    }

    private func rightPageNavigationRail(compact: Bool, horizontal: Bool = false) -> some View {
        BlackmagicRootPageRail(selection: navSelection, compact: compact, horizontal: horizontal, onNavigate: onNavigate)
        // Firmware/update note: landscape uses recovered right-edge BmdVTabView; portrait uses bottom BmdTabView order pageCamera/pageMedia/pageChat/pageSettings.
    }

    private func rightControlRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            monitorIconButton(asset: "Camera", color: .white.opacity(0.82), scroller: .lens, compact: compact)
            monitorIconButton(asset: "Focus", color: .white.opacity(0.72), scroller: .focus, compact: compact)
            monitorIconButton(asset: "Exposure", color: .white.opacity(0.78), scroller: .exposure, compact: compact)
            Button(action: onCapture) {
                RecordButtonView(active: isCaptureActive, enabled: canCapture, compact: true)
                    .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
            }
            .buttonStyle(.plain)
            .disabled(!canCapture)
            monitorIconButton(asset: "IconAf", color: .white.opacity(0.78), scroller: .focusAssist, compact: compact)
            monitorIconButton(asset: "FocusAutoZoom", color: .white.opacity(0.74), scroller: .zoom, compact: compact)
            Button {
                withAnimation(.snappy(duration: 0.18)) { showSlate = true }
            } label: {
                monitorIconShell(asset: "Slate", color: .white.opacity(0.76), active: showSlate, compact: compact)
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, compact ? 9 : 12)
        .background(Color.black.opacity(0.92))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(width: 1), alignment: .leading)
        // Firmware/update note: landscape right utility strip is the black vertical bar in the 3.2.00 screenshots, separate from the blue-highlight page rail.
    }

    private func leftMonitorRail(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 7) {
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
        .padding(.vertical, compact ? 4 : 6)
        .padding(.horizontal, compact ? 2 : 3)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))
        // Firmware/update note: icon-only left monitor rail maps HUDLeadingIndicators plus FocusAssistScroller/FramingGuidesScroller/SafeAreaScroller/ZebraScroller/LutScroller; 3.2.00 screenshots keep it very narrow and translucent.
    }

    private func monitorIconButton(asset: String, color: Color, scroller: BlackmagicHUDScroller, compact: Bool) -> some View {
        BmdIndicatorIconButton(image: asset, active: activeScroller == scroller, compact: compact, color: color) {
            withAnimation(.snappy(duration: 0.18)) { activeScroller = scroller }
        }
    }

    private func monitorIconShell(asset: String, color: Color, active: Bool, compact: Bool) -> some View {
        BMDAssetIcon(name: asset, active: active, color: active ? .white : color, size: compact ? 13 : 16)
            .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
            .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.68) : .black.opacity(0.24), in: RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.50) : .white.opacity(0.07), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
        // Firmware/update note: retained for non-button overlays; interactive indicators use recovered BmdIndicatorIconButton above.
    }

    private func bottomScopeStrip(compact: Bool) -> some View {
        HStack(alignment: .bottom, spacing: compact ? 8 : 12) {
            ForEach(0..<3, id: \.self) { index in
                if bottomCards.indices.contains(index) {
                    BottomHUDPreviewCard(card: bottomCards[index], compact: compact)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, compact ? 3 : 5)
        .padding(.vertical, compact ? 2 : 3)
        // Firmware/update note: bottom monitor widgets map HUDHistogramPopUpView/HUDAudioLevelPopUpView/StorageStatusHUD and are small translucent overlays, not a full-width toolbar.
    }

    private func bottomControls(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: compact ? 7 : 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: compact ? 6 : 9) {
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
        }
        .padding(.horizontal, compact ? 2 : 4)
        .padding(.vertical, compact ? 1 : 2)
        // Firmware/update note: screenshot/binary evidence exposes BmdAdjustmentDial/BmdDialHDivider/BmdDialVDivider for the footer; capture/AF controls stay in the right function rail and the top HUD remains status-only.
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
    var safePad: CGFloat { compact ? 6 : 10 }
    var pageTabWidth: CGFloat { compact ? 54 : 68 }
    var pageTabHeight: CGFloat { compact ? 72 : 84 }
    var footerBottomPadding: CGFloat { compact ? 6 : 10 }
    var leftHudWidth: CGFloat { compact ? 26 : 34 }
    var rightControlRailWidth: CGFloat { compact ? 38 : 50 }
    var rightPageRailWidth: CGFloat { compact ? 54 : 68 }
    var landscapeRightChromeWidth: CGFloat { rightControlRailWidth + rightPageRailWidth }
    var portraitControlBarHeight: CGFloat { compact ? 72 : 86 }
    var footerHeight: CGFloat { compact ? 72 : 92 }
    // Firmware/update note: values are reverse-derived from 3.2.00 MainViewLayoutData/PortraitLayoutData/StealthLayoutData plus App Store 3.x screenshots: status-only top HUD, PSHUDTimecodeBar in portrait, BmdAdjustmentDial footer controls, narrow left HUD strip, function rail + page rail on the right, and no generic card-like bottom toolbar.
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
    case lens, zoom, fps, shutter, iris, iso, exposure, whiteBalance, tint, codec, lut, focus, focusAssist, falseColor, guides, zebra, ndFilter, monitor, audio, stabilization, preset
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
        case .ndFilter: return "ND FILTER"
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
        case .focusAssist, .falseColor, .guides, .zebra, .ndFilter, .monitor: return "Monitor"
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
        case .ndFilter: return BlackmagicReverseSpec.ndFilterOptions
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

private struct CameraTopReadout: View {
    let item: BottomControlItem
    let compact: Bool
    let active: Bool

    var body: some View {
        VStack(alignment: .center, spacing: compact ? 1 : 2) {
            Text(item.title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 4.8 : 6, weight: .heavy))
                .tracking(0.35)
                .foregroundStyle(active ? BlackmagicCamStyle.cyan : .white.opacity(0.58))
            Text(item.value)
                .font(BlackmagicCamStyle.readoutFont(size: compact ? 7.2 : 9.5, weight: .heavy))
                .foregroundStyle(.white.opacity(active ? 1.0 : 0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .frame(minWidth: compact ? 24 : 34)
        .padding(.horizontal, compact ? 1 : 2)
        .padding(.vertical, compact ? 1 : 2)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.42) : .clear, in: RoundedRectangle(cornerRadius: compact ? 3 : 4, style: .continuous))
        // Firmware/update note: copied from 3.2.00 landscape screenshots where camera readouts are top-aligned tiny text: LENS 77mm, FPS 30, SHUTTER 1/120, IRIS f8.0, ISO 800, WB 5600K, TINT -10.
    }
}

private struct TopHudGlyph: View {
    let asset: String
    let text: String
    let color: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            BMDAssetIcon(name: asset, active: true, color: color, size: compact ? 8 : 10)
            Text(text)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}

private struct MiniFooterReadout: View {
    let item: BottomControlItem
    let compact: Bool
    let active: Bool

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            BMDAssetIcon(name: item.asset, active: active, color: active ? BlackmagicCamStyle.cyan : .white.opacity(0.60), size: compact ? 9 : 11)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5.5 : 7, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(active ? BlackmagicCamStyle.cyan : .white.opacity(0.50))
                Text(item.value)
                    .font(BlackmagicCamStyle.readoutFont(size: compact ? 8.5 : 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background(active ? BlackmagicCamStyle.activeBlue.opacity(0.32) : .black.opacity(0.22), in: RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous).stroke(active ? BlackmagicCamStyle.cyan.opacity(0.35) : .white.opacity(0.06), lineWidth: 1))
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
        BmdPopoverShell(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(scroller.eyebrow.uppercased()).font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy)).tracking(1.4).foregroundStyle(BlackmagicCamStyle.cyan)
                        Text(scroller.title).font(BlackmagicCamStyle.labelFont(size: compact ? 17 : 22, weight: .heavy)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text("SWIPE TO SELECT").font(BlackmagicCamStyle.labelFont(size: compact ? 8 : 9, weight: .heavy)).tracking(1.1).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
                    BmdTextButton(title: "Close", compact: compact, color: BlackmagicCamStyle.cyan, action: onClose)
                }
                if scroller == .lut {
                    LutNamesPanel(compact: compact)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: compact ? 7 : 10) {
                        ForEach(Array(scroller.options.enumerated()), id: \.offset) { index, option in
                            Button { onSelect(option) } label: {
                                ScrollerOptionDial(option: option, selected: index == 0, compact: compact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        // Firmware/update note: option strips mirror recovered BmdPopover, BmdTextButton, FpsOptions, ShutterScroll, IsoScroll, ZoomScroll, ExposureScroll, LutScroller and Monitor scroller families.
    }
}

private struct ScrollerOptionDial: View {
    let option: String
    let selected: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            BmdAdjustmentDialShape()
                .fill(selected ? BlackmagicCamStyle.activeBlue.opacity(0.24) : Color.black.opacity(0.56))
            BmdAdjustmentDialShape()
                .stroke(selected ? BlackmagicCamStyle.cyan.opacity(0.48) : .white.opacity(0.12), lineWidth: 1)
            BmdDialHDivider()
                .stroke(.white.opacity(selected ? 0.20 : 0.09), lineWidth: 1)
                .padding(.horizontal, compact ? 10 : 12)
            VStack(spacing: compact ? 6 : 8) {
                Text(option.uppercased())
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 10 : 12, weight: selected ? .heavy : .bold))
                    .tracking(0.7)
                    .foregroundStyle(selected ? .white : .white.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                BmdDialMarkerRow(active: selected, compact: compact)
            }
            .padding(.horizontal, compact ? 10 : 13)
            if selected {
                Text("SEL")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 6, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(BlackmagicCamStyle.activeBlue.opacity(0.95), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, compact ? 5 : 7)
                    .padding(.trailing, compact ? 6 : 8)
            }
        }
        .frame(width: compact ? 102 : 136, height: compact ? 58 : 72)
        .contentShape(BmdAdjustmentDialShape())
        // Firmware/update note: popup choices are rendered with the recovered BmdAdjustmentDial/BmdAdjustmentDialMarker visual language instead of generic list pills; update from FpsOptions/ShutterScroll/etc symbols when IPA UI changes.
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
                AudioMeterMini(levels: levels, compact: compact)
                    .frame(width: compact ? 66 : 86)
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
    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            BMDAssetImage(name: "FalseColorLegend", fallback: "circle.lefthalf.filled", preserveOriginalColors: true)
                .frame(width: compact ? 30 : 40, height: compact ? 121 : 161)
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                Text("FALSE COLOR")
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 8, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.68))
                ForEach(["HIGH", "SKIN", "MID", "18%", "LOW"], id: \.self) { label in
                    Text(label)
                        .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 7, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }
        }
        .padding(compact ? 6 : 8)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        // Firmware/update note: uses the real recovered FalseColorLegend asset (150x603 @3x) instead of a synthetic color strip; refresh asset dimensions via assetutil when IPA updates.
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

private enum SlateInfoTab: String, CaseIterable, Identifiable {
    case project, clip, lens
    var id: String { rawValue }
    var title: String {
        switch self {
        case .project: return "PROJECT INFO"
        case .clip: return "CLIP INFO"
        case .lens: return "LENS INFO"
        }
    }
    var evidenceName: String {
        switch self {
        case .project: return "SlateViewProjectInfo"
        case .clip: return "SlateViewClipInfo"
        case .lens: return "SlateViewLensInfo"
        }
    }
    var fields: [String] {
        switch self {
        case .project:
            return BlackmagicReverseSpec.slateProjectFields
        case .clip:
            return ["SLATE FOR", "SCENE", "TAKE", "REEL", "Good Take Last Clip", "Interior", "Exterior", "Day", "Night", "Next Clip"]
        case .lens:
            return ["LENS DATA", "Lens", "Frame Rate", "Iris", "ISO", "Shutter", "WB", "Tint"]
        }
    }
}

private struct SlateOverlay: View {
    let compact: Bool
    let onClose: () -> Void

    private var bluePanel: Color { Color(red: 0.11, green: 0.18, blue: 0.30) }
    private var blueCell: Color { Color(red: 0.15, green: 0.24, blue: 0.39) }
    private var activeBlueCell: Color { Color(red: 0.22, green: 0.38, blue: 0.66) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    BMDAssetIcon(name: "SlateClose", fallback: "xmark", color: .white.opacity(0.52), size: compact ? 11 : 14)
                        .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                }
                .buttonStyle(.plain)
            }
            .frame(height: compact ? 18 : 24)

            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    SlateTopField(title: "SLATE FOR", value: "Next Clip", compact: compact)
                    SlateTopField(title: "LENS DATA", value: "iPhone 14 Pro Max 77mm", compact: compact)
                }
                .frame(height: compact ? 48 : 64)

                HStack(spacing: 1) {
                    SlateNumberCell(title: "REEL", value: "1", compact: compact)
                    SlateNumberCell(title: "SCENE", value: "10", compact: compact)
                    SlateNumberCell(title: "TAKE", value: "2", suffix: "A", compact: compact)
                }
                .frame(height: compact ? 62 : 86)

                HStack(spacing: 1) {
                    SlateChoiceCell(title: "Good Take Last Clip", selected: false, compact: compact)
                    SlateChoiceCell(title: "Interior", selected: true, compact: compact)
                    SlateChoiceCell(title: "Exterior", selected: false, compact: compact)
                    SlateChoiceCell(title: "Day", selected: true, compact: compact)
                    SlateChoiceCell(title: "Night", selected: false, compact: compact)
                }
                .frame(height: compact ? 32 : 44)
            }
            .background(.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 4 : 6, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))

            HStack(spacing: compact ? 3 : 4) {
                Circle().fill(BlackmagicCamStyle.activeBlue).frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
                Circle().fill(.white.opacity(0.30)).frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
            }
            .padding(.top, compact ? 8 : 10)
        }
        .frame(maxWidth: compact ? 520 : 760)
        .padding(.horizontal, compact ? 12 : 18)
        .padding(.vertical, compact ? 8 : 12)
        .background(Color(red: 0.035, green: 0.055, blue: 0.085).opacity(0.94), in: RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous))
        .shadow(color: .black.opacity(0.62), radius: 24, x: 0, y: 12)
        // Firmware/update note: this maps 3.2.00 SlateView/SlateViewClipInfo screenshot exactly: top Slate/Lens fields, REEL/SCENE/TAKE numeric cells, Interior/Day choice strip, pager dots, and close X.
    }
}

private struct SlateTopField: View {
    let title: String
    let value: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 7 : 9)
        .background(Color(red: 0.12, green: 0.20, blue: 0.34))
    }
}

private struct SlateNumberCell: View {
    let title: String
    let value: String
    var suffix: String? = nil
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            Text(title)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 5 : 7, weight: .heavy))
                .foregroundStyle(.white.opacity(0.46))
                .frame(maxWidth: .infinity, alignment: .topLeading)
            HStack(spacing: compact ? 12 : 18) {
                Image(systemName: "chevron.left")
                    .font(.system(size: compact ? 11 : 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                Text(value)
                    .font(BlackmagicCamStyle.timecodeFont(size: compact ? 22 : 34))
                    .foregroundStyle(.white)
                    .frame(minWidth: compact ? 34 : 48)
                Image(systemName: "chevron.right")
                    .font(.system(size: compact ? 11 : 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
            }
            if let suffix {
                Text(suffix)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.50))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 5 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.15, green: 0.24, blue: 0.39))
    }
}

private struct SlateChoiceCell: View {
    let title: String
    let selected: Bool
    let compact: Bool

    var body: some View {
        Text(title)
            .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 8, weight: .heavy))
            .foregroundStyle(.white.opacity(selected ? 0.94 : 0.58))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? Color(red: 0.24, green: 0.39, blue: 0.66) : Color(red: 0.15, green: 0.24, blue: 0.39))
    }
}

private struct SlateTabButton: View {
    let tab: SlateInfoTab
    let active: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Capsule()
                .fill(active ? BlackmagicCamStyle.amber : .white.opacity(0.18))
                .frame(width: 3, height: compact ? 24 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 9 : 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(tab.evidenceName)
                    .font(BlackmagicCamStyle.labelFont(size: compact ? 6 : 7, weight: .heavy))
                    .foregroundStyle(.white.opacity(active ? 0.58 : 0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 8 : 10)
        .background(active ? BlackmagicCamStyle.amber.opacity(0.20) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: compact ? 11 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 11 : 14, style: .continuous).stroke(active ? BlackmagicCamStyle.amber.opacity(0.45) : .white.opacity(0.08), lineWidth: 1))
    }
}

private struct SlateInputCell: View {
    let field: String
    let value: String
    let compact: Bool
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            Text(field.uppercased())
                .font(BlackmagicCamStyle.labelFont(size: compact ? 7 : 9, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(value)
                .font(BlackmagicCamStyle.labelFont(size: compact ? 13 : 16, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
            Rectangle()
                .fill(accent.opacity(0.70))
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 60 : 74, alignment: .leading)
        .padding(compact ? 10 : 13)
        .background(.white.opacity(0.052), in: RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 13, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
        // Firmware/update note: input styling maps BmdPopUpInput/BmdPopUpInputTextField and SlateView* field-selection symbols rather than generic cards.
    }
}

private struct ZebraOverlay: View {
    let compact: Bool

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = compact ? 18 : 24
                var x: CGFloat = -proxy.size.height
                while x < proxy.size.width + proxy.size.height {
                    path.move(to: CGPoint(x: x, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: x + proxy.size.height, y: 0))
                    x += step
                }
            }
            .stroke(BlackmagicCamStyle.recordRed.opacity(0.32), lineWidth: compact ? 1 : 1.4)
        }
        // Firmware/update note: ZebraScroller is represented as a red diagonal exposure overlay only when the zebra tool is active, matching recovered Zebra/ZebraScroller symbols.
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



