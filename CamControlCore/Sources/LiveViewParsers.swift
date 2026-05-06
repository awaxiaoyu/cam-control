import CoreGraphics
import Foundation
import ImageIO

public enum NikonLiveViewParser {
    public static func parse(data: Data, productID: UInt16) -> LiveViewFrame? {
        guard data.count > 128 else { return parseByJPEGScan(data) }
        let offset = pictureOffset(productID: productID)
        if let offset, data.count > offset + 4 {
            let frame = parseKnownLayout(data: data, pictureOffset: offset)
            if frame != nil { return frame }
        }
        return parseByJPEGScan(data)
    }

    private static func parseKnownLayout(data: Data, pictureOffset: Int) -> LiveViewFrame? {
        var reader = PTPDataReader(data)
        guard let jpegWidth = try? reader.readUInt16BECompat(),
              let jpegHeight = try? reader.readUInt16BECompat(),
              let wholeWidth = try? reader.readUInt16BECompat(),
              let wholeHeight = try? reader.readUInt16BECompat(),
              jpegWidth > 0,
              jpegHeight > 0,
              wholeWidth > 0,
              wholeHeight > 0 else {
            return parseByJPEGScan(data)
        }

        var afReader = PTPDataReader(data)
        try? afReader.skip(16)
        let frameWidth = (try? afReader.readUInt16BECompat()) ?? 0
        let frameHeight = (try? afReader.readUInt16BECompat()) ?? 0
        let centerX = (try? afReader.readUInt16BECompat()) ?? 0
        let centerY = (try? afReader.readUInt16BECompat()) ?? 0
        guard pictureOffset < data.count else { return parseByJPEGScan(data) }
        let jpegCandidate = data.subdata(in: pictureOffset..<data.count)
        guard let jpeg = extractJPEG(from: jpegCandidate) else { return parseByJPEGScan(data) }

        let scaleX = CGFloat(jpegWidth) / CGFloat(wholeWidth)
        let scaleY = CGFloat(jpegHeight) / CGFloat(wholeHeight)
        let afSize = CGSize(width: CGFloat(frameWidth) * scaleX, height: CGFloat(frameHeight) * scaleY)
        let afCenter = CGPoint(x: CGFloat(centerX) * scaleX, y: CGFloat(centerY) * scaleY)
        let afRect = CGRect(
            x: afCenter.x - afSize.width / 2,
            y: afCenter.y - afSize.height / 2,
            width: afSize.width,
            height: afSize.height
        )
        return LiveViewFrame(
            jpegData: jpeg,
            histogram: LiveViewHistogram.makeLuminanceHistogram(fromJPEG: jpeg),
            autofocusFrame: afRect,
            wholeSize: CGSize(width: CGFloat(wholeWidth), height: CGFloat(wholeHeight)),
            autofocusFrameSize: afSize
        )
    }

    private static func pictureOffset(productID: UInt16) -> Int? {
        switch productID {
        case PTP.NikonProduct.d5000, PTP.NikonProduct.d3s, PTP.NikonProduct.d90:
            return 128
        case PTP.NikonProduct.d3x, PTP.NikonProduct.d300s, PTP.NikonProduct.d3, PTP.NikonProduct.d300, PTP.NikonProduct.d700:
            return 64
        case PTP.NikonProduct.d7000, PTP.NikonProduct.d5100:
            return 384
        default:
            return nil
        }
    }

    public static func parseByJPEGScan(_ data: Data) -> LiveViewFrame? {
        guard let jpeg = extractJPEG(from: data) else { return nil }
        return LiveViewFrame(jpegData: jpeg, histogram: LiveViewHistogram.makeLuminanceHistogram(fromJPEG: jpeg))
    }

