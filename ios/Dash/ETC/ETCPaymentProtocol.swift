//
//  ETCPaymentProtocol.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/10/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

protocol ETCPaymentProtocol {
    var amount: Int32 { get }
    var date: Date { get }
    var entranceTollboothID: String { get }
    var exitTollboothID: String { get }
    var vehicleClassification: VehicleClassification { get }
    var entranceTollbooth: Tollbooth?  { get }
    var exitTollbooth: Tollbooth?  { get }
}
