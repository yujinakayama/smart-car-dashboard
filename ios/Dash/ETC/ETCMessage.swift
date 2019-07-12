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

fileprivate func checksum(of headerAndPayloadBytes: [UInt8]) -> [UInt8] {
    var targetBytes = headerAndPayloadBytes
    targetBytes.removeFirst()
    let sum = targetBytes.reduce(0 as Int) { sum, byte in sum + Int(byte) }
    let lowerTwoDigitStringOfSum = String(format: "%02X", sum).suffix(2)
    return lowerTwoDigitStringOfSum.map { $0.asciiValue! }
}

enum ETCMessageError: Error {
    case unparsableString
    case unparsableInteger
    case invalidDate
    case unknownVehicleClassification
}

protocol ETCMessageProtocol: CustomDebugStringConvertible {
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

    var debugDescription: String {
        return "\(type(of: self))(data: \(data.map { String(format: "%02X", $0) }.joined(separator: " ")))"
    }
}

protocol ETCMessageFromClientProtocol: ETCMessageProtocol {}

extension ETCMessageFromClientProtocol {
    var bytes: [UInt8] {
        return headerBytes + payloadBytes + terminalBytes
    }

    var data: Data {
        return Data(bytes)
    }

    var requiresPreliminaryHandshake: Bool {
        return bytes.first == 0x01
    }
}

protocol ETCMessageFromDeviceProtocol: ETCMessageProtocol {
    static func validTerminalBytes(payloadBytes: [UInt8]) -> [UInt8]
    static var headerBytes: [UInt8] { get }
    static var length: Int { get }
    static var headerLength: Int { get }
    static var payloadLength: Int { get }
    static var terminalLength: Int { get }
    var data: Data { get }
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

    static func makeMockMessage(payload: String) -> Self {
        let bytes = Array(payload.utf8)
        return makeMockMessage(payloadBytes: bytes)
    }

    static func makeMockMessage(payloadBytes: [UInt8] = []) -> Self {
        assert(payloadBytes.count == payloadLength)
        let terminalBytes = validTerminalBytes(payloadBytes: payloadBytes)
        let data = Data(headerBytes + payloadBytes + terminalBytes)
        return Self(data: data)
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

    func extractIntegerFromPayload(in range: ClosedRange<Int>? = nil) throws -> Int {
        let string = try extractStringFromPayload(in: range)

        if let integer = Int(string.trimmingCharacters(in: .whitespaces)) {
            return integer
        } else {
            throw ETCMessageError.unparsableInteger
        }
    }

    func extractStringFromPayload(in range: ClosedRange<Int>? = nil) throws -> String {
        let targetRange = range ?? 0...(Self.payloadLength - 1)

        if let string = String(bytes: payloadBytes[targetRange], encoding: .ascii) {
            return string
        } else {
            throw ETCMessageError.unparsableString
        }
    }

    // TODO: Add validation for terminal bytes
}

protocol Plain where Self: ETCMessageFromDeviceProtocol {}

extension Plain {
    static func validTerminalBytes(payloadBytes: [UInt8]) -> [UInt8] {
        return [terminalByte]
    }

    static var terminalLength: Int {
        return 1
    }
}

protocol Checksummed where Self: ETCMessageFromDeviceProtocol  {}

extension Checksummed {
    static func validTerminalBytes(payloadBytes: [UInt8]) -> [UInt8] {
        return checksum(of: headerBytes + payloadBytes) + [terminalByte]
    }

    static var terminalLength: Int {
        return 3
    }

    // TODO: Add checksum validation
}

enum ETCMessageFromClient {
    static let handshakeRequest = PlainMessage(headerBytes: [0xFA])
    static let acknowledgement = ChecksummedMessage(headerBytes: [0x02, 0xC0])
    static let cardExistenceRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "G")])
    static let deviceNameRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "K")])
    static let initialPaymentRecordRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "L")])
    static let nextPaymentRecordRequest = ChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "M")])

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
            return checksum(of: headerBytes + payloadBytes)
        }
    }
}

enum ETCMessageFromDevice {
    static let knownTypes: [ETCMessageFromDeviceProtocol.Type] = [
        HeartBeat.self,
        HandshakeAcknowledgement.self,
        HandshakeRequest.self,
        CardExistenceResponse.self,
        CardNonExistenceResponse.self,
        DeviceNameResponse.self,
        InitialPaymentRecordExistenceResponse.self,
        InitialPaymentRecordNonExistenceResponse.self,
        NextPaymentRecordNonExistenceResponse.self,
        PaymentRecordResponse.self,
        GateEntranceNotification.self,
        GateExitNotification.self,
        PaymentNotification.self,
        CardInsertionNotification.self,
        CardEjectionNotification.self
    ]

