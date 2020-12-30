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
    func connection(_ connection: Connection, didTerminateWithReason reason: Connection.TerminationReason)
    func connection(_ connection: Connection, didReceiveData data: Data)
}

enum ConnectionError: Error {
    case invalidHost
}

class Connection {
    static func isValidHost(_ string: String) -> Bool {
        let host = NWEndpoint.Host(string)

        switch host {
        case .ipv4(_), .ipv6(_):
            return true
        default:
            return false
        }
    }

    weak var delegate: ConnectionDelegate?

    let connection: NWConnection
    lazy var dispatchQueue = DispatchQueue(label: "NWConnection")
    var timeoutTimer: DispatchSourceTimer?
    let timeoutPeriod: TimeInterval = 0.2
    var isEstablished = false

    init(host: String, port: NWEndpoint.Port) throws {
        guard Self.isValidHost(host) else {
            throw ConnectionError.invalidHost
        }

        connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)

        connection.stateUpdateHandler = { [weak self] (state) in
            self?.handleStateUpdate()
        }
    }

    func connect() {
        connection.start(queue: dispatchQueue)
        scheduleTimeoutTimer()
    }

    func disconnect() {
        if connection.state != .cancelled {
            connection.cancel()
        }
    }

    private func terminate(reason: TerminationReason) {
        isEstablished = false
        timeoutTimer?.cancel()
        delegate?.connection(self, didTerminateWithReason: reason)
    }

    private func handleStateUpdate() {
        logger.debug(connection.state)

        switch connection.state {
        case .ready:
            if !isEstablished {
                isEstablished = true
                delegate?.connectionDidEstablish(self)
            }
            readReceivedData()
        case .cancelled:
            terminate(reason: .closedByClient)
        case .failed:
            terminate(reason: .error)
        default:
            break
        }
    }

    private func readReceivedData() {
        connection.receive(minimumIncompleteLength: 500, maximumLength: 100000) { [weak self] (data, context, completed, error) in
            guard let self = self else { return }

            if let data = data {
                self.scheduleTimeoutTimer()
                self.delegate?.connection(self, didReceiveData: data)
            }

            if let error = error {
                logger.error(error)
            }

            if completed {
                self.terminate(reason: .closedByServer)
            } else if self.isEstablished {
                self.readReceivedData()
            }
        }
    }

    private func scheduleTimeoutTimer() {
        timeoutTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(flags: [], queue: dispatchQueue)

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.terminate(reason: .timeout)
        }

        timer.schedule(deadline: .now() + timeoutPeriod)
        timer.resume()

        timeoutTimer = timer
    }
}

extension Connection {
    enum TerminationReason {
        case closedByClient
        case closedByServer
        case error
        case timeout
    }
}
