//
//  ETCDataStore.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/12.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreData

enum ETCDataStoreError: Error {
    case currentCardMustBeSet
}

class ETCDataStore {
    let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    lazy var backgroundContext = persistentContainer.newBackgroundContext()

    var currentCard: ETCCardManagedObject?

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
        backgroundContext.perform { [unowned self] in
            block(self.backgroundContext)
        }
    }

    func insert(payment: ETCPayment, unlessExistsIn context: NSManagedObjectContext) throws -> ETCPaymentManagedObject? {
        if try checkExistence(of: payment, in: context) {
            return nil
        }

        return try insert(payment: payment, into: context)
    }

    func insert(payment: ETCPayment, into context: NSManagedObjectContext) throws -> ETCPaymentManagedObject {
        guard let card = currentCard else {
            throw ETCDataStoreError.currentCardMustBeSet
        }

        let managedObject = insertNewPayment(into: context)
        managedObject.amount = payment.amount
        managedObject.date = payment.date
        managedObject.entranceTollboothID = payment.entranceTollboothID
        managedObject.exitTollboothID = payment.exitTollboothID
        managedObject.vehicleClassification = payment.vehicleClassification
        managedObject.card = card
        return managedObject
    }

    func insertNewPayment(into context: NSManagedObjectContext) -> ETCPaymentManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: ETCPaymentManagedObject.entityName, into: context) as! ETCPaymentManagedObject
    }

    func checkExistence(of payment: ETCPayment, in context: NSManagedObjectContext) throws -> Bool {
        let fetchRequest: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", payment.date as NSDate)
        return try context.count(for: fetchRequest) > 0
    }

    func findOrInsertCard(uuid: UUID, in context: NSManagedObjectContext) throws -> ETCCardManagedObject {
        if let card = try findCard(uuid: uuid, in: context) {
            return card
        }

        let card = insertNewCard(into: context)
        card.uuid = uuid
        return card
    }

    func findCard(uuid: UUID, in context: NSManagedObjectContext) throws -> ETCCardManagedObject? {
        let request: NSFetchRequest<ETCCardManagedObject> = ETCCardManagedObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1
        let cards = try context.fetch(request)
        return cards.first
    }

    func insertNewCard(into context: NSManagedObjectContext) -> ETCCardManagedObject {
        return NSEntityDescription.insertNewObject(forEntityName: ETCCardManagedObject.entityName, into: context) as! ETCCardManagedObject
    }
}
