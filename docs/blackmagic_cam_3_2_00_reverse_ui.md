# Blackmagic Cam 3.2.00 UI Reverse Map

Source IPA: `F:\Blackmagic Cam_3.2.00.ipa`
SHA256: `3e6721ce0673432ea4fb21bf7556b0433f2d0f22e3cb6170c1117b8d487e7c28`
App bundle: `com.blackmagic-design.DaVinciCamera`, version `3.2.00`, build `3.2.000045`.

## Evidence files

- `artifacts/blackmagic_reverse_F_3_2_00/reverse_report.md`: Info.plist, resource inventory, framework list, UI string categories.
- `artifacts/blackmagic_reverse_F_3_2_00/ui_spec.md`: hard UI facts and implementation targets.
- `artifacts/reverse-blackmagic-3.2.00-current/asset_ui_names_unique.txt`: UI asset names recovered from `CameraAppToolbox.framework/Assets.car`.
- `artifacts/blackmagic_reverse_F_3_2_00/appintents_summary.json`: AppIntents navigation/control command surface.
- `artifacts/blackmagic_reverse_F_3_2_00/extract/Payload/BlackmagicCam.app/Frameworks/CameraAppToolbox.framework/en.lproj/Localizable.strings`: UTF-16 localization comments and labels.

## Hard UI anchors

- Main pages: `Camera`, `Media`, `Chat`, `Settings`, plus camera slate overlay from `SlateView` symbols.
- Main layout symbols: `MainUIView`, `MainUIViewController`, `MainViewLayoutData`, `pageTabWidth`, `pageTabHeight`, `footerHeight`, `navMenuEdgePadding`, `leftNavMenuSwipeWidthArea`, `rightNavMenuSwipeWidthArea`.
- Camera HUD families: `HUDCameraControls`, `PHUDCameraControls`, `PLHUDCameraControls`, `SHUDCameraControls`, `HUDTopLeftIndicators`, `HUDTopIndicators`, `HUDTrailingIndicators`, `HUDLeadingIndicators`, `RecordTimerTextIndicator`, `RecordButton`, `HUDTallyIndicator`.
- Footer/control families: `LHUDFooterElements`, `PHUDFooterElements`, `PLHUDFooterElements`, `BmdAdjustmentDial`, `BmdAdjustmentDialMarker`, `BmdAdjustmentDialAutoButton`, `BmdDialVDivider`, `BmdDialHDivider`.
- Monitor families: `HUDGuides`, `HUDSafeAreas`, `HUDHistogramPopUpView`, `HUDAudioLevelPopUpView`, `StorageStatusHUD`, `UploadStatusHUD`, `HUDWhiteBalanceOverlay`, `HUDFalseColor`.
- Panel families: `MediaView`, `MediaViewSidebar`, `MediaViewToolbar`, `MediaViewUploadToolbar`, `MediaClipDetailsLandscapePanel`, `ChatView`, `ChatViewSidebar`, `ChatViewToolbar`, `SettingsCategoryPanel`, `SettingsOptionsPanel`, `OptionListView`, `SlateViewProjectInfo`, `SlateViewClipInfo`, `SlateViewLensInfo`.

## Fonts

`Info.plist` registers all BMD Lato fonts. Internal PostScript names verified with `fontTools`:

- `Lato-Regular`
- `Lato-Bold`
- `Lato-Heavy`
- `Lato-Light`
- `Lato-Timecode-Heavy`
- `Lato-WP`
- `Lato-WPAC`

Implementation uses these through `BlackmagicCamStyle.labelFont`, `readoutFont`, and `timecodeFont`.

## Asset mapping

Recovered real assets are in `CameraAppToolbox.framework/Assets.car`; current implementation packages them as `CamControlApp/Resources/BlackmagicAssets.bundle/Assets.car` and loads via `UIImage(named:in:)`.

Primary mapped assets:

- Page/control: `Camera`, `Camera_active`, `Media`, `Media_active`, `Media_disabled`, `Cloud`, `ControlIcon`, `ControlIconNotConnected`, `Slate`, `Slate_active`.
- Record: `Record`, `Record_active`, `Record_disabled`, `RecordOffSpeed`.
- HUD toggles: `IconAe`, `IconAf`, `IconAwb`, `IconLock`, `IconLut`, `IconStream`, `IconTimelapse` and `_active` variants.
- Monitor/status: `BatteryIndicator`, `BatteryIndicatorWarning`, `StorageIphone`, `StorageDrive`, `FalseColor`, `FalseColorLegend`, `Focus`, `FocusAssist`, `Grids`, `Guides`, `Zebra`, `UploadToCloud`, `UploadedToCloud`.
- HDMI/clean feed: `HdmiRecord`, `HdmiPlay`, `HdmiHistogramRgb`, `HdmiStorageIphone`, `HdmiStorageDrive`, `HdmiFalseColorLegend`, `HudStream`.

`Chat` and `Settings` glyph asset names are not present in the recovered 3.2.00 asset catalog; implementation keeps the page names from AppIntents and uses recovered `Cloud` and `ControlIcon` glyphs for those tabs.

## AppIntents command surface

The 3.2.00 metadata exposes these direct camera commands and should drive the visible quick controls:

- `OpenCameraView`: `Navigate to the ${viewType} View`
- `StartRecordIntent`, `StopRecordIntent`, `LockedCaptureIntent`
- `SetLensIntent`, `SetFrameRateIntent`, `SetShutterSpeedIntent`, `SetISOIntent`, `SetWhiteBalanceIntent`, `TintIntent`, `ExposureIntent`, `FocusIntent`, `ZoomIntent`, `StabilizationIntent`
- `CodecIntent`, `SetResolutionIntent`, `SetProjectIntent`

## Localization-derived visible labels

Camera HUD short labels are constrained by comments:

- `LENS` limit 4 chars
- `FPS` limit 2 chars
- `SHUTTER` limit 3 chars
- `IRIS` limit 4 chars
- `ISO` limit 2 chars
- `WB` limit 4 chars
- `TINT` limit 3 chars

Settings categories from localization:

- `Record`, `Camera`, `Monitor`, `Audio`, `LUTs`, `Media`, `Blackmagic Cloud`, `HDMI Out`, `Presets`, `Accessories`, `About`

Slate fields from localization:

- Project: `PRODUCTION NAME`, `DIRECTOR`, `CAMERA`, `CAMERA OPERATOR`
- Clip/lens: `SLATE FOR`, `SCENE`, `TAKE`, `REEL`, `LENS DATA`, `Good Take Last Clip`, `Interior`, `Exterior`, `Day`, `Night`, `Next Clip`

## Current implementation requirements

- Keep page rail on the right edge for camera and non-camera pages.
- Reserve `pageTabWidth` on non-camera panels so content is not hidden under the root rail.
- Keep camera screen full black/preview-first; no iOS grouped list styling on `Media`, `Chat`, or `Settings`.
- Load real BMD assets from `BlackmagicAssets.bundle` before falling back to SF Symbols.
- Keep update comments beside every reverse-derived feature so future IPA/game-version-style UI updates rerun `scripts/reverse_blackmagic_ipa.py`, refresh asset lists, then adjust mappings without rewriting layout from scratch.
