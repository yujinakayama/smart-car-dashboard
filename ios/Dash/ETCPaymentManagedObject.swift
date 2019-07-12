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
class ETCPaymentManagedObject: NSManagedObject {
    static let entityName = "ETCPayment"

    class func insertNewObject(from payment: ETCPayment, into context: NSManagedObjectContext) -> ETCPaymentManagedObject {
        let managedObject = insertNewObject(into: context)
        managedObject.amount = payment.amount
        managedObject.date = payment.date as NSDate
        managedObject.entranceTollboothID = payment.entranceTollboothID
        managedObject.exitTollboothID = payment.exitTollboothID
        managedObject.vehicleClassification = payment.vehicleClassification.rawValue
        return managedObject
    }

    class func insertNewObject(into context: NSManagedObjectContext) -> ETCPaymentManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: ETCPaymentManagedObject.entityName, into: context) as! ETCPaymentManagedObject
    }

    class func fetchRequest() -> NSFetchRequest<ETCPaymentManagedObject> {
        return NSFetchRequest<ETCPaymentManagedObject>(entityName: ETCPaymentManagedObject.entityName)
    }

    @NSManaged var amount: Int32
    @NSManaged var date: NSDate
    @NSManaged var entranceTollboothID: String
    @NSManaged var exitTollboothID: String
    @NSManaged var vehicleClassification: Int16

    lazy var entranceTollbooth: Tollbooth? = Tollbooth.findTollbooth(id: entranceTollboothID)
    lazy var exitTollbooth: Tollbooth? = Tollbooth.findTollbooth(id: exitTollboothID)
}
