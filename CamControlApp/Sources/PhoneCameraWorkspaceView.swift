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
                canToggleLive: false,
                onCapture: {
                    camera.capturePhoto()
                },
                onToggleLive: {},
                onFocus: {},
                onRefresh: {
                    if camera.canSwitchCamera {
                        camera.switchCamera()
                    } else {
                        camera.start()
                    }
                },
                onNavigate: navigate
            ) {
                ZStack {
                    PhoneCameraPreview(session: camera.session, activePosition: camera.activePosition)
                        .ignoresSafeArea()

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
        ZStack(alignment: .topTrailing) {
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

            GeometryReader { proxy in
                let compact = proxy.size.width < 980 || proxy.size.height < 620
                BlackmagicRootPageRail(selection: navSelection, compact: compact, onNavigate: navigate)
                    .padding(.leading, compact ? 8 : 14)
                    .padding(.top, compact ? 76 : 110)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .allowsHitTesting(true)
        }
        .background(BlackmagicCamStyle.canvas)
        .ignoresSafeArea()
        // Firmware/update note: page switching mirrors recovered pageCamera/pageMedia/pageChat/pageSettings and BmdTabView/BmdVTabView symbols; update rail mapping only if new Blackmagic pages are added.
    }

    private var topItems: [ShootingHUDTopItem] {
        [
            ShootingHUDTopItem(title: "Lens", value: camera.activePosition == .front ? "Front" : "24mm"),
            ShootingHUDTopItem(title: "FPS", value: "24"),
            ShootingHUDTopItem(title: "Shutter", value: "1/24", isAuto: true, isMonospaced: true),
            ShootingHUDTopItem(title: "Iris", value: "f1.8", isDimmed: true, isMonospaced: true),
            ShootingHUDTopItem(title: "ISO", value: "Auto", isAuto: true),
            ShootingHUDTopItem(title: "WB", value: "4700K", isAuto: true),
            ShootingHUDTopItem(title: "Tint", value: "0", isMonospaced: true),
            ShootingHUDTopItem(title: "Format", value: "4K 16:9")
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
    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isSessionRunning = false
    @Published private(set) var lastPhoto: UIImage?
    @Published private(set) var lastError: String?
    @Published private(set) var activePosition: AVCaptureDevice.Position = .back

    private let sessionQueue = DispatchQueue(label: "com.aicomposition.camcontrol.phone-camera.session")
    private let photoOutput = AVCapturePhotoOutput()
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
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func switchCamera() {
        let nextPosition: AVCaptureDevice.Position = activePosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            self?.reconfigureInput(position: nextPosition)
        }
    }

    func capturePhoto() {
        guard isReady else { return }
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(.auto), activePosition == .back {
            settings.flashMode = .auto
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
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
        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .photo
            reconfigureInput(position: activePosition, commitConfiguration: false)
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            session.commitConfiguration()
            isConfigured = true
        }

        guard currentInput != nil else {
            publishError("No built-in camera was found on this device.")
            return
        }

        if !session.isRunning {
            session.startRunning()
        }
        DispatchQueue.main.async {
            self.isSessionRunning = self.session.isRunning
            self.lastError = nil
        }
    }

    private func reconfigureInput(position: AVCaptureDevice.Position, commitConfiguration: Bool = true) {
        guard let device = cameraDevice(position: position) else {
            publishError(position == .front ? "Front camera is unavailable." : "Back camera is unavailable.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if commitConfiguration {
                session.beginConfiguration()
            }
            if let currentInput {
                session.removeInput(currentInput)
            }
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                DispatchQueue.main.async {
                    self.activePosition = position
                    self.lastError = nil
                }
            } else {
                publishError("Phone camera input cannot be added.")
            }
            if commitConfiguration {
                session.commitConfiguration()
            }
        } catch {
            publishError(error.localizedDescription)
            if commitConfiguration {
                session.commitConfiguration()
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
