# CamControl

SwiftUI iOS port of Remote Your Cam USB.（only support Nikon，Canon and Sony）

This project keeps the original Apache 2.0 license and rewrites the Android USB Host transport around Apple's public ImageCaptureCore APIs. The app targets iOS 17 and newer SDKs, including iOS 26.

## Build

Install XcodeGen on a Mac, then run:

```sh
xcodegen generate
open CamControl.xcodeproj
```

Run on a real iPhone or iPad. USB/tethered camera control cannot be validated in the simulator.

## GitHub Actions

The included workflow builds and tests on GitHub's macOS runner without code signing. To install on an iPhone 16 Pro Max, use TestFlight or an Ad Hoc signed IPA from an Apple Developer Program account.

## Shape

`CamControlCore` owns PTP packet encoding, parsing, Nikon/Canon drivers, ImageCaptureCore transport, and a mockable `CameraController`.

`CamControlApp` is the SwiftUI shell for device discovery, live view, camera properties, gallery, preview, and saving.
