import AVFoundation
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
                timecode: "00:00:00:00",
                topItems: topItems,
                bottomCards: bottomCards,
                navSelection: navSelection,
                isCaptureActive: false,
                isLiveActive: camera.isSessionRunning,
                canCapture: camera.isReady,
                canFocus: false,
                canToggleLive: true,
                onCapture: {
                    camera.capturePhoto()
                },
                onToggleLive: {
                    camera.start()
                },
                onFocus: {},
                onRefresh: {
                    if camera.isSessionRunning, camera.canSwitchCamera {
                        camera.switchCamera()
                    } else {
                        camera.start()
                    }
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
        }
        .onDisappear {
            camera.stop()
        }
        // Firmware/update note: if iOS camera APIs expose more per-device video properties after OS updates, populate topItems here while keeping the Blackmagic HUD shell stable.
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
                        GalleryView()
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
        // Firmware/update note: page switching mirrors recovered pageCamera/pageMedia/pageChat/pageSettings and BmdTabView/BmdVTabView symbols; rail remains anchored to the right edge like the 3.2.00 camera workspace, and non-camera panels reserve pageTabWidth.
    }

    private var topItems: [ShootingHUDTopItem] {
        [
            ShootingHUDTopItem(title: "LENS", value: camera.activePosition == .front ? "FRONT" : "24mm"),
            ShootingHUDTopItem(title: "FPS", value: "24"),
            ShootingHUDTopItem(title: "SHUTTER", value: "1/48", isAuto: true, isMonospaced: true),
            ShootingHUDTopItem(title: "IRIS", value: "f1.8", isDimmed: true, isMonospaced: true),
            ShootingHUDTopItem(title: "ISO", value: "Auto", isAuto: true),
            ShootingHUDTopItem(title: "WB", value: "4700K", isAuto: true),
            ShootingHUDTopItem(title: "TINT", value: "0", isMonospaced: true)
        ]
    }

    private var bottomCards: [ShootingHUDBottomCard] {
        [
            ShootingHUDBottomCard(title: "Rec.709", kind: .histogram(ShootingHUDFixtures.histogramBars)),
            ShootingHUDBottomCard(title: "Storage", kind: .storage(primary: "09:00", progress: camera.isReady ? 0.35 : 0.02, trailing: camera.lastPhoto == nil ? "3GB" : "1 shot")),
            ShootingHUDBottomCard(title: "iPhone Mic", kind: .audio([0.24, 0.21]))
        ]
    }
}
private final class PhoneCameraViewModel: NSObject, ObservableObject {
    @Published private(set) var session: AVCaptureSession?
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var lastPhoto: UIImage?
    @Published private(set) var lastError: String?
    @Published private(set) var activePosition: AVCaptureDevice.Position = .back
    @Published private(set) var hasAttemptedStart = false

    private let sessionQueue = DispatchQueue(label: "com.aicomposition.camcontrol.phone-camera.session")
    private var currentSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var isConfigured = false

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
        if session == nil && !hasAttemptedStart {
            return "Tap VIEW or Refresh to start phone camera."
        }
        switch authorizationStatus {
        case .authorized:
            return isSessionRunning ? nil : "Starting phone camera..."
        case .notDetermined:
            return hasAttemptedStart ? "Requesting camera permission..." : "Tap VIEW or Refresh to start phone camera."
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
            let granted = await self.requestAccessIfNeeded()
            guard granted else { return }
            self.sessionQueue.async { [weak self] in
                self?.configureAndStart()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let session = self.currentSession, session.isRunning {
                session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func switchCamera() {
        guard currentSession != nil else {
            start()
            return
        }
        let nextPosition: AVCaptureDevice.Position = activePosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            self?.reconfigureInput(position: nextPosition)
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

    @MainActor
    private func requestAccessIfNeeded() async -> Bool {
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

    private func configureAndStart() {
        let captureSession = currentSession ?? AVCaptureSession()
        currentSession = captureSession
        if !isConfigured {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo
            reconfigureInput(position: activePosition, commitConfiguration: false)
            let output = photoOutput ?? AVCapturePhotoOutput()
            photoOutput = output
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            captureSession.commitConfiguration()
            isConfigured = true
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
        // Firmware/update note: phone camera hardware is created only after user action; keep this lazy path so future iOS camera or game-version updates cannot crash the first rendered Blackmagic HUD frame.
    }

    private func reconfigureInput(position: AVCaptureDevice.Position, commitConfiguration: Bool = true) {
        guard let device = cameraDevice(position: position) else {
            publishError(position == .front ? "Front camera is unavailable." : "Back camera is unavailable.")
            return
        }

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
                DispatchQueue.main.async {
                    self.activePosition = position
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
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
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
