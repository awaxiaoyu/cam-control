import Foundation

/// Reverse-derived UI anchors from `the repo-local Blackmagic Cam_3.2.00.ipa`.
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
        "FocusAdjustmentDial", "FocusAssistScroller", "LensOptions", "IsoPresetOptions", "ShutterPresetOptions",
        "WhiteBalancePresetOptions", "ZoomPresetOptions", "NDFilterOptions", "StabilisationOptions", "StabilizationIntent", "LutScroller", "ZebraScroller", "FramingGuidesScroller",
        "SafeAreaScroller", "FocusAssistScroller"
    ]

    static let layoutComponentNames = [
        "MainUIView", "MainUIViewController", "BmdTabView", "BmdVTabView", "SinglePanelBackground",
        "DualPanelBackground", "SingleDualPanelBackground", "BmdAdjustmentDial", "BmdPopover",
        "BmdIndicatorIconButton", "BmdTextButton", "BmdTextListSelector", "BmdPopover", "MainControlRecordTimer", "LHUDFooterElements",
        "PHUDFooterElements", "PLHUDFooterElements", "SHUDFooterElements", "PHUDSidebarOptions",
        "PSHUDSidebarOptions", "HUDTallyIndicator", "HUDTimelapseIndicator", "HUDFullscreenItems",
        "HUDSafeAreas", "StorageStatusHUD", "UploadStatusHUD", "HUDHistogramPopUp", "HUDPresetPopUp",
        "LutScrollPanel", "LutNamesLandscapePanel", "LutNamesPortraitPanel", "AudioMeterMini", "HUDCameraLightIndicator", "RemoteClipSyncStatusFooterView", "TimecodeSettingsView", "MainControlsPersistenceController"
    ]

    static let pageComponentNames = [
        "pageCamera", "pageMedia", "pageChat", "pageSettings", "MediaTab", "MediaViewSidebar",
        "MediaSortPanel", "MediaUploadToCloudPanel", "MediaClipDetailsLandscapePanel", "MediaClipDetailsPortraitPanel",
        "ChatViewSidebar", "ChatTableView", "BmdCloudWebPage", "SettingsCategoryPanel", "SettingsOptionsPanel",
        "RemoteSettingsCategoryPanel", "RemoteSettingsOptionsPanel", "OptionListView", "OptionStringListView",
        "SlateView", "LSlateView", "PSlateView", "SlateViewProjectInfo", "SlateViewClipInfo", "SlateViewLensInfo"
    ]

    static let settingsCategories = [
        "Record", "Camera", "Monitor", "Audio", "LUTs", "Media", "Blackmagic Cloud", "HDMI Out", "Presets", "Accessories", "About", "Reset"
    ]
    static let portraitSettingsTitle = "Settings"

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
    static let ndFilterOptions = ["Clear", "1 Stop", "2 Stops", "3 Stops", "4 Stops", "ND 0.3", "ND 0.6", "ND 0.9", "ND 1.2"]

    static let cameraOptions = [
        "Anamorphic De-Squeeze", "Enable Vertical Video", "Flicker Free Shutter Based On", "Flip Image for SLR Lens",
        "Lens Correction", "Lock Current Orientation", "Lock White Balance on Record", "Mirror Front-Facing Camera",
        "Shutter Measurement", "Trigger Record Indicator", "Use Volume Button to Trigger Record"
    ]

    static let hudControlLabels = ["LENS", "FPS", "SHUTTER", "IRIS", "ISO", "WB", "TINT"]
    static let lutColorSpaces = ["Rec.709", "Rec.2020", "P3 D65", "Apple Log", "Apple Log 2"]
    static let lutNames = ["Rec 709 Neutral", "Cinema Teal", "Day Night", "Dusty", "Monochrome", "Nature", "Nostalgic", "Paloma", "Rift", "Vivid", "Warm Fade"]
    static let audioLabels = ["Audio Format", "Audio Metering", "Audio Source", "iPhone Microphone", "Record Audio as", "Sample Rate"]
    static let audioHudLabels = audioLabels + ["AUDIO GAIN"]
    static let mediaOptions = ["Auto Upload To Selected Project", "Enable Upload Only Over Wi-Fi", "Filename Convention", "Save Clips to", "Save Location Data to Clip", "Upload Clips"]
    static let cloudOptions = ["Available Cloud Projects", "Log in to Blackmagic Cloud"]
    static let mediaSortOptions = ["Sort By", "Clip Name", "Date Time", "Location", "Scene, Shot", "Timecode", "Upload Status"]
    static let mediaClipInfoLabels = ["Original Video", "Proxy", "Color Space", "Created", "File Size", "Frame Rate", "Iris", "ISO", "Lens Data", "Location", "Notes", "Reel", "Resolution", "Scene", "Shutter", "Take", "Tint", "WB"]
    static let hdmiOutOptions = ["Clean Feed", "Mirror Display", "Status Text", "Status Text Surrounds Image"]
    static let presetOptions = ["Preset Selection", "Sync Presets to Cloud Project"]
    static let presetSelectionOptions = ["Export Preset", "Import Preset", "Save New Preset"]
    static let accessoriesOptions = ["Nucleus Wireless Lens Control", "Use Bluetooth"]
    static let aboutOptions = ["App Version", "Learn More at Blackmagicdesign.com"]
    static let resetOptions = ["Reset Blackmagic Cam Settings"]
    static let resetChoices = ["Reset Camera Settings", "Reset Camera and Cloud Settings", "Reset All Settings and Erase All Content"]
    static let resetDialogBodies = [
        "This will revert all settings to default.",
        "This will revert all camera and cloud settings to default.",
        "This will revert all camera and cloud settings to default and erase all clips, presets and LUTS stored on this iphone. This cannot be undone."
    ]

    static let settingsOptionChoices: [String: [String]] = [
        "Capture 1 Frame Every": ["1 Second", "%d Seconds", "1 Minute", "%d Minutes", "%d Frames"],
        "Codec": recordCodecOptions,
        "If Media Drops Frame": ["Alert ", "Stop Recording"],
        "Resolution": recordResolutionOptions,
        "Timecode Display": recordTimecodeOptions,
        "Audio Format": ["AAC", "IEEE Float", "Linear PCM"],
        "Audio Metering": ["PPM (-18dBFS)", "PPM (-20dBFS)", "VU (-18dBFS)", "VU (-20dBFS)"],
        "Audio Source": ["iPhone Microphone", "None"],
        "iPhone Microphone": ["Auto"],
        "Record Audio as": ["Mono", "Stereo", "Dual Mono", "4 Channels"],
        "Sample Rate": ["Auto", "44.1 kHz", "48.0 kHz", "96.0 kHz", "192.0 kHz"],
        "Shutter Measurement": ["Speed", "Angle"],
        "Trigger Record Indicator": ["None", "Beeper", "Beeper and Flash"],
        "Anamorphic De-Squeeze": ["None"],
        "Focus Assist": ["Colored Lines", "Peaking"],
        "Focus Assist Color": ["Blue", "Red", "Green", "White", "Black"],
        "Filename Convention": ["Blackmagic Camera", "iOS"],
        "Save Clips to": ["In-App Only", "In-App and Photo Library", "Files"],
        "Upload Clips": ["Proxies Only", "Originals and Proxies"],
        "Preset Selection": presetSelectionOptions,
        "LUT Selection": ["Import LUT"] + lutNames,
        "Reset Blackmagic Cam Settings": resetChoices
    ]
    static let slateProjectFields = ["PRODUCTION NAME", "DIRECTOR", "CAMERA", "CAMERA OPERATOR"]
    static let slateClipFields = ["SLATE FOR", "SCENE", "TAKE", "REEL", "LENS DATA", "Good Take Last Clip", "Interior", "Exterior", "Day", "Night", "Next Clip"]
    static let slateFields = slateProjectFields + slateClipFields

    static let hudAssetNames = [
        "Camera", "Camera_active", "Media", "Media_active", "Media_disabled", "Cloud", "BmdCloudSidebar", "ControlIcon", "ControlIconNotConnected", "Record", "Record_active", "Record_disabled", "RecordOffSpeed",
        "Apple Watch/IconAe", "Apple Watch/IconAe_active", "Apple Watch/IconAf", "Apple Watch/IconAf_active", "Apple Watch/IconAwb", "Apple Watch/IconAwb_active",
        "Apple Watch/IconLock", "Apple Watch/IconLock_active", "Apple Watch/IconLut", "Apple Watch/IconLut_active", "Apple Watch/IconStream", "Apple Watch/IconStream_active", "Apple Watch/IconTimelapse", "Apple Watch/IconTimelapse_active",
        "BatteryIndicator", "BatteryIndicatorWarning", "StorageIphone", "StorageDrive",
        "Exposure", "Exposure_active", "ExposureAutoZoom", "ExposureAutoZoom_active", "ExposureLockZoom", "ExposureLockZoom_active", "FocusAutoZoom", "FocusAutoZoom_active", "HdmiNdClear", "HdmiNdFrac1", "HdmiNdFrac2", "HdmiNdFrac3", "HdmiNdFrac4", "HdmiNdStop1", "HdmiNdStop2", "HdmiNdStop3", "HdmiNdStop4", "FalseColor", "FalseColorLegend", "Focus", "FocusAssist", "Grids", "Guides", "Zebra",
        "Lut", "LutDisplay", "LutRecord", "LutSelector", "LutSelector_active",
        "Media", "Media_active", "MediaSync", "MediaSync_active", "MediaSync_disabled", "Sort", "Sort_active", "SortDatetime", "SortFilename", "SortLocation", "SortTimecode", "SortUploadStatus", "UploadToCloud", "UploadToCloud_active", "UploadToCloud_disabled", "UploadedToCloud", "UploadedToCloudHq", "UploadedToCloudPxy", "Uploading", "UploadingSmall", "UploadingPause", "UploadingDone", "UploadingFailedThumbnail", "ProjectUpload", "ProjectUploadFailed", "ProjectUploadNoConnection", "Sync", "Sync_active", "SyncFooter", "SyncSidebar",
        "Cloud", "BmdCloudLogo", "BmdCloudSidebar", "Slate", "Slate_active", "CameraLinkedSlate", "CameraLinkedSmall",
        "HdmiRecord", "HdmiRecord_active", "HdmiPlay", "HdmiPlay_active", "HdmiHistogramRgb",
        "Hdmi4kRecord", "Hdmi4kRecord_active", "Hdmi4kPlay", "Hdmi4kPlay_active", "Hdmi4kHistogramRgb",
        "HdmiStorageIphone", "HdmiStorageDrive", "Hdmi4kStorageIphone", "Hdmi4kStorageDrive", "HdmiFalseColorLegend", "Hdmi4kFalseColorLegend"
    ]

    static let assetAliasNotes = [
        "Chat tab glyph": "3.2.00 has pageChat symbols but no bare Chat asset; use recovered Cloud/BmdCloudSidebar glyphs.",
        "HUD auto icons": "IconAf/IconAwb/IconLock/IconLut/IconTimelapse are recovered under Apple Watch/* plus png rendition aliases.",
        "Lens footer glyph": "3.2.00 exposes LensOptions as UI symbols but no bare Lens asset; use Camera glyph while preserving LENS label.",
        "Zoom/function rail glyph": "3.2.00 screenshots show a zoom/function icon in the camera-control rail; use recovered FocusAutoZoom/ExposureAutoZoom assets because no bare Zoom asset exists in 3.2.00.",
        "ND/stabilisation rail glyphs": "3.2.00 exposes NDFilterOptions/StabilisationOptions plus HdmiNd*/ExposureLockZoom assets; keep them as secondary rail scrollers, never as footer controls."
    ]

    static let implementationRules = [
        "HUDTopLeftIndicators/HUDTopIndicators are status-only; never duplicate LENS/FPS/SHUTTER/IRIS/ISO/WB/TINT in the top overlay.",
        "LHUDFooterElements/PHUDFooterElements/PLHUDFooterElements render the seven camera controls as BmdAdjustmentDial cells.",
        "BmdVTabView pageCamera/pageMedia/pageChat/pageSettings is an icon-only right-edge rail; visible text labels are not part of the 3.2.00 page rail.",
        "Live/review/stream controls should use recovered HdmiPlay/IconTimelapse/IconStream/Media assets before SF Symbol fallback."
    ]

    static let assetFallbackSystemImages: [String: String] = [
        "Camera": "camera.fill",
        "Camera_active": "camera.fill",
        "Chat": "ellipsis.message.fill",
        "Chat_active": "ellipsis.message.fill",
        "Cloud": "cloud.fill",
        "ProjectUpload": "folder.fill",
        "Sync": "arrow.triangle.2.circlepath",
        "MediaSync": "arrow.clockwise",
        "UploadedToCloud": "checkmark.circle.fill",
        "ControlIcon": "slider.horizontal.3",
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
        "Zoom": "plus.magnifyingglass",
        "Hdmi4kPlay": "play.fill",
        "Hdmi4kRecord": "record.circle",
        "Hdmi4kHistogramRgb": "waveform.path.ecg",
        "ExposureLockZoom": "lock.circle",
        "HdmiNdClear": "circle.slash",
        "HdmiNdFrac1": "circle.dotted",
        "HdmiNdStop1": "1.circle",
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
        "Sort": "arrow.up.arrow.down",
        "Sort_active": "arrow.up.arrow.down",
        "UploadToCloud": "arrow.up.circle.fill",
        "Cloud": "cloud.fill",
        "Slate": "rectangle.and.pencil.and.ellipsis",
        "HdmiRecord": "record.circle",
        "HdmiPlay": "play.fill",
        "HdmiHistogramRgb": "waveform.path.ecg"
    ]
}
