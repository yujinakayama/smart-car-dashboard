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
        brightness: 55,
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
        options.exposure = .nightpreview
        return options
    }()

    static func fixedSensitivity(digitalgain: Float) -> CameraOptions {
        var options = day
        options.digitalgain = digitalgain
        return options
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
            try container.encode(String(format: "%d,%d", u, v))
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
            try container.encode(String(format: "%f,%f,%f,%f", x, y, width, height))
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
            try container.encode(String(format: "%f,%f", blue, red))
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
