//
//  CameraOptions.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/12/26.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

struct CameraOptions: Encodable {
    static let day = CameraOptions(
        sharpness: 100,
        saturation: 12,
        exposure: .auto,
        flicker: .auto,
        awb: .off,
        imxfx: .denoise,
        metering: .average,
        hflip: true,
        drc: .high,
        awbgains: AWBGains(blue: 1.4, red: 1.6),
        width: 1440,
        height: 1080,
        framerate: 40,
        profile: .high,
        level: .fourPointTwo
    )

    static let night: CameraOptions = {
        var options = day
        options.brightness = 55
        options.exposure = .nightpreview
        options.awbgains = AWBGains(blue: 1.45, red: 1.7)
        return options
    }()

    static func fixedSensitivity(digitalgain: Float) -> CameraOptions {
        var options = night
        options.digitalgain = sanitizeDigitalGain(digitalgain)
        return options
    }

    private static func sanitizeDigitalGain(_ digitalgain: Float) -> Float {
        // Sets the digital gain value applied by the ISP (floating point value from 1.0 to 64.0,
        // but values over about 4.0 will produce overexposed images)
        // https://www.raspberrypi.org/documentation/raspbian/applications/camera.md

        if digitalgain < 1 {
            return 1
        } else if digitalgain > 64 {
            return 64
        } else {
            return digitalgain
        }
    }

    // https://github.com/raspberrypi/userland/blob/093b30b/host_applications/linux/apps/raspicam/RaspiCamControl.c#L189-L218
    var sharpness: Int?
    var contrast: Int?
    var brightness: Int?
    var saturation: Int?
    var ISO: UInt?
    var vstab: Bool?
    var ev: Int?
    var exposure: Exposure?
    var flicker: Flicker?
    var awb: AWB?
    var imxfx: ImageFX?
    var colfx: ColourFX?
    var metering: MeterMode?
    var rotation: UInt?
    var hflip: Bool?
    var vflip: Bool?
    var roi: ROI?
    var shutter: UInt?
    var drc: DRCLevel?
    var stats: Bool?
    var awbgains: AWBGains?
    var analoggain: Float?
    var digitalgain: Float?
    var mode: UInt?

    // https://github.com/raspberrypi/userland/blob/093b30b/host_applications/linux/apps/raspicam/RaspiVid.c#L316-L344
    var width: UInt?
    var height: UInt?
    var bitrate: UInt?
    var framerate: UInt?
    var intra: UInt?
    var qp: UInt?
    var profile: Profile?
    var level: Level?
    var irefresh: IntraRefreshType?
    var inline: Bool?
    var spstimings: Bool?
}

extension CameraOptions {
    enum Exposure: String, Encodable {
        case auto, night, nightpreview, backlight, spotlight, sports, snow, beach, verylong, fixedfps, antishake, fireworks
    }

    enum Flicker: String, Encodable {
        case off, auto, fiftyHz = "50hz", sixtyHz = "60hz"
    }

    enum AWB: String, Encodable {
        case off, auto, sun, cloud, shade, tungsten, fluorescent, incandescent, flash, horizon, greyworld
    }

    enum ImageFX: String, Encodable {
        case none, negative, solarise, posterise, whiteboard, blackboard, sketch, denoise, emboss, oilpaint, hatch, gpen, pastel, watercolour, film, blur, saturation, colourswap, washedout, colourpoint, colourbalance, cartoon
    }

    struct ColourFX: Encodable {
        let u: UInt
        let v: UInt

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }

        var string: String {
            return [u, v].map { String($0) }.joined(separator: ",")
        }
    }

    enum MeterMode: String, Encodable {
        case average, spot, backlit, matrix
    }

    struct ROI: Encodable {
        let x: Float
        let y: Float
        let width: Float
        let height: Float

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }

        var string: String {
            return [x, y, width, height].map { String($0) }.joined(separator: ",")
        }
    }

    enum DRCLevel: String, Encodable {
        case off, low, med, high
    }

    struct AWBGains: Encodable {
        let blue: Float
        let red: Float

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }

        var string: String {
            return [blue, red].map { String($0) }.joined(separator: ",")
        }
    }

    enum Profile: String, Encodable {
        case baseline, main, high
    }

    enum Level: String, Encodable {
        case four = "4", fourPointOne = "4.1", fourPointTwo = "4.2"
    }

    enum IntraRefreshType: String, Encodable {
        case cyclic, adaptive, both, cyclicrows
    }
}
