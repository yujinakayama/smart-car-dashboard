//
//  ETCPaymentDatabase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/12.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreData

class ETCPaymentDatabase {
    let persistentContainer: NSPersistentContainer

    var available = false

    init(name: String) {
        persistentContainer = NSPersistentContainer(name: name)

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        persistentContainer.persistentStoreDescriptions.forEach { (persistentStoreDescription) in
            persistentStoreDescription.shouldAddStoreAsynchronously = true
        }
    }

    func loadPersistantStores(completionHandler: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        persistentContainer.loadPersistentStores(completionHandler: completionHandler)
    }

    func performBackgroundTask(block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    func makeFetchRequest() -> NSFetchRequest<ETCPaymentManagedObject> {
        return NSFetchRequest<ETCPaymentManagedObject>(entityName: ETCPaymentManagedObject.entityName)
    }

    func insert(payment: ETCPayment, unlessExistsIn context: NSManagedObjectContext) throws -> ETCPaymentManagedObject? {
        if try checkExistence(of: payment, in: context) {
            return nil
        }

        let managedObject = insert(payment: payment, into: context)
        try context.save()
        return managedObject
    }

    func insert(payment: ETCPayment, into context: NSManagedObjectContext) -> ETCPaymentManagedObject {
        let managedObject = insertNewETCPayment(into: context)
        managedObject.amount = payment.amount
        managedObject.date = payment.date as NSDate
        managedObject.entranceTollboothID = payment.entranceTollboothID
        managedObject.exitTollboothID = payment.exitTollboothID
        managedObject.vehicleClassification = payment.vehicleClassification
        return managedObject
    }

    func insertNewETCPayment(into context: NSManagedObjectContext) -> ETCPaymentManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: ETCPaymentManagedObject.entityName, into: context) as! ETCPaymentManagedObject
    }

    func checkExistence(of payment: ETCPayment, in context: NSManagedObjectContext) throws -> Bool {
        let fetchRequest = makeFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", payment.date as NSDate)
        return try context.count(for: fetchRequest) > 0
    }

    func deleteAll() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: ETCPaymentManagedObject.entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try persistentContainer.viewContext.execute(deleteRequest)
    }
}