    public static func extractJPEG(from data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return nil }
        var start: Int?
        var index = 0
        while index + 1 < bytes.count {
            if bytes[index] == 0xff, bytes[index + 1] == 0xd8 {
                start = index
                break
            }
            index += 1
        }
        guard let jpegStart = start else { return nil }
        index = jpegStart + 2
        while index + 1 < bytes.count {
            if bytes[index] == 0xff, bytes[index + 1] == 0xd9 {
                return data.subdata(in: jpegStart..<(index + 2))
            }
            index += 1
        }
        return data.subdata(in: jpegStart..<data.count)
    }
}

public enum LiveViewHistogram {
    public static func makeLuminanceHistogram(fromJPEG data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return makeLuminanceHistogram(from: image)
    }

    public static func normalize(_ bins: [UInt32]) -> Data {
        guard let maximum = bins.max(), maximum > 0 else {
            return Data(repeating: 0, count: 256)
        }
        var output = Data()
        output.reserveCapacity(256)
        for value in bins.prefix(256) {
            output.append(UInt8(min(255, (value * 255) / maximum)))
        }
        if output.count < 256 {
            output.append(contentsOf: repeatElement(UInt8(0), count: 256 - output.count))
        }
        return output
    }

    private static func makeLuminanceHistogram(from image: CGImage) -> Data? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }

        var bins = [UInt32](repeating: 0, count: 256)
        var index = 0
        while index + 2 < pixels.count {
            let r = UInt32(pixels[index])
            let g = UInt32(pixels[index + 1])
            let b = UInt32(pixels[index + 2])
            let luminance = Int((77 * r + 150 * g + 29 * b) >> 8)
            bins[luminance] += 1
            index += bytesPerPixel
        }
        return normalize(bins)
    }
}

public enum CanonLiveViewParser {
    public static func parse(data: Data) -> LiveViewFrame? {
        var reader = PTPDataReader(data)
        var jpeg: Data?
        var histogram: Data?
        var zoomFactor: UInt32?
        var zoomRectLeft: UInt32?
        var zoomRectTop: UInt32?
        var zoomRectRight: UInt32?
        var zoomRectBottom: UInt32?

        while reader.remainingCount >= 8 {
            guard let subLength = try? reader.readUInt32LE(), let type = try? reader.readUInt32LE(), subLength >= 8 else {
                break
            }
            let payloadLength = Int(subLength) - 8
            guard payloadLength <= reader.remainingCount else { break }
            let payload = (try? reader.readData(count: payloadLength)) ?? Data()
            switch type {
            case 0x01:
                jpeg = NikonLiveViewParser.extractJPEG(from: payload) ?? payload
            case 0x03:
                histogram = payload
            case 0x04:
                var payloadReader = PTPDataReader(payload)
                zoomFactor = try? payloadReader.readUInt32LE()
            case 0x05:
                var payloadReader = PTPDataReader(payload)
                zoomRectRight = try? payloadReader.readUInt32LE()
                zoomRectBottom = try? payloadReader.readUInt32LE()
            case 0x06:
                var payloadReader = PTPDataReader(payload)
                zoomRectLeft = try? payloadReader.readUInt32LE()
                zoomRectTop = try? payloadReader.readUInt32LE()
            default:
                continue
            }
        }

        if let jpeg, !jpeg.isEmpty {
            return LiveViewFrame(
                jpegData: jpeg,
                histogram: histogram,
                zoomFactor: zoomFactor,
                zoomRect: makeZoomRect(left: zoomRectLeft, top: zoomRectTop, right: zoomRectRight, bottom: zoomRectBottom)
            )
        }
        return NikonLiveViewParser.parseByJPEGScan(data)
    }

    private static func makeZoomRect(left: UInt32?, top: UInt32?, right: UInt32?, bottom: UInt32?) -> CGRect? {
        guard let left, let top, let right, let bottom else { return nil }
        let width = right > left ? right - left : right
        let height = bottom > top ? bottom - top : bottom
        return CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(width), height: CGFloat(height))
    }
}

private extension PTPDataReader {
    mutating func readUInt16BECompat() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }
}
