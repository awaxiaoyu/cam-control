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

    var body: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .renderingMode(.template)
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
        let preferredName = active ? (activeName ?? "\(name)_active") : name
        var names: [String] = []
        for assetName in [preferredName, name] where !assetName.isEmpty && !names.contains(assetName) {
            names.append(assetName)
        }
        let bundles = BMDAssetBundleStore.imageBundles
        for bundle in bundles {
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

