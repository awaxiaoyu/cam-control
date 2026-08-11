import AVFoundation
import AVKit
import CamControlCore
import SwiftUI
import UIKit

struct PhoneCameraWorkspaceView: View {
    @AppStorage("camera.source.kind") private var selectedSourceRaw = CameraSourceKind.phone.rawValue
    @StateObject private var camera = PhoneCameraViewModel()
    @State private var page: WorkspaceTab?

    var body: some View {
        ZStack {
            ShootingHUDLayout(
                title: "Blackmagic Camera",
                subtitle: camera.activePosition == .front ? "Front Camera" : "Back Camera",
                timecode: camera.timecode,
                topItems: topItems,
                bottomCards: bottomCards,
                navSelection: navSelection,
                isCaptureActive: camera.isRecording,
                isLiveActive: camera.isSessionRunning,
                canCapture: camera.isReady,
                canFocus: camera.isReady,
                canToggleLive: true,
                onCapture: {
                    camera.toggleRecording()
                },
                onToggleLive: {
                    camera.start()
                },
                onFocus: {
                    camera.autofocus()
                },
                onRefresh: {
                    if camera.isSessionRunning, camera.canSwitchCamera {
                        camera.switchCamera()
                    } else {
                        camera.start()
                    }
                },
                onHUDOption: { option in
                    camera.handleHUDOption(option)
                },
                onNavigate: navigate
            ) {
                ZStack {
                    if let session = camera.session {
                        PhoneCameraPreview(session: session, activePosition: camera.activePosition)
                            .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                    }

                    if camera.isRecording {
                        VStack {
                            HStack {
                                HUDCameraLightIndicator(title: "REC", asset: "Record", active: true, compact: true, color: BlackmagicCamStyle.recordRed)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.40), in: Capsule())
                                Spacer()
                            }
                            .padding(.top, 62)
                            .padding(.leading, 16)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }

                    if let image = camera.lastPhoto {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 92, height: 122)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(.white.opacity(0.9), lineWidth: 2)
                                    )
                                    .shadow(radius: 8)
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 128)
                            }
                        }
                    }

                    if let message = camera.overlayMessage {
                        VStack(spacing: 12) {
                            BMDAssetIcon(name: "Camera", fallback: "camera.viewfinder", color: .white, size: 44)
                            Text(message)
                                .font(BlackmagicCamStyle.labelFont(size: 16, weight: .heavy))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .padding(24)
                        .blackmagicPanel(cornerRadius: 18, borderOpacity: 0.20)
                        .padding()
                    }
                }
            }

            if let page {
                cameraPage(page)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .background(BlackmagicCamStyle.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedSourceRaw = CameraSourceKind.phone.rawValue
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        // Firmware/update note: phone camera now owns real offline capture/recording so future iOS camera API changes should update PhoneCameraViewModel, not the Blackmagic HUD shell.
    }


    private var navSelection: ShootingHUDNavItem {
        switch page {
        case .some(.gallery): return .media
        case .some(.chat): return .chat
        case .some(.controls): return .settings
        case .none, .some(.live): return .camera
        }
    }

    private func navigate(_ item: ShootingHUDNavItem) {
        withAnimation(.snappy(duration: 0.20)) {
            switch item {
            case .camera:
                page = nil
            case .media:
                page = .gallery
            case .chat:
                page = .chat
            case .settings:
                page = .controls
            }
        }
    }

    @ViewBuilder
    private func cameraPage(_ tab: WorkspaceTab) -> some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 980 || proxy.size.height < 620
            ZStack(alignment: .topTrailing) {
                Group {
                    switch tab {
                    case .live:
                        EmptyView()
                    case .controls:
                        PropertyPanel()
                    case .gallery:
                        PhoneMediaGalleryView(clips: camera.recordedClips, lastPhoto: camera.lastPhoto)
                    case .chat:
                        CloudChatPanel()
                    }
                }
                .padding(.trailing, compact ? 64 : 84)

                BlackmagicRootPageRail(selection: navSelection, compact: compact, onNavigate: navigate)
                    .padding(.trailing, compact ? 8 : 14)
                    .padding(.top, compact ? 76 : 110)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .allowsHitTesting(true)
        }
        .background(BlackmagicCamStyle.canvas)
        .ignoresSafeArea()
        // Firmware/update note: page switching mirrors recovered pageCamera/pageMedia/pageChat/pageSettings; Media is now backed by local recorded clips while Blackmagic Cloud online sync remains intentionally offline.
    }

    private var topItems: [ShootingHUDTopItem] {
        [
            ShootingHUDTopItem(title: "LENS", value: camera.lensLabel),
            ShootingHUDTopItem(title: "FPS", value: "24"),
            ShootingHUDTopItem(title: "SHUTTER", value: "1/48", isAuto: true, isMonospaced: true),
            ShootingHUDTopItem(title: "IRIS", value: "f1.8", isDimmed: true, isMonospaced: true),
            ShootingHUDTopItem(title: "ISO", value: "Auto", isAuto: true),
            ShootingHUDTopItem(title: "WB", value: camera.whiteBalanceLabel, isAuto: true),
            ShootingHUDTopItem(title: "TINT", value: "0", isMonospaced: true)
        ]
    }

    private var bottomCards: [ShootingHUDBottomCard] {
        [
            ShootingHUDBottomCard(title: "Rec.709", kind: .histogram(ShootingHUDFixtures.histogramBars)),
            ShootingHUDBottomCard(title: "Storage", kind: .storage(primary: camera.isRecording ? "REC" : "READY", progress: camera.isRecording ? 0.86 : 0.35, trailing: "\(camera.recordedClips.count) clips")),
            ShootingHUDBottomCard(title: "iPhone Mic", kind: .audio(camera.audioLevels))
        ]
    }
}

