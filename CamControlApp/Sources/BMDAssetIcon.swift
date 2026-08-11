import SwiftUI
import UIKit

/// Runtime loader for asset names recovered from Blackmagic Cam 3.2.00 `CameraAppToolbox.framework/Assets.car`.
/// Firmware/update note: update BlackmagicReverseSpec.hudAssetNames and rebuild BlackmagicAssets.bundle/Assets.car after rerunning reverse_blackmagic_ipa.py against a new IPA.
struct BMDAssetIcon: View {
    let name: String
    var activeName: String?
    var active = false
    var fallback: String? = nil
    var color: Color = .white
    var size: CGFloat = 20
    var preserveOriginalColors = false

    var body: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .renderingMode(preserveOriginalColors ? .original : .template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallback ?? BlackmagicReverseSpec.assetFallbackSystemImages[name] ?? "circle")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }

    private var loadedImage: UIImage? {
        BMDAssetImageLoader.image(name: name, activeName: activeName, active: active)
    }
}

struct BMDAssetImage: View {
    let name: String
    var activeName: String?
    var active = false
    var fallback: String? = nil
    var color: Color = .white
    var preserveOriginalColors = false

    var body: some View {
        if let image = BMDAssetImageLoader.image(name: name, activeName: activeName, active: active) {
            Image(uiImage: image)
                .renderingMode(preserveOriginalColors ? .original : .template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        } else {
            Image(systemName: fallback ?? BlackmagicReverseSpec.assetFallbackSystemImages[name] ?? "circle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        }
        // Firmware/update note: use this flexible image for non-square recovered assets such as FalseColorLegend and BmdCloudLogo; keep BMDAssetIcon for 96x96/132x132 icon slots.
    }
}

private enum BMDAssetImageLoader {
    static func image(name: String, activeName: String? = nil, active: Bool = false) -> UIImage? {
        let preferredName = active ? (activeName ?? "\(name)_active") : name
        var names: [String] = []
        for assetName in ([preferredName, name] + aliases(for: preferredName) + aliases(for: name)) where !assetName.isEmpty && !names.contains(assetName) {
            names.append(assetName)
        }
        for bundle in BMDAssetBundleStore.imageBundles {
            for assetName in names {
                if let image = UIImage(named: assetName, in: bundle, compatibleWith: nil) {
                    return image
                }
            }
        }
        for assetName in names {
            if let image = UIImage(named: assetName) {
                return image
            }
        }
        return nil
    }

    private static func aliases(for assetName: String) -> [String] {
        switch assetName {
        case "IconAf": return ["Apple Watch/IconAf", "icon_AF"]
        case "IconAf_active": return ["Apple Watch/IconAf_active", "icon_AF_active"]
        case "IconAwb": return ["Apple Watch/IconAwb", "icon_AWB"]
        case "IconAwb_active": return ["Apple Watch/IconAwb_active", "icon_AWB_active"]
        case "IconLock": return ["Apple Watch/IconLock", "icon_lock", "Lock", "LockHud"]
        case "IconLock_active": return ["Apple Watch/IconLock_active", "icon_lock_active", "Lock_active", "LockHud_active"]
        case "IconLut": return ["Apple Watch/IconLut", "icon_LUT", "Lut"]
        case "IconLut_active": return ["Apple Watch/IconLut_active", "icon_LUT_active", "Lut_active"]
        case "IconStream": return ["Apple Watch/IconStream", "icon_stream"]
        case "IconStream_active": return ["Apple Watch/IconStream_active", "icon_stream_active"]
        case "IconTimelapse": return ["Apple Watch/IconTimelapse", "icon_timelapse", "Timelapse"]
        case "IconTimelapse_active": return ["Apple Watch/IconTimelapse_active", "icon_timelapse_active"]
        case "Chat", "Chat_active": return ["Cloud", "BmdCloudSidebar"]
        case "Lens", "Lens_active": return ["Camera", "Camera_active"]
        case "Zoom", "Zoom_active": return ["Hdmi4kPlay", "HdmiPlay", "FocusAutoZoom", "ExposureAutoZoom"]
        case "HdmiHistogramRgb": return ["Hdmi4kHistogramRgb", "HDMI_4K_histogram_rgb"]
        case "HdmiNdClear": return ["Hdmi4kNdClear", "HDMI_4K_nd_clear"]
        case "HdmiNdFrac1": return ["Hdmi4kNdFrac1", "HDMI_4K_nd_frac_1"]
        case "HdmiNdFrac2": return ["Hdmi4kNdFrac2", "HDMI_4K_nd_frac_2"]
        case "HdmiNdFrac3": return ["Hdmi4kNdFrac3", "HDMI_4K_nd_frac_3"]
        case "HdmiNdFrac4": return ["Hdmi4kNdFrac4", "HDMI_4K_nd_frac_4"]
        case "HdmiNdStop1": return ["Hdmi4kNdStop1", "HDMI_4K_nd_stop_1"]
        case "HdmiNdStop2": return ["Hdmi4kNdStop2", "HDMI_4K_nd_stop_2"]
        case "HdmiNdStop3": return ["Hdmi4kNdStop3", "HDMI_4K_nd_stop_3"]
        case "HdmiNdStop4": return ["Hdmi4kNdStop4", "HDMI_4K_nd_stop_4"]
        case "HdmiPlay", "HdmiPlay_active": return ["Hdmi4kPlay", "Hdmi4kPlay_active", "HDMI_4K_play"]
        case "HdmiRecord", "HdmiRecord_active": return ["Hdmi4kRecord", "Hdmi4kRecord_active", "HDMI_4K_record"]
        case "StorageIphone": return ["Hdmi4kStorageIphone", "HDMI_4K_storage_iPhone"]
        case "StorageDrive": return ["Hdmi4kStorageDrive", "HDMI_4K_storage_drive"]
        default: return []
        }
        // Firmware/update note: aliases are reverse-derived from assetutil rendition names in CameraAppToolbox.framework/Assets.car; rerun the asset reverse workflow before changing them for a new IPA.
    }
}

private enum BMDAssetBundleStore {
    static let imageBundles: [Bundle] = {
        var bundles: [Bundle] = []
        if let url = Bundle.main.url(forResource: "BlackmagicAssets", withExtension: "bundle"), let bundle = Bundle(url: url) {
            bundles.append(bundle)
        }
        if let url = Bundle.main.url(forResource: "BlackmagicAssets", withExtension: nil), let bundle = Bundle(url: url) {
            bundles.append(bundle)
        }
        bundles.append(.main)
        return bundles
    }()
}

