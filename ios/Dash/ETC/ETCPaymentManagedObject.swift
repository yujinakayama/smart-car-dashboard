//
//  ETCPaymentManagedObject+CoreDataProperties.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/12.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//
//

import Foundation
import CoreData

@objc(ETCPaymentManagedObject)
class ETCPaymentManagedObject: NSManagedObject, ETCPaymentProtocol {
    static let entityName = "ETCPayment"

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ETCPaymentManagedObject> {
        return NSFetchRequest<ETCPaymentManagedObject>(entityName: entityName)
    }

    @NSManaged var amount: Int32
    @NSManaged var date: Date
    @NSManaged var entranceTollboothID: String
    @NSManaged var exitTollboothID: String
    @NSManaged var card: ETCCardManagedObject?

    var vehicleClassification: VehicleClassification {
        get {
            return VehicleClassification(rawValue: vehicleClassificationRawValue)!
        }

        set {
            vehicleClassificationRawValue = newValue.rawValue
        }
    }

    private var vehicleClassificationRawValue: Int16 {
        get {
            return primitiveValue(forKey: "vehicleClassification") as! Int16
        }

        set {
            setPrimitiveValue(newValue, forKey: "vehicleClassification")
        }
    }

    lazy var entranceTollbooth: Tollbooth? = Tollbooth.findTollbooth(id: entranceTollboothID)
    lazy var exitTollbooth: Tollbooth? = Tollbooth.findTollbooth(id: exitTollboothID)

    @objc var sectionIdentifier: Date {
        var components = Calendar.current.dateComponents(in: TimeZone.current, from: date)
        components.hour = nil
        components.minute = nil
        components.second = nil
        return components.date!
    }
}