    struct HeartBeat: ETCMessageFromDeviceProtocol, Plain {
        static let headerBytes: [UInt8] = [byte(of: "U")]
        static let payloadLength = 0
        let data: Data
    }

    struct HandshakeAcknowledgement: ETCMessageFromDeviceProtocol, Plain {
        static let headerBytes: [UInt8] = [0xF0]
        static let payloadLength = 0
        let data: Data
    }

    struct HandshakeRequest: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC2, byte(of: "0")]
        static let payloadLength = 0
        let data: Data
    }

    struct CardExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xCD, 0x01]
        static let payloadLength = 0
        let data: Data
    }

    struct CardNonExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xCD, 0x00]
        static let payloadLength = 0
        let data: Data
    }

    struct DeviceNameResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xE2]
        static let payloadLength = 8
        let data: Data

        var deviceName: String? {
            return String(bytes: payloadBytes, encoding: .ascii)
        }
    }

    struct InitialPaymentRecordExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "7")]
        static let payloadLength = 0
        let data: Data
    }

    struct InitialPaymentRecordNonExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "5")]
        static let payloadLength = 0
        let data: Data
    }

    struct NextPaymentRecordNonExistenceResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "8")]
        static let payloadLength = 0
        let data: Data
    }

    struct PaymentRecordResponse: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x02, 0xE5]
        static let payloadLength = 41
        let data: Data

        var payment: ETCPayment? {
            do {
                return ETCPayment(
                    amount: try amount(),
                    date: try date(),
                    entranceTollboothID: try entranceTollboothID(),
                    exitTollboothID: try exitTollboothID(),
                    vehicleClassification: try vehicleClassification()
                )
            } catch {
                return nil
            }
        }

        func entranceTollboothID() throws -> String {
            let roadNumber = try extractStringFromPayload(in: 4...5)
            let tollboothNumber = try extractStringFromPayload(in: 6...8)
            return "\(roadNumber)-\(tollboothNumber)"
        }

        func exitTollboothID() throws -> String {
            let roadNumber = try extractStringFromPayload(in: 13...14)
            let tollboothNumber = try extractStringFromPayload(in: 15...17)
            return "\(roadNumber)-\(tollboothNumber)"
        }

        func date() throws -> Date {
            var dateComponents = DateComponents()
            dateComponents.calendar = Calendar(identifier: .gregorian)
            dateComponents.timeZone = TimeZone(identifier: "Asia/Tokyo")
            dateComponents.year = try extractIntegerFromPayload(in: 18...21)
            dateComponents.month = try extractIntegerFromPayload(in: 22...23)
            dateComponents.day = try extractIntegerFromPayload(in: 24...25)
            dateComponents.hour = try extractIntegerFromPayload(in: 26...27)
            dateComponents.minute = try extractIntegerFromPayload(in: 28...29)
            dateComponents.second = try extractIntegerFromPayload(in: 30...31)

            if let date = dateComponents.date {
                return date
            } else {
                throw ETCMessageError.invalidDate
            }
        }

        func vehicleClassification() throws -> VehicleClassification {
            let integer = try extractIntegerFromPayload(in: 32...34)

            if let vehicleClassification = VehicleClassification(rawValue: Int16(integer)) {
                return vehicleClassification
            } else {
                throw ETCMessageError.unknownVehicleClassification
            }
        }

        func amount() throws -> Int32 {
            let integer = try extractIntegerFromPayload(in: 35...40)
            return Int32(integer)
        }
    }

    struct GateEntranceNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC7, byte(of: "a")]
        static let payloadLength = 0
        let data: Data
    }

    struct GateExitNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC7, byte(of: "A")]
        static let payloadLength = 0
        let data: Data
    }

    struct PaymentNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC5]
        static let payloadLength = 6
        let data: Data

        var amount: Int? {
            return try? extractIntegerFromPayload()
        }
    }

    struct CardInsertionNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC2, byte(of: "D")]
        static let payloadLength = 0
        let data: Data
    }

    struct CardEjectionNotification: ETCMessageFromDeviceProtocol, Checksummed {
        static let headerBytes: [UInt8] = [0x01, 0xC2, byte(of: "E")]
        static let payloadLength = 0
        let data: Data
    }

    struct Unknown: ETCMessageFromDeviceProtocol, Plain {
        static let headerBytes: [UInt8] = []
        static let payloadLength = 0
        static let terminalLength = 0
        let data: Data
    }
}