private struct PhoneCameraClip: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let createdAt: Date
    let duration: TimeInterval

    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var durationText: String {
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PhoneMediaGalleryView: View {
    let clips: [PhoneCameraClip]
    let lastPhoto: UIImage?

    var body: some View {
        ZStack {
            BlackmagicCamStyle.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                BMSectionHeader(
                    eyebrow: "Media",
                    title: "Local Clips",
                    subtitle: "Offline in-app recordings from the phone camera"
                )
                if clips.isEmpty, lastPhoto == nil {
                    BMEmptyState(
                        systemImage: "film.stack",
                        title: "No local media yet",
                        subtitle: "Tap the red record button on Camera to create a .mov clip. Cloud sync stays offline for now."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(clips.reversed()) { clip in
                                PhoneClipRow(clip: clip)
                            }
                            if let lastPhoto {
                                HStack(spacing: 12) {
                                    Image(uiImage: lastPhoto)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last Photo")
                                            .font(BlackmagicCamStyle.labelFont(size: 13, weight: .heavy))
                                            .foregroundStyle(.white)
                                        Text("Still capture preview")
                                            .font(BlackmagicCamStyle.labelFont(size: 10, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.48))
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .blackmagicPanel(cornerRadius: 12)
                            }
                        }
                    }
                }
            }
            .padding(.top, 72)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        // Firmware/update note: this is the offline MediaTab equivalent; when online Blackmagic Cloud returns, add upload/sync state here without replacing local clip playback.
    }
}

private struct PhoneClipRow: View {
    let clip: PhoneCameraClip
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                BMDAssetIcon(name: "Media", fallback: "film", color: BlackmagicCamStyle.cyan, size: 22)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.displayName)
                        .font(BlackmagicCamStyle.labelFont(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("MOV  •  \(clip.durationText)")
                        .font(BlackmagicCamStyle.labelFont(size: 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.50))
                }
                Spacer()
                ShareLink(item: clip.url) {
                    BMDAssetIcon(name: "UploadToCloud", fallback: "square.and.arrow.up", color: .white.opacity(0.78), size: 18)
                        .frame(width: 34, height: 34)
                }
                Button {
                    withAnimation(.snappy(duration: 0.18)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "play.fill")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            if isExpanded {
                VideoPlayer(player: AVPlayer(url: clip.url))
                    .frame(height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
            }
        }
        .padding(10)
        .blackmagicPanel(cornerRadius: 14)
        // Firmware/update note: local playback uses the clip URL from AVCaptureMovieFileOutput; if Blackmagic changes media naming, update displayName generation only.
    }
}

private final class PhoneCameraViewModel: NSObject, ObservableObject {
    @Published private(set) var session: AVCaptureSession?
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var audioAuthorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false
    @Published private(set) var timecode = "00:00:00:00"
    @Published private(set) var lastPhoto: UIImage?
    @Published private(set) var lastError: String?
    @Published private(set) var activePosition: AVCaptureDevice.Position = .back
    @Published private(set) var lensLabel = "24mm"
    @Published private(set) var whiteBalanceLabel = "4700K"
    @Published private(set) var audioLevels: [Double] = [0.24, 0.21]
    @Published private(set) var recordedClips: [PhoneCameraClip] = []
    @Published private(set) var hasAttemptedStart = false

    private let sessionQueue = DispatchQueue(label: "com.aicomposition.camcontrol.phone-camera.session")
    private var currentSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var recordingStartedAt: Date?
    private var timecodeTimer: Timer?

    var isReady: Bool {
        authorizationStatus == .authorized && isSessionRunning
    }

    var canSwitchCamera: Bool {
        cameraDevice(position: .front) != nil && cameraDevice(position: .back) != nil
    }

    var overlayMessage: String? {
        if let lastError {
            return lastError
        }
        switch authorizationStatus {
        case .authorized:
            return isSessionRunning ? nil : "Starting phone camera..."
        case .notDetermined:
            return "Requesting camera permission..."
        case .denied, .restricted:
            return "Camera permission is disabled. Enable Camera access in Settings."
        @unknown default:
            return "Camera is unavailable."
        }
    }

    func start() {
        hasAttemptedStart = true
        Task { [weak self] in
            guard let self else { return }
            let granted = await self.requestVideoAccessIfNeeded()
            guard granted else { return }
            let includeAudio = await self.requestAudioAccessIfNeeded()
            self.sessionQueue.async { [weak self] in
                self?.configureAndStart(includeAudio: includeAudio)
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.movieOutput?.isRecording == true {
                self.movieOutput?.stopRecording()
            }
            if let session = self.currentSession, session.isRunning {
                session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.isRecording = false
                self.stopTimecodeTimer(reset: true)
            }
        }
    }

    func switchCamera() {
        let nextPosition: AVCaptureDevice.Position = activePosition == .back ? .front : .back
        switchCamera(to: nextPosition)
    }

    func switchCamera(to position: AVCaptureDevice.Position) {
        guard currentSession != nil else {
            start()
            return
        }
        guard !isRecording else {
            publishError("Stop recording before switching camera.")
            return
        }
        sessionQueue.async { [weak self] in
            self?.reconfigureInput(position: position)
        }
    }

    func toggleRecording() {
        guard isReady else {
            start()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let output = self.movieOutput else {
                self.publishError("Video recording output is unavailable.")
                return
            }
            if output.isRecording {
                output.stopRecording()
                return
            }
            do {
                let url = try Self.makeRecordingURL()
                self.configureMovieConnection()
                output.startRecording(to: url, recordingDelegate: self)
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    func capturePhoto() {
        guard isReady else { return }
        guard let output = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(.auto), activePosition == .back {
            settings.flashMode = .auto
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func autofocus() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.lastError = nil }
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
        // Firmware/update note: AF maps Blackmagic Focus/AF controls to native iPhone focus APIs; if iOS camera focus modes change, update this adapter only.
    }

    func handleHUDOption(_ option: String) {
        let normalized = option.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized.lowercased() {
        case "refresh", "live":
            start()
        case "front":
            switchCamera(to: .front)
        case "af":
            autofocus()
        case "auto":
            resetAutoExposureAndFocus()
        case "lock":
            lockFocusAndExposure()
        default:
            if let zoom = Self.zoomPreset(for: normalized) {
                applyZoom(zoom.factor, label: zoom.label)
            }
        }
        // Firmware/update note: HUD scroller options come from the Blackmagic 3.2.00 Lens/Fps/Shutter/Iris/Iso/WB/Tint option families; unsupported online/cloud choices intentionally no-op until those services are rebuilt.
    }

    @MainActor
    private func requestVideoAccessIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    @MainActor
    private func requestAudioAccessIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        audioAuthorizationStatus = status
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            audioAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureAndStart(includeAudio: Bool) {
        let captureSession = currentSession ?? AVCaptureSession()
        currentSession = captureSession
        if !isConfigured {
            captureSession.beginConfiguration()
            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            }
            reconfigureInput(position: activePosition, commitConfiguration: false)
            configureAudioInput(includeAudio: includeAudio, session: captureSession)

            let photo = photoOutput ?? AVCapturePhotoOutput()
            photoOutput = photo
            if captureSession.canAddOutput(photo) {
                captureSession.addOutput(photo)
            }

            let movie = movieOutput ?? AVCaptureMovieFileOutput()
            movieOutput = movie
            if captureSession.canAddOutput(movie) {
                captureSession.addOutput(movie)
            }
            captureSession.commitConfiguration()
            configureMovieConnection()
            isConfigured = true
        } else if includeAudio, audioInput == nil {
            captureSession.beginConfiguration()
            configureAudioInput(includeAudio: true, session: captureSession)
            captureSession.commitConfiguration()
        }

        guard currentInput != nil else {
            publishError("No built-in camera was found on this device.")
            return
        }

        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        DispatchQueue.main.async {
            self.session = captureSession
            self.isSessionRunning = captureSession.isRunning
            self.lastError = nil
        }
        // Firmware/update note: real phone recording uses AVCaptureMovieFileOutput to match Blackmagic's offline record-first camera behavior; cloud upload remains outside this adapter.
    }

    private func configureAudioInput(includeAudio: Bool, session: AVCaptureSession) {
        guard includeAudio, audioInput == nil, let device = AVCaptureDevice.default(for: .audio) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            }
        } catch {
            publishError(error.localizedDescription)
        }
    }

    private func reconfigureInput(position: AVCaptureDevice.Position, commitConfiguration: Bool = true) {
        guard let device = cameraDevice(position: position) else {
            publishError(position == .front ? "Front camera is unavailable." : "Back camera is unavailable.")
            return
        }
        reconfigureInput(device: device, position: position, commitConfiguration: commitConfiguration)
    }

    private func reconfigureInput(device: AVCaptureDevice, position: AVCaptureDevice.Position, commitConfiguration: Bool = true) {
        guard let captureSession = currentSession else {
            publishError("Phone camera session has not been created.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if commitConfiguration {
                captureSession.beginConfiguration()
            }
            if let currentInput {
                captureSession.removeInput(currentInput)
            }
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentInput = input
                configureMovieConnection()
                DispatchQueue.main.async {
                    self.activePosition = position
                    self.lensLabel = position == .front ? "FRONT" : "24mm"
                    self.lastError = nil
                }
            } else {
                publishError("Phone camera input cannot be added.")
            }
            if commitConfiguration {
                captureSession.commitConfiguration()
            }
        } catch {
            publishError(error.localizedDescription)
            if commitConfiguration {
                captureSession.commitConfiguration()
            }
        }
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if position == .back {
            deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInUltraWideCamera, .builtInWideAngleCamera]
        } else {
            deviceTypes = [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }

    private func applyZoom(_ factor: CGFloat, label: String) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let minimum = device.minAvailableVideoZoomFactor
                let maximum = min(device.maxAvailableVideoZoomFactor, 8.0)
                let clamped = min(max(factor, minimum), maximum)
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.lensLabel = label
                    self.lastError = nil
                }
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    private func resetAutoExposureAndFocus() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.whiteBalanceLabel = "Auto"
                    self.lastError = nil
                }
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    private func lockFocusAndExposure() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
                if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
                if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.lastError = nil }
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    private func configureMovieConnection() {
        guard let connection = movieOutput?.connection(with: .video) else { return }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = Self.currentVideoOrientation
        }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }

    private static var currentVideoOrientation: AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    private static func zoomPreset(for option: String) -> (factor: CGFloat, label: String)? {
        switch option.lowercased() {
        case "0.5x", "13mm": return (0.5, option)
        case "1.0x", "1x", "24mm": return (1.0, option == "1x" ? "1.0x" : option)
        case "2.0x", "2x", "48mm": return (2.0, option == "2x" ? "2.0x" : option)
        case "3.0x", "3x", "77mm": return (3.0, option == "3x" ? "3.0x" : option)
        case "5.0x", "5x": return (5.0, option == "5x" ? "5.0x" : option)
        case "35mm": return (1.45, option)
        default: return nil
        }
    }

    private static func makeRecordingURL() throws -> URL {
        let directory = try recordingDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = directory.appendingPathComponent("A001_\(timestamp).mov")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        return url
    }

    private static func recordingDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("BlackmagicCam", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func startTimecodeTimer(start: Date) {
        timecodeTimer?.invalidate()
        recordingStartedAt = start
        timecode = "00:00:00:00"
        timecodeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartedAt else { return }
            let elapsed = Date().timeIntervalSince(start)
            self.timecode = Self.formatTimecode(elapsed: elapsed)
            let pulse = 0.18 + min(0.70, abs(sin(elapsed * 2.1)) * 0.44)
            self.audioLevels = [pulse, max(0.08, pulse * 0.82)]
        }
    }

    private func stopTimecodeTimer(reset: Bool) {
        timecodeTimer?.invalidate()
        timecodeTimer = nil
        recordingStartedAt = nil
        audioLevels = [0.24, 0.21]
        if reset {
            timecode = "00:00:00:00"
        }
    }

    private static func formatTimecode(elapsed: TimeInterval) -> String {
        let frameRate = 24
        let totalFrames = max(0, Int((elapsed * Double(frameRate)).rounded(.down)))
        let frames = totalFrames % frameRate
        let totalSeconds = totalFrames / frameRate
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async {
            self.lastError = message
            self.isSessionRunning = false
        }
    }
}

