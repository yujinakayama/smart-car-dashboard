//
//  Connection.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/14.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import Network

protocol ConnectionDelegate: NSObjectProtocol {
    func connectionDidEstablish(_ connection: Connection)
    func connectionDidTimeOut(_ connection: Connection)
    func connection(_ connection: Connection, didUpdateState state: NWConnection.State)
    func connection(_ connection: Connection, didReceiveData data: Data)
}

class Connection {
    weak var delegate: ConnectionDelegate?

    let connection: NWConnection
    var timeoutTimer: Timer?
    let timeoutPeriod: TimeInterval = 1
    var isEstablished = false

    init(host: String, port: NWEndpoint.Port) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)

        connection.stateUpdateHandler = { [weak self] (state) in
            self?.handleStateUpdate()
        }
    }

    func connect() {
        connection.start(queue: DispatchQueue(label: "NWConnection"))

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutPeriod, repeats: false, block: { [weak self] (timer) in
            guard let self = self else { return }
            if self.connection.state == .ready { return }
            self.delegate?.connectionDidTimeOut(self)
        })
    }

    func disconnect() {
        connection.cancel()
        isEstablished = false

        timeoutTimer?.invalidate()
    }

    func handleStateUpdate() {
        if !isEstablished && connection.state == .ready {
            isEstablished = true
            delegate?.connectionDidEstablish(self)
        }

        delegate?.connection(self, didUpdateState: connection.state)

        if connection.state == .ready {
            readReceivedData()
        }
    }

    func readReceivedData() {
        connection.receive(minimumIncompleteLength: 500, maximumLength: 100000) { [weak self] (data, context, completed, error) in
            guard let self = self else { return }

            if let data = data {
                self.delegate?.connection(self, didReceiveData: data)
            }

            self.readReceivedData()
        }
    }

}
