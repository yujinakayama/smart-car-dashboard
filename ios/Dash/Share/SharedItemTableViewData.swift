//
//  SharedItemTableViewData.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/05.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class SharedItemTableViewData {
    struct Section {
        let date: Date
        let items: [SharedItemProtocol]
    }

    let sections: [Section]

    init() {
        sections = []
    }

    init(firestoreSnapshot: QuerySnapshot) {
        let items: [SharedItemProtocol] = firestoreSnapshot.documents.compactMap({ (document) in
            do {
                return try SharedItem.makeItem(document: document)
            } catch {
                logger.error(error)
                return nil
            }
        })

        let itemsByDate = Dictionary<Date, [SharedItemProtocol]>(grouping: items) { (item) in
            var components = Calendar.current.dateComponents(in: TimeZone.current, from: item.creationDate!)
            components.hour = nil
            components.minute = nil
            components.second = nil
            components.nanosecond = nil
            return components.date!
        }

        var sections: [Section] = []

        for date in itemsByDate.keys.sorted().reversed() {
            let section = Section(date: date, items: itemsByDate[date]!)
            sections.append(section)
        }

        self.sections = sections
    }

    func item(for indexPath: IndexPath) -> SharedItemProtocol {
        return sections[indexPath.section].items[indexPath.row]
    }

    func item(for identifier: SharedItem.Identifier) -> SharedItemProtocol? {
        return itemsByIdentifier[identifier]
    }

    var items: [SharedItemProtocol] {
        return sections.flatMap { $0.items }
    }

    private lazy var itemsByIdentifier = items.reduce(into: Dictionary<SharedItem.Identifier, SharedItemProtocol>()) { (dictionary, item) in
        dictionary[item.identifier] = item
    }
}
