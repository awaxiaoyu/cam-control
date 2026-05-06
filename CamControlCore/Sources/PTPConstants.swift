import Foundation

public enum PTP {
    public enum Vendor {
        public static let canon: UInt16 = 0x04a9
        public static let nikon: UInt16 = 0x04b0
    }

    public enum ContainerType {
        public static let command: UInt16 = 1
        public static let data: UInt16 = 2
        public static let response: UInt16 = 3
        public static let event: UInt16 = 4
    }

    public enum Operation {
        public static let getDeviceInfo: UInt16 = 0x1001
        public static let openSession: UInt16 = 0x1002
        public static let closeSession: UInt16 = 0x1003
        public static let getStorageIDs: UInt16 = 0x1004
        public static let getStorageInfo: UInt16 = 0x1005
        public static let getObjectHandles: UInt16 = 0x1007
        public static let getObjectInfo: UInt16 = 0x1008
        public static let getObject: UInt16 = 0x1009
        public static let getThumb: UInt16 = 0x100a
        public static let initiateCapture: UInt16 = 0x100e
        public static let getDevicePropDesc: UInt16 = 0x1014
        public static let getDevicePropValue: UInt16 = 0x1015
        public static let setDevicePropValue: UInt16 = 0x1016
        public static let nikonInitiateCaptureRecInSdram: UInt16 = 0x90c0
        public static let nikonAfDrive: UInt16 = 0x90c1
        public static let nikonChangeCameraMode: UInt16 = 0x90c2
        public static let nikonGetEvent: UInt16 = 0x90c7
        public static let nikonDeviceReady: UInt16 = 0x90c8
        public static let nikonGetVendorPropCodes: UInt16 = 0x90ca
        public static let nikonStartLiveView: UInt16 = 0x9201
        public static let nikonEndLiveView: UInt16 = 0x9202
        public static let nikonGetLiveViewImage: UInt16 = 0x9203
        public static let nikonMfDrive: UInt16 = 0x9204
        public static let nikonChangeAfArea: UInt16 = 0x9205
        public static let eosTakePicture: UInt16 = 0x910f
        public static let eosSetDevicePropValue: UInt16 = 0x9110
        public static let eosSetPCConnectMode: UInt16 = 0x9114
        public static let eosSetEventMode: UInt16 = 0x9115
        public static let eosEventCheck: UInt16 = 0x9116
        public static let eosTransferComplete: UInt16 = 0x9117
        public static let eosBulbStart: UInt16 = 0x9125
        public static let eosBulbEnd: UInt16 = 0x9126
        public static let eosRemoteReleaseOn: UInt16 = 0x9128
        public static let eosRemoteReleaseOff: UInt16 = 0x9129
        public static let eosGetLiveViewPicture: UInt16 = 0x9153
        public static let eosDriveLens: UInt16 = 0x9155
    }

    public enum Event {
        public static let objectAdded: UInt16 = 0x4002
        public static let devicePropChanged: UInt16 = 0x4006
        public static let captureComplete: UInt16 = 0x400d
        public static let nikonObjectAddedInSdram: UInt16 = 0xc101
        public static let nikonCaptureCompleteRecInSdram: UInt16 = 0xc102
        public static let eosObjectAdded: UInt16 = 0xc181
        public static let eosDevicePropChanged: UInt16 = 0xc189
        public static let eosDevicePropDescChanged: UInt16 = 0xc18a
        public static let eosCameraStatus: UInt16 = 0xc18b
        public static let eosWillSoonShutdown: UInt16 = 0xc18d
        public static let eosBulbExposureTime: UInt16 = 0xc194
    }

    public enum Response {
        public static let ok: UInt16 = 0x2001
        public static let generalError: UInt16 = 0x2002
        public static let sessionNotOpen: UInt16 = 0x2003
        public static let operationNotSupported: UInt16 = 0x2005
        public static let storeNotAvailable: UInt16 = 0x2013
        public static let deviceBusy: UInt16 = 0x2019
        public static let invalidParameter: UInt16 = 0x201d
        public static let sessionAlreadyOpen: UInt16 = 0x201e
        public static let nikonNotLiveView: UInt16 = 0xa00b
    }

