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

class Connection {
    weak var delegate: ConnectionDelegate?

    let connection: NWConnection
    lazy var dispatchQueue = DispatchQueue(label: "NWConnection")
    var isEstablished = false
    private var isTerminated = false

    init(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 1  // establishmentTimeout
        tcpOptions.connectionDropTime = 1 // connectionDropTimeout

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

        connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] (state) in
            self?.handleStateUpdate()
        }
    }

    func connect() {
        connection.start(queue: dispatchQueue)
    }

    func disconnect() {
        if connection.state != .cancelled {
            connection.cancel()
        }
    }

    private func terminate(reason: TerminationReason) {
        isEstablished = false
        isTerminated = true
        connection.cancel()
        delegate?.connection(self, didTerminateWithReason: reason)
    }

    private func handleStateUpdate() {
        logger.debug(connection.state)

        switch connection.state {
        case .waiting(let error):
            logger.error(error)
            terminate(reason: error.isTimeOutError ? .establishmentTimeout : .establishmentFailure)
        case .ready:
            if !isEstablished {
                isEstablished = true
                delegate?.connectionDidEstablish(self)
            }
            readReceivedData()
        case .cancelled where !isTerminated:
            terminate(reason: .closedByClient)
        case .failed(let error):
            logger.error(error)
            terminate(reason: error.isTimeOutError ? .connectionDropTimeout : .unexpectedDisconnection)
        default:
            break
        }
    }

    private func readReceivedData() {
        connection.receive(minimumIncompleteLength: 500, maximumLength: 100000) { [weak self] (data, context, completed, error) in
            guard let self = self else { return }

            if let data = data {
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
}

extension Connection {
    enum TerminationReason {
        case establishmentFailure
        case establishmentTimeout
        case closedByClient
        case closedByServer
        case unexpectedDisconnection
        case connectionDropTimeout
    }
}

fileprivate extension NWError {
    var isTimeOutError: Bool {
        switch self {
        case .posix(let posixErrorCode):
            return posixErrorCode == .ETIMEDOUT
        default:
            return false
        }
    }
}
