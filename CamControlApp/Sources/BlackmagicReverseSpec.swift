import Foundation

/// Reverse-derived UI anchors from `F:\Blackmagic Cam_3.2.00.ipa`.
/// Firmware/update note: when Blackmagic Cam updates, rerun `scripts/reverse_blackmagic_ipa.py` and update these arrays from the new binary/resource strings before touching view layout.
enum BlackmagicReverseSpec {
    static let sourceBundle = "Blackmagic Cam 3.2.00 / com.blackmagic-design.DaVinciCamera / build 3.2.000045"

    static let hudComponentNames = [
        "HUDCameraControls", "PSHUDCameraBaseControls", "PLHUDCameraControls", "HUDTopLeftIndicators",
        "HUDTopIndicators", "HUDTrailingIndicators", "HUDLeadingIndicators", "HUDLutIndicator",
        "HUDHistogramPopUpView", "HUDAudioLevelPopUpView", "StorageStatusHUD", "UploadStatusHUD",
        "RecordButton", "RecordTimerTextIndicator", "HUDWhiteBalanceOverlay", "HUDGuides", "HUDFalseColor"
    ]

    static let controlScrollerNames = [
        "FpsOptions", "ShutterScroll", "IrisScroll", "IsoScroll", "WhiteBalanceScroll", "TintScroll",
        "FocusScroll", "FocusAdjustmentDial", "FocusTransitionOptions", "LensOptions", "NDFilterOptions",
        "ZoomScroll", "StabilisationOptions", "LutScroller", "ZebraScroller", "FramingGuidesScroller",
        "SafeAreaScroller", "FocusAssistScroller"
    ]

    static let settingsCategories = [
        "Record", "Camera", "Monitor", "Audio", "LUTs", "Media", "Blackmagic Cloud", "HDMI Out", "Preset", "Accessories", "About"
    ]

    static let monitorOptions = [
        "Display Histogram", "Display Audio Meters", "Display Storage Status", "Display Battery Indicator",
        "Display Upload Status", "Focus Assist", "Focus Assist Color", "Guides Color", "Guides Opacity", "Clean Feed"
    ]

    static let recordOptions = [
        "Codec", "Resolution", "Frame Rate", "If Media Drops Frame", "Record Audio as", "Lock White Balance on Record",
        "Trigger Record Indicator", "Use Volume Button to Trigger Record"
    ]

    static let cameraOptions = [
        "Lens", "FPS", "Shutter", "Iris", "ISO", "White Balance", "Tint", "Anamorphic De-Squeeze", "Flicker Free Shutter Based On", "Stabilization"
    ]

    static let lutColorSpaces = ["Rec.709", "Rec.2020", "P3 D65", "Apple Log", "Apple Log 2"]
    static let lutNames = ["Rec 709 Neutral", "Cinema Teal", "Day Night", "Dusty", "Monochrome", "Nature", "Nostalgic", "Paloma", "Rift", "Vivid", "Warm Fade"]
    static let audioLabels = ["AUDIO GAIN", "Audio Source", "Audio Metering", "Audio Format", "Sample Rate"]
    static let slateFields = ["SLATE FOR", "PROJECT", "SCENE", "TAKE", "REEL", "CAMERA OPERATOR", "LENS DATA", "GOOD TAKE"]
}
