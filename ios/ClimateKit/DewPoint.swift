//
//  DewPoint.swift
//  ClimateKit
//
//  Created by Yuji Nakayama on 2024/01/31.
//  Copyright © 2024 Yuji Nakayama. All rights reserved.
//

import Foundation

fileprivate let b = 17.62
fileprivate let c = 243.12

public func dewPointAt(temperature: DegreeCelsius, humidity: RelativeHumidity) -> DegreeCelsius {
    // https://chat.openai.com/share/f3e876b4-ef45-4651-a18e-30dcb21e1971
    let gamma = (b * temperature) / (c + temperature) + log(humidity)
    return (c * gamma) / (b - gamma)
}
