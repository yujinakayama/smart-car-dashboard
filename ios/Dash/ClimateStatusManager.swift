//
//  ClimateStatusManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/01/20.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation
import HomeKit

// Custom HomeKit types
fileprivate let HMServiceTypeAirPressureSensor         = "A54E5D5C-BFE7-4060-ACD0-69F9D6FDB30E"
fileprivate let HMCharacteristicTypeCurrentAirPressure = "C13C8795-D950-453A-A3E7-DF244913560A"

class ClimateStatusManager: NSObject {
    let homeName: String
    let statusBarManager: StatusBarManager
    let homeManager = HMHomeManager()

    private var temperature: Characteristic<Double>?
    private var humidity: Characteristic<Double>?
    private var airPressure: Characteristic<Double>?

    private var updateTimer: DispatchSourceTimer?

    init(homeName: String, statusBarManager: StatusBarManager) {
        self.homeName = homeName
        self.statusBarManager = statusBarManager
        super.init()
        homeManager.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(statusBarManagerDidUpdateVisibility), name: .StatusBarManagerDidUpdateVisibility, object: nil)
    }

    private var home: HMHome? {
        return homeManager.homes.first { $0.name == homeName }
    }

    @objc func statusBarManagerDidUpdateVisibility() {
        startOrStopUpdating()
    }

    private func startOrStopUpdating() {
        if statusBarManager.isStatusBarVisible {
            startUpdating()
        } else {
            stopUpdating()
        }
    }

    private func startUpdating() {
        guard updateTimer == nil, let home = home else { return }

        temperature = Characteristic<Double>(
            home: home,
            serviceType: HMServiceTypeTemperatureSensor, // TODO: Avoid filtering with service type
            characteristicType: HMCharacteristicTypeCurrentTemperature
        )

        humidity = Characteristic<Double>(
            home: home,
            serviceType: HMServiceTypeHumiditySensor,
            characteristicType: HMCharacteristicTypeCurrentRelativeHumidity
        )

        airPressure = Characteristic<Double>(
            home: home,
            serviceType: HMServiceTypeAirPressureSensor,
            characteristicType: HMCharacteristicTypeCurrentAirPressure
        )

        updateTimer = startBackgroundRepeatingTimer(label: "ClimateStatusManager", interval: 60) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.update()
            }
        }
    }

    private func stopUpdating() {
        updateTimer?.cancel()
        updateTimer = nil
    }

    private func update() async {
        async let temperatureValue = temperature?.value
        async let humidityValue = humidity?.value
        async let airPressureValue = airPressure?.value

        var items: [StatusBarItem] = []

        if let temperatureValue = try? await temperatureValue {
            items.append(.init(
                text: String(format: "%.0f°", temperatureValue),
                symbolName: "thermometer.medium"
            ))
        }

        if let humidityValue = try? await humidityValue {
            items.append(.init(
                text: String(format: "%.0f%%", humidityValue),
                symbolName: "humidity.fill"
            ))
        }

        if let airPressureValue = try? await airPressureValue {
            items.append(.init(
                text: String(format: "%d hPa", Int(airPressureValue / 100)),
                symbolName: "mountain.2.fill"
            ))
        }

        let fixedItems = items

        await MainActor.run {
            statusBarManager.rightItems = fixedItems
        }
    }
}

extension ClimateStatusManager: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        stopUpdating()
        startOrStopUpdating()
    }
}

fileprivate class Characteristic<Value> {
    let home: HMHome
    let serviceType: String
    let characteristicType: String

    init(home: HMHome, serviceType: String, characteristicType: String) {
        self.home = home
        self.serviceType = serviceType
        self.characteristicType = characteristicType
    }

    var value: Value? {
        get async throws {
            guard let characteristic = characteristic else { return nil }
            try await characteristic.readValue()
            return characteristic.value as? Value
        }
    }

    private lazy var service: HMService? = {
        return home.servicesWithTypes([serviceType])?.first
    }()

    private lazy var characteristic: HMCharacteristic? = {
        return service?.characteristics.first { $0.characteristicType == characteristicType }
    }()

}

fileprivate func startBackgroundRepeatingTimer(label: String, interval: TimeInterval, handler: @escaping () -> Void) -> DispatchSourceTimer {
    let queue = DispatchQueue(label: label)
    let timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
    timer.setEventHandler(handler: handler)
    timer.schedule(deadline: .now(), repeating: interval)
    timer.resume()
    return timer
}
