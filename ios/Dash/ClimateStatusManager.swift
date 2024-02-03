//
//  ClimateStatusManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2024/01/20.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation
import HomeKit
import ClimateKit

// Custom HomeKit types
fileprivate let HMServiceTypeAirPressureSensor         = "00010000-3420-4EDC-90D1-E326457409CF"
fileprivate let HMCharacteristicTypeCurrentAirPressure = "00000001-3420-4EDC-90D1-E326457409CF"

class ClimateStatusManager: NSObject {
    static let requiredCharacteristicTypesBySlot: [DashStatusBarSlot: [String]] = [
        .temperature: [HMCharacteristicTypeCurrentTemperature],
        .humidity: [HMCharacteristicTypeCurrentRelativeHumidity],
        .dewPoint: [HMCharacteristicTypeCurrentTemperature, HMCharacteristicTypeCurrentRelativeHumidity],
        .airPressure: [HMCharacteristicTypeCurrentAirPressure],
    ]

    let statusBarManager: StatusBarManager<DashStatusBarSlot>
    let homeName: String
    let enabledSlots: [DashStatusBarSlot]

    let homeManager = HMHomeManager()

    private var monitoredCharacteristics: [String: HMCharacteristic] = [:]

    init(statusBarManager: StatusBarManager<DashStatusBarSlot>, homeName: String, enabledSlots: [DashStatusBarSlot]) {
        self.statusBarManager = statusBarManager
        self.homeName = homeName
        self.enabledSlots = enabledSlots

        super.init()

        homeManager.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(statusBarManagerDidUpdateVisibility), name: .StatusBarManagerDidUpdateVisibility, object: nil)
    }

    private var home: HMHome? {
        return homeManager.homes.first { $0.name == homeName }
    }

    @objc func statusBarManagerDidUpdateVisibility() {
        startOrStopMonitoring()
    }

    private func startOrStopMonitoring() {
        if statusBarManager.canShowItems {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard let home = home else { return }

        let requiredCharacteristicTypes = enabledSlots.flatMap { (slot) in
            Self.requiredCharacteristicTypesBySlot[slot] ?? []
        }

        for characteristicType in Set(requiredCharacteristicTypes) {
            startMonitoring(characteristicType, in: home)
        }
    }

    private func startMonitoring(_ characteristicType: String, in home: HMHome) {
        guard let characteristic = home.findCharacteristic(type: characteristicType),
              let accessory = characteristic.service?.accessory
        else { return }

        accessory.delegate = self

        characteristic.enableNotification(true) { (error) in
            logger.error(error)
        }

        monitoredCharacteristics[characteristicType] = characteristic

        Task {
            await updateItem(for: characteristic)
        }
    }

    private func stopMonitoring() {
        for (_, characteristic) in monitoredCharacteristics {
            characteristic.enableNotification(false) { (error) in
                logger.error(error)
            }
        }

        monitoredCharacteristics.removeAll()
    }

    @MainActor
    private func updateItem(for characteristic: HMCharacteristic) {
        switch characteristic.characteristicType {
        case HMCharacteristicTypeCurrentTemperature:
            updateTemperatureItem()
            updateDewPointItem()
        case HMCharacteristicTypeCurrentRelativeHumidity:
            updateHumidityItem()
            updateDewPointItem()
        case HMCharacteristicTypeCurrentAirPressure:
            updateAirPressureItem()
        default:
            break
        }
    }

    private func updateTemperatureItem() {
        if enabledSlots.contains(.temperature),
           let characteristic = monitoredCharacteristics[HMCharacteristicTypeCurrentTemperature],
           let value: Double = valueOf(characteristic)
        {
            let item = StatusBarItem(
                text: String(format: "%.0f", round(value)),
                unit: "℃",
                symbolName: "thermometer.medium"
            )
            statusBarManager.setItem(item, for: .temperature)
        } else {
            statusBarManager.removeItem(for: .temperature)
        }
    }

    private func updateHumidityItem() {
        if enabledSlots.contains(.humidity),
           let characteristic = monitoredCharacteristics[HMCharacteristicTypeCurrentRelativeHumidity],
           let value: Double = valueOf(characteristic)
        {
            let item = StatusBarItem(
                text: String(format: "%.0f", round(value)),
                unit: "%",
                symbolName: "humidity.fill"
            )
            statusBarManager.setItem(item, for: .humidity)
        } else {
            statusBarManager.removeItem(for: .humidity)
        }
    }

    private func updateAirPressureItem() {
        if enabledSlots.contains(.airPressure),
           let characteristic = monitoredCharacteristics[HMCharacteristicTypeCurrentAirPressure],
           let value: Double = valueOf(characteristic)
        {
            let item = StatusBarItem(
                text: String(format: "%.0f", round(value / 100)),
                unit: "hPa",
                symbolName: "gauge.with.dots.needle.bottom.50percent"
            )
            statusBarManager.setItem(item, for: .airPressure)
        } else {
            statusBarManager.removeItem(for: .airPressure)
        }
    }

    private func updateDewPointItem() {
        if enabledSlots.contains(.dewPoint),
           let temperatureCharacteristic = monitoredCharacteristics[HMCharacteristicTypeCurrentTemperature],
           let humidityCharacteristic = monitoredCharacteristics[HMCharacteristicTypeCurrentRelativeHumidity],
           let temperature: DegreeCelsius = valueOf(temperatureCharacteristic),
           let humidityPercentage: Double = valueOf(humidityCharacteristic)
        {
            let humidity: RelativeHumidity = humidityPercentage / 100

            let item = StatusBarItem(
                text: String(format: "%.0f", round(dewPointAt(temperature: temperature, humidity: humidity))),
                unit: "℃",
                symbolName: "drop.fill"
            )

            statusBarManager.setItem(item, for: .dewPoint)
        } else {
            statusBarManager.removeItem(for: .dewPoint)
        }
    }
}

extension ClimateStatusManager: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        stopMonitoring()
        startOrStopMonitoring()
    }
}

extension ClimateStatusManager: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        Task {
            await updateItem(for: characteristic)
        }
    }

    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task {
            for service in accessory.services {
                for characteristic in service.characteristics {
                    await updateItem(for: characteristic)
                }
            }
        }
    }
}

fileprivate extension HMHome {
    func findCharacteristic(type: String) -> HMCharacteristic? {
        for accessory in accessories {
            for service in accessory.services {
                for characteristic in service.characteristics {
                    if characteristic.characteristicType == type {
                        return characteristic
                    }
                }
            }
        }

        return nil
    }
}

fileprivate func valueOf<Value>(_ characteristic: HMCharacteristic) -> Value? {
    guard let accessory = characteristic.service?.accessory, accessory.isReachable else { return nil }
    return characteristic.value as? Value
}
