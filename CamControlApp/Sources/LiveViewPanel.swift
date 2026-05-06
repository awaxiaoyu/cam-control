import CamControlCore
import SwiftUI

struct LiveViewPanel: View {
    @EnvironmentObject private var controller: CameraController

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                    if let frame = controller.liveViewFrame {
                        LiveImage(data: frame.jpegData)
                            .overlay(alignment: .topLeading) {
                                AutofocusOverlay(frame: frame)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if controller.snapshot.capabilities.histogram, let histogram = frame.histogram {
                                    HistogramOverlay(histogram: histogram)
                                        .padding(10)
                                }
                            }
                    } else {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        let x = max(0, min(1, value.location.x / max(proxy.size.width, 1)))
                        let y = max(0, min(1, value.location.y / max(proxy.size.height, 1)))
                        Task { await controller.setLiveViewAfArea(x: x, y: y) }
                    }
                )
                .aspectRatio(16 / 9, contentMode: .fit)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .padding(.horizontal)

            HStack(spacing: 10) {
                Button {
                    Task { await controller.toggleLiveView() }
                } label: {
                    Label(controller.isLiveViewActive ? "Stop" : "Live", systemImage: controller.isLiveViewActive ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controller.snapshot.capabilities.liveView)

                Button {
                    Task { await controller.focus() }
                } label: {
                    Label("AF", systemImage: "scope")
                }
                .buttonStyle(.bordered)
                .disabled(!controller.snapshot.capabilities.autofocus)

                Button {
                    Task { await controller.driveLens(direction: .near, step: .soft) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(!controller.snapshot.capabilities.driveLens)

                Button {
                    Task { await controller.driveLens(direction: .far, step: .soft) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(!controller.snapshot.capabilities.driveLens)
            }
            .padding(.bottom)
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
