//
//  MockSerialPort.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/06.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

let paymentRecordResponsePayloads = [
    "01031210701031204920190604184534001   470",
    "01031275301031206920190531175618001   840",
    "01031291501031291920190531172428001   300",
    "01080302801080305420190531171226001  2120",
    "01080305401080303120190530124006001  1840",
    "01080305401080305420190530113434001   800",
    "01031284601031287720190530112428001   930",
    "01082110101082110120190530104452001   320",
    "01031282701031282820190530104048001   930",
    "01082010201082010620190530102156001   330",
    "01031216301031209320190520160158001   450",
    "01090405801090320620190518202424001   830",
    "01090144601090140620190518182324001  2170",
    "01090146601090141920190518123104001  2670",
    "01090480501090483420190512175402001   870",
    "01090110301090483420190512113714001  1840",
    "01031292301031243720190505210458001   300",
    "01080303101080305420190505203032001  2090",
    "01080305401080302820190505151724001   930",
    "01080305401080305420190505145258001   800",
    "01031274701031288020190505143152001   340",
    "01031229701031240120190504212918001   830",
    "01031210701031229920190504205558001   770",
    "01031290301031274820190502220230001   700",
    "01031282701031279920190502195312001   360",
    "01082000401082010620190502194656001   190",
    "01031209501031201020190429141246001   560",
    "01031215501031209320190429122852001   360"
]

class MockSerialPort: NSObject, SerialPort {
    weak var delegate: SerialPortDelegate?

    var isAvailable = false

    private var paymentRecordPayloadIterator: IndexingIterator<[String]>?

    func startPreparation() {
        delegate?.serialPortDidFinishPreparation(self, error: nil)
        isAvailable = true
        startHeartbeats()
    }

    func transmit(_ data: Data) throws {
        switch data {
        case ETCMessageFromClient.handshakeRequest.data:
            simulateReceive(ETCMessageFromDevice.HandshakeAcknowledgement.makeMockMessage())
            simulateReceive(ETCMessageFromDevice.HandshakeRequest.makeMockMessage())
        case ETCMessageFromClient.initialPaymentRecordRequest.data:
            if paymentRecordPayloadIterator == nil {
                paymentRecordPayloadIterator = paymentRecordResponsePayloads.makeIterator()
                simulateReceive(ETCMessageFromDevice.InitialPaymentRecordExistenceResponse.makeMockMessage())
            } else if let payload = paymentRecordPayloadIterator!.next() {
                simulateReceive(ETCMessageFromDevice.PaymentRecordResponse.makeMockMessage(payload: payload))
            }
        case ETCMessageFromClient.nextPaymentRecordRequest.data:
            if let payload = paymentRecordPayloadIterator?.next() {
                simulateReceive(ETCMessageFromDevice.PaymentRecordResponse.makeMockMessage(payload: payload))
            } else {
                paymentRecordPayloadIterator = nil
                simulateReceive(ETCMessageFromDevice.NextPaymentRecordNonExistenceResponse.makeMockMessage())
            }
        default:
            break
        }
    }

    private func simulateReceive(_ message: ETCMessageFromDeviceProtocol) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.delegate?.serialPort(self, didReceiveData: message.data)
        }
    }

    private func startHeartbeats() {
        var heartbeatCount = 0

        simulateReceive(ETCMessageFromDevice.HeartBeat.makeMockMessage())
        heartbeatCount += 1

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
            guard let self = self else { return }

            if heartbeatCount < 5 {
                self.simulateReceive(ETCMessageFromDevice.HeartBeat.makeMockMessage())
                heartbeatCount += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
