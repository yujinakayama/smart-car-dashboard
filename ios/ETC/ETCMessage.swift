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

protocol ETCMessage {
    var bytes: [UInt8] { get }
    var headerBytes: [UInt8] { get }
    var payloadBytes: [UInt8] { get }
    var terminalBytes: [UInt8] { get }
    var data: Data { get }
}

extension ETCMessage {
    static var terminalByte: UInt8 {
        return 0x0D
    }

    var bytes: [UInt8] {
        return headerBytes + payloadBytes + terminalBytes
    }
}

protocol ETCSendableMessage: ETCMessage {}

extension ETCSendableMessage {
    var data: Data {
        return Data(bytes)
    }

    var requiresPreliminaryHandshake: Bool {
        return bytes.first == 0x01
    }
}

protocol ETCReceivedMessage: ETCMessage, CustomDebugStringConvertible {
    static var headerBytes: [UInt8] { get }
    static var length: Int { get }
    static var headerLength: Int { get }
    static var payloadLength: Int { get }
    static var terminalLength: Int { get }
    var data: Data { get set }
    init(data: Data)
}

extension ETCReceivedMessage {
    static func makeReceivedMessageIfMatches(data: Data) -> (message: ETCReceivedMessage, unconsumedData: Data)? {
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

    // TODO: Add validation for terminal bytes
}

protocol Plain where Self: ETCReceivedMessage {}

extension Plain {
    static var terminalLength: Int {
        return 1
    }
}

protocol Checksummed where Self: ETCReceivedMessage  {}

extension Checksummed {
    static var terminalLength: Int {
        return 3
    }

    // TODO: Add checksum validation
}

extension ETCDevice {
    enum SendableMessage {
        static let handshakeRequest = SendablePlainMessage(headerBytes: [0xFA])
        static let acknowledgement = SendableChecksummedMessage(headerBytes: [0x02, 0xC0])
        static let deviceNameRequest = SendableChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "K")])
        static let initialUsageRecordRequest = SendableChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "L")])
        static let nextUsageRecordRequest = SendableChecksummedMessage(headerBytes: [0x01, 0xC6, byte(of: "M")])

        struct SendablePlainMessage: ETCSendableMessage {
            let headerBytes: [UInt8]
            let payloadBytes: [UInt8] = []
            let terminalBytes: [UInt8] = [SendablePlainMessage.terminalByte]
        }

        struct SendableChecksummedMessage: ETCSendableMessage {
            let headerBytes: [UInt8]

            let payloadBytes: [UInt8] = []

            var terminalBytes: [UInt8] {
                return checksumBytes + [SendableChecksummedMessage.terminalByte]
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
}

extension ETCDevice {
    enum ReceivedMessage {
        static let types: [ETCReceivedMessage.Type] = [
            HeartBeat.self,
            HandshakeAcknowledgement.self,
            HandshakeRequest.self,
            DeviceNameResponse.self,
            InitialUsageRecordExistenceResponse.self,
            InitialUsageRecordNonExistenceResponse.self,
            NextUsageRecordNonExistenceResponse.self,
            UsageRecordResponse.self,
        ]

        struct HeartBeat: ETCReceivedMessage, Plain {
            static let headerBytes: [UInt8] = [byte(of: "U")]
            static let payloadLength = 0
            var data: Data
        }

        struct HandshakeAcknowledgement: ETCReceivedMessage, Plain {
            static let headerBytes: [UInt8] = [0xF0]
            static let payloadLength = 0
            var data: Data
        }

        struct HandshakeRequest: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x01, 0xC2, byte(of: "0")]
            static let payloadLength = 0
            var data: Data
        }

        struct DeviceNameResponse: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x02, 0xE2]
            static let payloadLength = 8
            var data: Data

            var deviceName: String? {
                return String(bytes: payloadBytes, encoding: .ascii)
            }
        }

        struct InitialUsageRecordExistenceResponse: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "7")]
            static let payloadLength = 0
            var data: Data
        }

        struct InitialUsageRecordNonExistenceResponse: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "5")]
            static let payloadLength = 0
            var data: Data
        }

        struct NextUsageRecordNonExistenceResponse: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x02, 0xC1, byte(of: "8")]
            static let payloadLength = 0
            var data: Data
        }

        struct UsageRecordResponse: ETCReceivedMessage, Checksummed {
            static let headerBytes: [UInt8] = [0x02, 0xE5]
            static let payloadLength = 41
            var data: Data

            var usage: ETCUsage {
                let usage = ETCUsage()
                usage.entranceRoadNumber      = number(in: 4...5)
                usage.entranceTollboothNumber = number(in: 6...8)
                usage.exitRoadNumber          = number(in: 13...14)
                usage.exitTollboothNumber     = number(in: 15...17)
                usage.year                    = number(in: 18...21)
                usage.month                   = number(in: 22...23)
                usage.day                     = number(in: 24...25)
                usage.hour                    = number(in: 26...27)
                usage.minute                  = number(in: 28...29)
                usage.second                  = number(in: 30...31)
                usage.vehicleType             = number(in: 32...34)
                usage.fee                     = number(in: 35...40)
                return usage
            }

            func number(in range: ClosedRange<Int>) -> Int? {
                guard let string = String(bytes: payloadBytes[range], encoding: .ascii) else { return nil }
                return Int(string.trimmingCharacters(in: .whitespaces))
            }
        }

        struct Unknown: ETCReceivedMessage {
            static let headerBytes: [UInt8] = []
            static let payloadLength = 0
            static let terminalLength = 0
            var data: Data
        }
    }
}
