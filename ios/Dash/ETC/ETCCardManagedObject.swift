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

    @NSManaged public var uuid: UUID
    @NSManaged public var name: String
    @NSManaged public var payments: NSSet
}
