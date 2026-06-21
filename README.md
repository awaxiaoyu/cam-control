# CamControl

SwiftUI iOS port of Remote Your Cam USB. (Only supports Nikon, Canon and Sony cameras.)

This project keeps the original Apache 2.0 license and rewrites the Android USB Host transport around Apple's public ImageCaptureCore APIs. The app targets iOS 17 and newer SDKs, including iOS 26.

## 简要说明（Chinese summary）

这是 Remote Your Cam USB 的 SwiftUI iOS 移植版，使用 ImageCaptureCore 作为传输层，可在支持 USB/tether 的 iPhone 和 iPad 上控制相机。当前支持三大厂商：Nikon、Canon、Sony。

## Features

- Device discovery: find USB/tethered cameras via ImageCaptureCore.
- Live view: stream camera live view to the app when the camera provides a live view feed.
- Remote capture: trigger still captures (shutter release) from the app.
- Camera properties: read and change common camera settings exposed by the camera (exposure, ISO, shutter, aperture when supported).
- Gallery & preview: view captured photos inside the app and preview before saving/exporting.
- Save & export: save images to the Photos library or export using standard iOS share sheet.
- Mockable transport & controllers: CamControlCore provides mockable CameraController for testing and development.
- PTP packet handling: PTP packet encoding/parsing and vendor drivers live in CamControlCore.
- SwiftUI app shell: CamControlApp provides device discovery, UI, and interaction layers.

## Supported cameras

- Nikon (PTP/PTP-IP compatible models)
- Canon (PTP/PTP-IP compatible models)
- Sony (PTP/PTP-IP compatible models)

Note: Support is at the protocol/driver level (Nikon/Canon drivers implemented in CamControlCore). Exact behaviour and available features depend on the camera model and firmware. If you need a specific model verified (e.g. Z-series, R-series, EOS models, or Alpha series), open an issue and include the camera model and firmware version.

## Requirements

- macOS with Xcode and XcodeGen installed
- Xcode 15+ recommended (targets iOS 17+ SDKs)
- A real iPhone or iPad running iOS 17 or newer — USB/tethered camera control cannot be validated in the simulator
- An Apple Developer account or TestFlight/Ad Hoc signing to install on physical devices

## Build

Install XcodeGen on a Mac, then run:

```sh
xcodegen generate
open CamControl.xcodeproj
```

Open the generated project in Xcode, select a real device, set your signing team, then build and run.

## Usage notes

- Connect your camera to the iPhone/iPad using a supported USB adapter or tethering method.
- The app uses the ImageCaptureCore framework; camera discovery and capabilities are limited to what ImageCaptureCore exposes for the connected device.
- For best results, enable camera remote control (PC Remote / USB Remote / Remote Control) mode on the camera if required by the vendor.

## GitHub Actions

The included workflow builds and tests on GitHub's macOS runner without code signing. To install on an iPhone 16 Pro Max or other device, use TestFlight or an Ad Hoc signed IPA from an Apple Developer Program account.

## Project structure

- CamControlCore: PTP packet encoding/parsing, Nikon/Canon drivers, ImageCaptureCore transport, and a mockable CameraController abstraction.
- CamControlApp: SwiftUI application providing device discovery, live view, camera properties UI, gallery, preview, and saving/exporting.

## Troubleshooting

- If a camera is not discovered, confirm the camera is in the correct USB/remote mode and the cable/adapter supports data (some cheap adapters only provide power).
- If live view or properties are missing, the camera may not expose those features over PTP/ImageCaptureCore — check the camera manual and firmware.

## Contributing

Contributions are welcome. Please open issues for bugs or feature requests and submit pull requests for fixes or enhancements.

If you add or verify support for a specific camera model, include the model and firmware in the issue so others can see which models work.

## License

This project retains the original Apache 2.0 license from Remote Your Cam USB. See the LICENSE file for details.
