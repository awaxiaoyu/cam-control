import CoreGraphics
import Foundation

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
        return LiveViewFrame(jpegData: jpeg)
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

public enum CanonLiveViewParser {
    public static func parse(data: Data) -> LiveViewFrame? {
        var reader = PTPDataReader(data)
        var jpeg: Data?
        var histogram: Data?

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
            default:
                continue
            }
        }

        if let jpeg, !jpeg.isEmpty {
            return LiveViewFrame(jpegData: jpeg, histogram: histogram)
        }
        return NikonLiveViewParser.parseByJPEGScan(data)
    }
}

private extension PTPDataReader {
    mutating func readUInt16BECompat() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }
}
