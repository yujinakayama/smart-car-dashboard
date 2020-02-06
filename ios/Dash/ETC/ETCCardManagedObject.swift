//
//  ETCCardManagedObject+CoreDataClass.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/13.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//
//

import Foundation
import CoreData

@objc(ETCCardManagedObject)
class ETCCardManagedObject: NSManagedObject {
    static let entityName = "ETCCard"

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ETCCardManagedObject> {
        return NSFetchRequest<ETCCardManagedObject>(entityName: entityName)
    }

    @NSManaged public var uuid: UUID
    @NSManaged public var name: String?
    @NSManaged public var payments: Set<ETCPaymentManagedObject>

    var brand: ETCCardBrand {
        get {
            return ETCCardBrand(rawValue: brandRawValue)!
        }

        set {
            brandRawValue = newValue.rawValue
        }
    }

    private var brandRawValue: Int16 {
        get {
            return primitiveValue(forKey: "brand") as! Int16
        }

        set {
            setPrimitiveValue(newValue, forKey: "brand")
        }
    }

    var tentativeName: String {
        return name ?? "Unnamed Card"
    }
}

enum ETCCardBrand: Int16 {
    case unknown = 0
    case visa
    case mastercard
}
