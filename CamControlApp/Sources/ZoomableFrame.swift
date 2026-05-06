import SwiftUI

struct ZoomableFrame<Content: View>: View {
    let minScale: CGFloat
    let maxScale: CGFloat
    let onTapNormalized: ((CGPoint) -> Void)?
    private let content: Content

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    init(
        minScale: CGFloat = 1,
        maxScale: CGFloat = 5,
        onTapNormalized: ((CGPoint) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.onTapNormalized = onTapNormalized
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                content
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .offset(offset)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(magnificationGesture(in: size))
            .simultaneousGesture(dragGesture(in: size))
            .simultaneousGesture(tapGesture(in: size))
            .overlay(alignment: .topTrailing) {
                if scale > minScale + 0.01 {
                    Button {
                        reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(8)
                }
            }
        }
    }

    private func magnificationGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let nextScale = clampedScale(baseScale * value)
                scale = nextScale
                offset = clampedOffset(baseOffset, in: size, scale: nextScale)
            }
            .onEnded { value in
                let nextScale = clampedScale(baseScale * value)
                scale = nextScale
                offset = clampedOffset(offset, in: size, scale: nextScale)
                baseScale = nextScale
                baseOffset = offset
            }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard scale > minScale + 0.01 else {
                    offset = .zero
                    return
                }
                let proposed = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, in: size, scale: scale)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, in: size, scale: scale)
                baseOffset = offset
            }
    }

    private func tapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                onTapNormalized?(normalizedPoint(for: value.location, in: size))
            }
    }

    private func normalizedPoint(for location: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let unscaledX = (location.x - center.x - offset.width) / scale + center.x
        let unscaledY = (location.y - center.y - offset.height) / scale + center.y
        return CGPoint(
            x: min(1, max(0, unscaledX / size.width)),
            y: min(1, max(0, unscaledY / size.height))
        )
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale), maxScale)
    }

    private func clampedOffset(_ proposed: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        guard scale > minScale + 0.01 else { return .zero }
        let maxX = max(0, size.width * (scale - 1) / 2)
        let maxY = max(0, size.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func reset() {
        withAnimation(.snappy(duration: 0.2)) {
            scale = minScale
            baseScale = minScale
            offset = .zero
            baseOffset = .zero
        }
    }
}