    public enum Property {
        public static let batteryLevel: UInt16 = 0x5001
        public static let whiteBalance: UInt16 = 0x5005
        public static let fNumber: UInt16 = 0x5007
        public static let focusMode: UInt16 = 0x500a
        public static let exposureMeteringMode: UInt16 = 0x500b
        public static let exposureTime: UInt16 = 0x500d
        public static let exposureProgramMode: UInt16 = 0x500e
        public static let exposureIndex: UInt16 = 0x500f
        public static let exposureBiasCompensation: UInt16 = 0x5010
        public static let focusMeteringMode: UInt16 = 0x501c
        public static let eosApertureValue: UInt16 = 0xd101
        public static let eosShutterSpeed: UInt16 = 0xd102
        public static let eosIsoSpeed: UInt16 = 0xd103
        public static let eosExposureCompensation: UInt16 = 0xd104
        public static let eosShootingMode: UInt16 = 0xd105
        public static let eosMeteringMode: UInt16 = 0xd107
        public static let eosAfMode: UInt16 = 0xd108
        public static let eosWhiteBalance: UInt16 = 0xd109
        public static let eosColorTemperature: UInt16 = 0xd10a
        public static let eosPictureStyle: UInt16 = 0xd110
        public static let eosAvailableShots: UInt16 = 0xd11b
        public static let eosEvfOutputDevice: UInt16 = 0xd1b0
        public static let eosEvfMode: UInt16 = 0xd1b3
        public static let nikonShutterSpeed: UInt16 = 0xd100
        public static let nikonWbColorTemp: UInt16 = 0xd01e
        public static let nikonEnableAfAreaPoint: UInt16 = 0xd08d
        public static let nikonFocusArea: UInt16 = 0xd108
        public static let nikonRecordingMedia: UInt16 = 0xd10b
        public static let nikonExposureIndicateStatus: UInt16 = 0xd1b1
        public static let nikonActivePictureControlItem: UInt16 = 0xd200
    }

    public enum DataType {
        public static let int8: UInt16 = 0x0001
        public static let uint8: UInt16 = 0x0002
        public static let int16: UInt16 = 0x0003
        public static let uint16: UInt16 = 0x0004
        public static let int32: UInt16 = 0x0005
        public static let uint32: UInt16 = 0x0006
    }

    public enum ObjectFormat {
        public static let association: UInt16 = 0x3001
        public static let exifJpeg: UInt16 = 0x3801
        public static let tiff: UInt16 = 0x380d
        public static let eosCRW: UInt16 = 0xb101
        public static let eosCRW3: UInt16 = 0xb103
        public static let eosMOV: UInt16 = 0xb104
    }

    public enum NikonProduct {
        public static let d200: UInt16 = 0x0410
        public static let d80: UInt16 = 0x0412
        public static let d40: UInt16 = 0x0414
        public static let d300: UInt16 = 0x041a
        public static let d3: UInt16 = 0x041c
        public static let d3x: UInt16 = 0x0420
        public static let d90: UInt16 = 0x0421
        public static let d700: UInt16 = 0x0422
        public static let d5000: UInt16 = 0x0423
        public static let d300s: UInt16 = 0x0425
        public static let d3s: UInt16 = 0x0426
        public static let d7000: UInt16 = 0x0428
        public static let d5100: UInt16 = 0x0429
    }

    public static func responseName(_ code: UInt16) -> String {
        switch code {
        case Response.ok: return "OK"
        case Response.generalError: return "GeneralError"
        case Response.sessionNotOpen: return "SessionNotOpen"
        case Response.operationNotSupported: return "OperationNotSupported"
        case Response.storeNotAvailable: return "StoreNotAvailable"
        case Response.deviceBusy: return "DeviceBusy"
        case Response.invalidParameter: return "InvalidParameter"
        case Response.sessionAlreadyOpen: return "SessionAlreadyOpen"
        case Response.nikonNotLiveView: return "NotLiveView"
        default: return "0x\(String(code, radix: 16))"
        }
    }
}