extension PhoneCameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            publishError(error.localizedDescription)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            publishError("Captured photo data could not be decoded.")
            return
        }
        DispatchQueue.main.async {
            self.lastPhoto = image
            self.lastError = nil
        }
    }
}

extension PhoneCameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            let start = Date()
            self.isRecording = true
            self.lastError = nil
            self.startTimecodeTimer(start: start)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            let duration = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            self.isRecording = false
            self.stopTimecodeTimer(reset: true)
            if let error {
                self.lastError = error.localizedDescription
                return
            }
            guard FileManager.default.fileExists(atPath: outputFileURL.path) else {
                self.lastError = "Recorded clip file was not created."
                return
            }
            self.recordedClips.append(PhoneCameraClip(url: outputFileURL, createdAt: Date(), duration: duration))
            self.lastError = nil
        }
    }
}

private struct PhoneCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let activePosition: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.configure(position: activePosition)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.configure(position: activePosition)
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configure(position: nil)
    }

    func configure(position: AVCaptureDevice.Position?) {
        videoPreviewLayer.videoGravity = .resizeAspectFill
        guard let connection = videoPreviewLayer.connection else { return }

        if connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation
        }

        if let position, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
        // Firmware/update note: if future iOS camera orientation APIs replace AVCaptureConnection rotation/mirroring, update this adapter only; keep HUD layout coordinates unchanged.
    }

    private var currentVideoOrientation: AVCaptureVideoOrientation {
        guard let orientation = window?.windowScene?.interfaceOrientation else {
            return .landscapeRight
        }
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .landscapeRight
        }
    }
}
