import SwiftUI
import UIKit

/// Runtime loader for asset names recovered from Blackmagic Cam 3.2.00 `CameraAppToolbox.framework/Assets.car`.
/// Firmware/update note: update BlackmagicReverseSpec.hudAssetNames after rerunning reverse_blackmagic_ipa.py against a new IPA; fallbacks only exist to keep dev builds visible if a copied .car asset name changes.
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
        let assetName = active ? (activeName ?? "\(name)_active") : name
        return UIImage(named: assetName) ?? UIImage(named: name)
    }
}
