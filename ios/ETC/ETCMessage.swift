//
//  ETCMessage.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/01.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

fileprivate func byte(of character: String) -> UInt8 {
    return Character(character).asciiValue!
}

protocol ETCMessageProtocol {
    var bytes: [UInt8] { get }
    var headerBytes: [UInt8] { get }
    var payloadBytes: [UInt8] { get }
    var terminalBytes: [UInt8] { get }
    var data: Data { get }
}

extension ETCMessageProtocol {
    static var terminalByte: UInt8 {
        return 0x0D
    }

    var bytes: [UInt8] {
        return headerBytes + payloadBytes + terminalBytes
    }
}

protocol ETCMessageFromClientProtocol: ETCMessageProtocol {}

extension ETCMessageFromClientProtocol {
    var data: Data {
        return Data(bytes)
    }

    var requiresPreliminaryHandshake: Bool {
        return bytes.first == 0x01
    }
}

protocol ETCMessageFromDeviceProtocol: ETCMessageProtocol, CustomDebugStringConvertible {
    static var headerBytes: [UInt8] { get }
    static var length: Int { get }
    static var headerLength: Int { get }
    static var payloadLength: Int { get }
    static var terminalLength: Int { get }
    var data: Data { get set }
    init(data: Data)
}

extension ETCMessageFromDeviceProtocol {
    static func makeMessageIfMatches(data: Data) -> (message: ETCMessageFromDeviceProtocol, unconsumedData: Data)? {
        guard matches(data: data) else { return nil }
        let consumedData = data[..<length]
        let unconsumedData = Data(data[length...]) // Re-instantiate as Data since the sliced Data starts from non-zero index
        return (Self(data: consumedData), unconsumedData)
    }

    static func matches(data: Data) -> Bool {
        return data.count >= length && [UInt8](data.prefix(headerLength)) == headerBytes
    }

    static var length: Int {
        return headerLength + payloadLength + terminalLength
    }

    static var headerLength: Int {
        return headerBytes.count
    }

    var bytes: [UInt8] {
        return [UInt8](data)
    }

    var headerBytes: [UInt8] {
        return Array(bytes[0..<Self.headerLength])
    }

    var payloadBytes: [UInt8] {
        return Array(bytes[Self.headerLength..<(Self.headerLength + Self.payloadLength)])
    }

    var terminalBytes: [UInt8] {
        let terminalStartIndex = Self.headerLength + Self.payloadLength
        return Array(bytes[(terminalStartIndex)..<(terminalStartIndex + Self.terminalLength)])
    }

    var requiresAcknowledgement: Bool {
        return bytes.first == 0x01
    }

    var debugDescription: String {
        return "\(type(of: self))(data: \(data.map { String(format: "%02X", $0) }.joined(separator: " ")))"
    }

    func number(in range: ClosedRange<Int>? = nil) -> Int? {
        let targetRange = range == nil ? 0...(Self.payloadLength - 1) : range!
        guard let string = String(bytes: payloadBytes[targetRange], encoding: .ascii) else { return nil }
        return Int(string.trimmingCharacters(in: .whitespaces))
    }

    // TODO: Add validation for terminal bytes
}

protocol Plain where Self: ETCMessageFromDeviceProtocol {}

extension Plain {
    static var terminalLength: Int {
        return 1
    }
}

protocol Checksummed where Self: ETCMessageFromDeviceProtocol  {}

extension Checksummed {
    static var terminalLength: Int {
        return 3
    }

    // TODO: Add checksum validation
}

enum ETCMessageFromClient {
    static let handshakeRequest = PlainMessage(headerBytes: [0xFA])
    static let acknowledgement = ChecksummedMessage(headerBytes: [0x02, 0xC0])
    static let deviceNameRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "K")])
    static let initialUsageRecordRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "L")])
    static let nextUsageRecordRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "M")])

    struct PlainMessage: ETCMessageFromClientProtocol {
        let headerBytes: [UInt8]
        let payloadBytes: [UInt8] = []
        let terminalBytes: [UInt8] = [PlainMessage.terminalByte]
    }

    struct ChecksummedMessage: ETCMessageFromClientProtocol {
        let headerBytes: [UInt8]

        let payloadBytes: [UInt8] = []

        var terminalBytes: [UInt8] {
            return checksumBytes + [ChecksummedMessage.terminalByte]
        }

        var checksumBytes: [UInt8] {
            var targetBytes = headerBytes + payloadBytes
            targetBytes.removeFirst()
            let sum = targetBytes.reduce(0 as Int) { sum, byte in sum + Int(byte) }
            let lowerTwoDigitStringOfSum = String(format: "%02X", sum).suffix(2)
            return lowerTwoDigitStringOfSum.map { $0.asciiValue! }
        }
    }
}

enum ETCMessageFromDevice {
    static let knownTypes: [ETCMessageFromDeviceProtocol.Type] = [
        HeartBeat.self,
        HandshakeAcknowledgement.self,
        HandshakeRequest.self,
        DeviceNameResponse.self,
        InitialUsageRecordExistenceResponse.self,
        InitialUsageRecordNonExistenceResponse.self,
        NextUsageRecordNonExistenceResponse.self,
        UsageRecordResponse.self,
        GateEntranceNotification.self,
        GateExitNotification.self,
        PaymentNotification.self
    ]

    struct HeartBeat: ETCMessageFromDeviceProtocol, Plain {
        static let headerBytes: [UInt8] = [byte(of: "U")]
        static let payloadLength = 0
        var data: Data
    }

    struct HandshakeAcknowledgement: ETCMessageFromDeviceProtocol, Plain {
        static let headerBytes: [UInt8] = [0xF0]
        static let payloadLength = 0
        var data: Data
    }

    struct HandshakeRequest: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC2, byte(of: "0")]
        static let payloadLength = 0
        var data: Data
    }

    struct DeviceNameResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xE2]
        static let payloadLength = 8
        var data: Data

        var deviceName: String? {
            return String(bytes: payloadBytes, encoding: .ascii)
        }
    }

    struct InitialUsageRecordExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "7")]
        static let payloadLength = 0
        var data: Data
    }

    struct InitialUsageRecordNonExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "5")]
        static let payloadLength = 0
        var data: Data
    }

    struct NextUsageRecordNonExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "8")]
        static let payloadLength = 0
        var data: Data
    }

    struct UsageRecordResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xE5]
        static let payloadLength = 41
        var data: Data

        var usage: ETCUsage {
            return ETCUsage(
                entranceRoadNumber: number(in: 4...5),
                entranceTollboothNumber: number(in: 6...8),
                exitRoadNumber: number(in: 13...14),
                exitTollboothNumber: number(in: 15...17),
                year: number(in: 18...21),
                month: number(in: 22...23),
                day: number(in: 24...25),
                hour: number(in: 26...27),
                minute: number(in: 28...29),
                second: number(in: 30...31),
                vehicleType: number(in: 32...34),
                fee: number(in: 35...40)
            )
        }
    }

    struct GateEntranceNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC7, byte(of: "a")]
        static let payloadLength = 0
        var data: Data
    }

    struct GateExitNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC7, byte(of: "A")]
        static let payloadLength = 0
        var data: Data
    }

    struct PaymentNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC5]
        static let payloadLength = 6
        var data: Data

        var fee: Int? {
            return number()
        }
    }

    struct Unknown: ETCMessageFromDeviceProtocol {
        static let headerBytes: [UInt8] = []
        static let payloadLength = 0
        static let terminalLength = 0
        var data: Data
    }
}
