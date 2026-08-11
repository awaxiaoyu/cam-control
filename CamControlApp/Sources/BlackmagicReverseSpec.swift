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

    static let layoutComponentNames = [
        "MainUIView", "MainUIViewController", "BmdTabView", "BmdVTabView", "SinglePanelBackground",
        "DualPanelBackground", "SingleDualPanelBackground", "BmdAdjustmentDial", "BmdPopover",
        "BmdIndicatorIconButton", "BmdTextButton", "MainControlRecordTimer", "LHUDFooterElements",
        "PHUDFooterElements", "PLHUDFooterElements", "SHUDFooterElements", "PHUDSidebarOptions",
        "PSHUDSidebarOptions", "HUDTallyIndicator", "HUDTimelapseIndicator", "HUDFullscreenItems",
        "HUDSafeAreas", "StorageStatusHUD", "UploadStatusHUD", "HUDHistogramPopUp", "HUDPresetPopUp",
        "LutScrollPanel", "MainControlsPersistenceController"
    ]

    static let pageComponentNames = [
        "pageCamera", "pageMedia", "pageChat", "pageSettings", "MediaTab", "MediaViewSidebar",
        "MediaSortPanel", "MediaUploadToCloudPanel", "MediaClipDetailsLandscapePanel", "MediaClipDetailsPortraitPanel",
        "ChatViewSidebar", "ChatTableView", "BmdCloudWebPage", "SettingsCategoryPanel", "SettingsOptionsPanel",
        "RemoteSettingsCategoryPanel", "RemoteSettingsOptionsPanel", "OptionListView", "OptionStringListView",
        "SlateView", "LSlateView", "PSlateView", "SlateViewProjectInfo", "SlateViewClipInfo", "SlateViewLensInfo"
    ]

    static let settingsCategories = [
        "Record", "Camera", "Monitor", "Audio", "LUTs", "Media", "Blackmagic Cloud", "HDMI Out", "Presets", "Accessories", "About"
    ]

    static let monitorOptions = [
        "Display Audio Meters", "Display Battery Indicator", "Display Histogram", "Display Storage Status",
        "Display Upload Status", "Focus Assist", "Focus Assist Color", "Guides Color", "Guides Opacity", "HDMI Out"
    ]

    static let recordOptions = [
        "Capture 1 Frame Every", "Codec", "Color Space", "If Media Drops Frame", "Resolution", "Timecode Display", "Timelapse Recording"
    ]

    static let recordCodecOptions = ["Apple ProRes 422", "Apple ProRes 422 HQ", "Apple ProRes 422 LT", "Apple ProRes 422 Proxy", "H.264", "HEVC (H.265)"]
    static let recordResolutionOptions = ["4K", "720p", "HD"]
    static let recordTimecodeOptions = ["Record Run", "Tentacle Sync", "Time of Day (TOD)"]

    static let cameraOptions = [
        "Anamorphic De-Squeeze", "Enable Vertical Video", "Flicker Free Shutter Based On", "Flip Image for SLR Lens",
        "Lens Correction", "Lock Current Orientation", "Lock White Balance on Record", "Mirror Front-Facing Camera",
        "Shutter Measurement", "Trigger Record Indicator", "Use Volume Button to Trigger Record"
    ]

    static let hudControlLabels = ["LENS", "FPS", "SHUTTER", "IRIS", "ISO", "WB", "TINT"]
    static let lutColorSpaces = ["Rec.709", "Rec.2020", "P3 D65", "Apple Log", "Apple Log 2"]
    static let lutNames = ["Rec 709 Neutral", "Cinema Teal", "Day Night", "Dusty", "Monochrome", "Nature", "Nostalgic", "Paloma", "Rift", "Vivid", "Warm Fade"]
    static let audioLabels = ["Audio Format", "Audio Metering", "Audio Source", "iPhone Microphone", "Record Audio as", "Sample Rate", "AUDIO GAIN"]
    static let mediaOptions = ["Auto Upload To Selected Project", "Enable Upload Only Over Wi-Fi", "Filename Convention", "Save Clips to", "Save Location Data to Clip", "Upload Clips"]
    static let cloudOptions = ["Available Cloud Projects", "Log in to Blackmagic Cloud"]
    static let mediaSortOptions = ["Sort By", "Clip Name", "Date Time", "Location", "Scene, Shot", "Timecode", "Upload Status"]
    static let mediaClipInfoLabels = ["Original Video", "Proxy", "Color Space", "Created", "File Size", "Frame Rate", "Iris", "ISO", "Lens Data", "Location", "Notes", "Reel", "Resolution", "Scene", "Shutter", "Take", "Tint", "WB"]
    static let hdmiOutOptions = ["Clean Feed", "Mirror Display", "Status Text", "Status Text Surrounds Image"]
    static let presetOptions = ["Preset Selection", "Sync Presets to Cloud Project", "Export Preset", "Import Preset", "Save New Preset"]
    static let accessoriesOptions = ["Nucleus Wireless Lens Control", "Use Bluetooth"]
    static let aboutOptions = ["App Version", "Learn More at Blackmagicdesign.com"]
    static let slateProjectFields = ["PRODUCTION NAME", "DIRECTOR", "CAMERA", "CAMERA OPERATOR"]
    static let slateClipFields = ["SLATE FOR", "SCENE", "TAKE", "REEL", "LENS DATA", "Good Take Last Clip", "Interior", "Exterior", "Day", "Night", "Next Clip"]
    static let slateFields = slateProjectFields + slateClipFields

    static let hudAssetNames = [
        "Camera", "Camera_active", "Chat", "Chat_active", "Settings", "Settings_active", "Record", "Record_active", "Record_disabled", "RecordOffSpeed",
        "IconAe", "IconAe_active", "IconAf", "IconAf_active", "IconAwb", "IconAwb_active",
        "IconLock", "IconLock_active", "IconLut", "IconLut_active", "IconStream", "IconStream_active", "IconTimelapse", "IconTimelapse_active",
        "BatteryIndicator", "BatteryIndicatorWarning", "StorageIphone", "StorageDrive",
        "Exposure", "Exposure_active", "Lens", "Lens_active", "FalseColor", "FalseColorLegend", "Focus", "FocusAssist", "Grids", "Guides", "Zebra",
        "Lut", "LutDisplay", "LutRecord", "LutSelector", "LutSelector_active",
        "Media", "Media_active", "UploadToCloud", "UploadToCloud_active", "Uploading", "UploadingDone",
        "Cloud", "BmdCloudLogo", "BmdCloudSidebar", "Slate", "Slate_active", "CameraLinkedSlate",
        "HdmiRecord", "HdmiRecord_active", "HdmiPlay", "HdmiPlay_active", "HdmiHistogramRgb",
        "HdmiStorageIphone", "HdmiStorageDrive", "HdmiFalseColorLegend", "HudStream"
    ]

    static let assetFallbackSystemImages: [String: String] = [
        "Camera": "camera.fill",
        "Camera_active": "camera.fill",
        "Chat": "ellipsis.message.fill",
        "Settings": "slider.horizontal.3",
        "Record": "record.circle",
        "Record_active": "record.circle.fill",
        "IconAe": "a.circle",
        "IconAf": "scope",
        "IconAwb": "sun.max.fill",
        "IconLock": "lock.fill",
        "IconLut": "camera.filters",
        "IconStream": "dot.radiowaves.left.and.right",
        "IconTimelapse": "timer",
        "Exposure": "plusminus.circle",
        "Lens": "camera.aperture",
        "BatteryIndicator": "battery.75percent",
        "StorageIphone": "iphone",
        "StorageDrive": "externaldrive.fill",
        "FalseColor": "circle.lefthalf.filled",
        "FalseColorLegend": "circle.lefthalf.filled",
        "Focus": "scope",
        "FocusAssist": "scope",
        "Grids": "square.grid.3x3",
        "Guides": "rectangle.dashed",
        "Zebra": "line.diagonal",
        "Lut": "camera.filters",
        "Media": "photo.on.rectangle",
        "UploadToCloud": "arrow.up.circle.fill",
        "Cloud": "cloud.fill",
        "Slate": "rectangle.and.pencil.and.ellipsis",
        "HdmiRecord": "record.circle",
        "HdmiPlay": "play.fill",
        "HdmiHistogramRgb": "waveform.path.ecg",
        "HudStream": "film.stack"
    ]
}
