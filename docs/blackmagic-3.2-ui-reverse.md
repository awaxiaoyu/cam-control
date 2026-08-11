# Blackmagic Cam 3.2.00 UI Reverse Evidence

Source: `F:\Blackmagic Cam_3.2.00.ipa`
SHA256: `3e6721ce0673432ea4fb21bf7556b0433f2d0f22e3cb6170c1117b8d487e7c28`
Bundle: `com.blackmagic-design.DaVinciCamera`
Version/build: `3.2.00 / 3.2.000045`

## Resource Evidence

- Main app is SwiftUI-first: no storyboard/nib payload; UI symbols live primarily in `CameraAppToolbox.framework/CameraAppToolbox`.
- App orientations: landscape left/right plus portrait, so the clone must be landscape-first but not landscape-only.
- UI resources recovered from IPA and copied into `CamControlApp/Resources`: `CameraAppToolbox.framework/Assets.car`, `BMD-Lato-*` fonts, LUT folder names, and localized strings.
- Assetutil confirms 452 image asset names, including `Camera`, `Media`, `Chat`, `ControlIcon`, `Record`, `FalseColor`, `FocusAssist`, `Guides`, `Zebra`, `Lut`, `BatteryIndicator`, `StorageIphone`, `UploadToCloud`, `Slate`, `Hdmi*`.

## Layout Evidence

Recovered binary strings include:

- Main shell: `MainUIView`, `MainUIViewController`, `MainView`, `CameraUIControls`.
- Navigation/page system: `BmdPagingView`, `BmdPageControl`, `CustomPageControl`, `pageCamera`, `pageMedia`, `pageChat`, `pageSettings`, `getPageTabWidthForLandscapeMode`.
- Camera HUD: `HUDCameraControls`, `LHUDFooterElements`, `PHUDFooterElements`, `PLHUDFooterElements`, `SHUDFooterElements`, `HUDTimelapseIndicator`, `HUDTallyIndicator`, `HUDSafeAreas`.
- Controls: `BmdAdjustmentDial`, `BmdAdjustmentDialDualPanel`, `BmdAdjustmentDialMarker`, `DialScroll`, `FpsOptions`, `ShutterScroll`, `IrisScroll`, `IsoScroll`, `WhiteBalanceScroll`, `TintScroll`, `LensOptions`.
- Monitor overlays: `ImageHistogram`, `AudioMeter`, `StorageStatusHUD`, `UploadStatusHUD`, `BmdZebraRegion`, `FalseColor`, `FocusAssist`, `Guides`, `LutScroller`, `ZebraScroller`, `FramingGuidesScroller`.
- Settings/media/chat: `SettingsCategoryPanel`, `SettingsOptionsPanel`, `OptionListView`, `OptionStringListView`, `MediaViewSidebar`, `MediaSortPanel`, `MediaUploadToCloudPanel`, `MediaClipDetailsLandscapePanel`, `ChatViewSidebar`, `ChatTableView`.

## Settings Hierarchy

Recovered from UTF-16LE `CameraAppToolbox.framework/en.lproj/Localizable.strings` comments:

- Record: `Capture 1 Frame Every`, `Codec`, `Color Space`, `If Media Drops Frame`, `Resolution`, `Timecode Display`, `Timelapse Recording`.
- Camera: `Anamorphic De-Squeeze`, `Enable Vertical Video`, `Flicker Free Shutter Based On`, `Flip Image for SLR Lens`, `Lens Correction`, `Lock Current Orientation`, `Lock White Balance on Record`, `Mirror Front-Facing Camera`, `Shutter Measurement`, `Trigger Record Indicator`, `Use Volume Button to Trigger Record`.
- Monitor: `Display Audio Meters`, `Display Battery Indicator`, `Display Histogram`, `Display Storage Status`, `Display Upload Status`, `Focus Assist`, `Focus Assist Color`, `Guides Color`, `Guides Opacity`, `HDMI Out`.
- Audio: `Audio Format`, `Audio Metering`, `Audio Source`, `iPhone Microphone`, `Record Audio as`, `Sample Rate`.
- LUTs: `Display LUT`, `LUT Selection`.
- Media: `Auto Upload To Selected Project`, `Enable Upload Only Over Wi-Fi`, `Filename Convention`, `Save Clips to`, `Save Location Data to Clip`, `Upload Clips`.
- Blackmagic Cloud: `Available Cloud Projects`, `Log in to Blackmagic Cloud`.
- HDMI Out: `Clean Feed`, `Mirror Display`, `Status Text`, `Status Text Surrounds Image`.
- Presets: `Preset Selection`, `Sync Presets to Cloud Project`.
- Accessories/About: `Nucleus Wireless Lens Control`, `Use Bluetooth`, `App Version`, `Learn More at Blackmagicdesign.com`.

## Implementation Rule

When Blackmagic updates the app, rerun:

```powershell
python scripts\_authoritative_reverse.py
python scripts\_parse_strings.py
python scripts\_extract_settings_comments.py
python scripts\_decode_ui_symbols.py
```

Then update `BlackmagicReverseSpec.swift` before modifying layout files.
