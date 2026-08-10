# Blackmagic Cam 3.2.00 UI Reverse Notes

Source IPA: `F:\Blackmagic Cam_3.2.00.ipa`
Bundle: `com.blackmagic-design.DaVinciCamera`
Version: `3.2.00`, build `3.2.000045`
Minimum iOS: `17.0`

## Extraction

- Tool: `scripts/reverse_blackmagic_ipa.py`
- Local output: `artifacts/reverse/blackmagic_cam_3_2_00/`
- Mach-O: `BlackmagicCam`, arm64, `LC_ENCRYPTION_INFO_64 cryptid=0`, SwiftUI/UIKit app.
- Key embedded frameworks: `CameraAppToolbox`, `DavCloudClient`, `DavCloudClientSwift`, `DavStream`, `GStreamer`, `Tentacle`.

## UI resource evidence

The IPA registers Blackmagic's Lato family through `UIAppFonts`:

- `BMD-Lato-Bold-Italic.ttf`
- `BMD-Lato-Bold.ttf`
- `BMD-Lato-Heavy.ttf`
- `BMD-Lato-HeavyItalic.ttf`
- `BMD-Lato-Italic.ttf`
- `BMD-Lato-Light-Italic.ttf`
- `BMD-Lato-Light.ttf`
- `BMD-Lato-Regular.ttf`
- `BMD-Lato-Timecode-Heavy.ttf`
- `BMD-Lato-WP.ttf`
- `BMD-Lato-WPAC.ttf`

The IPA includes LUT resources across these families:

- `Rec.709`, `Rec.2020`, `P3 D65`, `Apple Log`, `Apple Log 2`
- `Rec 709 Neutral`, `Cinema Teal`, `Day Night`, `Dusty`, `Monochrome`, `Nature`, `Nostalgic`, `Paloma`, `Rift`, `Vivid`, `Warm Fade`

## Recovered SwiftUI component anchors

Recovered strings include the camera HUD surface and popover components used as implementation anchors:

- `HUDCameraControls`, `PSHUDCameraBaseControls`, `PHUDCameraControls`, `SHUDCameraControls`, `PLHUDCameraControls`
- `HUDTopLeftIndicators`, `HUDTopIndicators`, `HUDTrailingIndicators`, `HUDLeadingIndicators`
- `RecordButton`, `RecordTimerTextIndicator`, `HUDLutIndicator`, `HUDWhiteBalanceOverlay`
- `HUDFalseColor`, `HUDGuides`, `HUDGrids`, `HUDHistogramPopUpView`, `HUDAudioLevelPopUpView`
- `StorageStatusHUD`, `UploadStatusHUD`, `SlateView`, `LSlateView`, `PSlateView`
- `FpsOptions`, `ShutterScroll`, `IrisScroll`, `IsoScroll`, `WhiteBalanceScroll`, `TintScroll`
- `FocusScroll`, `FocusAdjustmentDial`, `FocusTransitionOptions`, `LensOptions`, `NDFilterOptions`, `ZoomScroll`
- `StabilisationOptions`, `LutScroller`, `ZebraScroller`, `FramingGuidesScroller`, `SafeAreaScroller`, `FocusAssistScroller`

## Recovered settings labels

Camera/record/monitor labels from `CameraAppToolbox.framework/en.lproj/Localizable.strings` include:

- Record: `Codec`, `Resolution`, `Frame Rate`, `If Media Drops Frame`, `Record Audio as`, `Lock White Balance on Record`, `Trigger Record Indicator`, `Use Volume Button to Trigger Record`
- Camera: `Lens`, `Focus`, `ISO`, `White Balance`, `Tint`, `Anamorphic De-Squeeze`, `Flicker Free Shutter Based On`, `Stabilization`
- Monitor: `Display Histogram`, `Display Audio Meters`, `Display Storage Status`, `Display Battery Indicator`, `Display Upload Status`, `Focus Assist`, `Focus Assist Color`, `Guides Color`, `Guides Opacity`, `Clean Feed`
- Cloud/Media: `Blackmagic Cloud`, `No project selected - All Clips`, `Chat`, `Media`, `Upload`, `Proxy uploaded`, `Uploading proxy...`
- Slate: `SLATE FOR`, `CAMERA OPERATOR`, `Lens Data`, `Scene`, `Take`, `Reel`, `Good Take`

## Implementation mapping

`ShootingHUDComponents.swift` is now rewritten as a full-screen camera HUD instead of the previous side-rail app shell:

- Full-screen preview with Blackmagic-style edge vignette.
- Top indicator groups and center timecode/tally mirror `HUDTopIndicators` and `RecordTimerTextIndicator`.
- Floating leading/trailing indicators replace fixed app sidebars and map to `HUDLeadingIndicators`/`HUDTrailingIndicators`.
- Bottom horizontal `HUDCameraControls` strip maps lens/FPS/shutter/iris/ISO/WB/tint/LUT plus live/AF/record controls.
- Bottom popover scrollers use recovered component names such as `FpsOptions`, `ShutterScroll`, `IsoScroll`, `LutScroller`, `FocusAssistScroller`, `ZebraScroller`.
- Monitor overlays include guides, false-color legend, white-balance/tint pill, histogram, audio meters and storage HUD cards.
- Slate overlay maps `SlateViewProjectInfo`, `SlateViewClipInfo`, and `SlateViewLensInfo` strings.

## Update procedure

When Blackmagic Cam ships a new IPA:

1. Replace the source IPA path.
2. Run `python scripts/reverse_blackmagic_ipa.py --ipa <new ipa> --out artifacts/reverse/<version>`.
3. Diff `ui_strings.json`, `ui_file_terms.json`, and `ipa_summary.json` against this note.
4. Update `BlackmagicReverseSpec.swift` and only then adjust `ShootingHUDComponents.swift` layout or option arrays.
