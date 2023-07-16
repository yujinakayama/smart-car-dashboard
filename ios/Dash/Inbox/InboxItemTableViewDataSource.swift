//
//  InboxItemTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestore

@MainActor
class InboxItemTableViewDataSource: UITableViewDiffableDataSource<Date, String> {
    private var querySubscription: FirestoreQuery<InboxItemProtocol>.PaginatedSubscription!

    private var tableViewData = TableViewData()

    init(database: InboxItemDatabase, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Date, String>.CellProvider) {
        super.init(tableView: tableView, cellProvider: cellProvider)

        querySubscription = database.allItems.subscribeToUpdates(documentCountPerPage: 20) { [weak self] (result) in
            self?.onUpdate(result: result)
        }

        // To update relative dates in section headers when the current date changed
        NotificationCenter.default.addObserver(tableView, selector: #selector(tableView.reloadData), name: UIApplication.significantTimeChangeNotification, object: nil)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        let section = tableViewData.sections[sectionIndex]
        return sectionHeaderDateFormatter.string(from: section.date)
    }

    private lazy var sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Disable "Swipe to Delete" since unnintentional swipe operations may be made
        // in shaky car environment
        return tableView.isEditing
    }

    var isEmpty: Bool {
        return tableViewData.sections.isEmpty
    }

    var isLoadingNewPage: Bool {
        get async {
            return await querySubscription.isLoadingNewPage
        }
    }

    func incrementPage() async {
        await querySubscription.incrementPage()
    }

    func item(for indexPath: IndexPath) -> InboxItemProtocol {
        return tableViewData.sections[indexPath.section].items[indexPath.row]
    }

    private func onUpdate(result: Result<FirestoreQuery<InboxItemProtocol>.PaginatedSubscription.Update, Error>) {
        do {
            let update = try result.get()
            let tableViewData = TableViewData(items: update.documents)
            let dataSourceSnapshot = Self.makeDataSourceSnapshot(tableViewData: tableViewData, changes: update.changes)

            DispatchQueue.main.async {
                self.tableViewData = tableViewData
                self.apply(dataSourceSnapshot, animatingDifferences: !update.isCausedByPagination)
            }
        } catch {
            logger.error(error)
        }
    }

    private static func makeDataSourceSnapshot(tableViewData: TableViewData, changes: [FirestoreDocumentChange<InboxItemProtocol>]) -> NSDiffableDataSourceSnapshot<Date, String> {
        var snapshot = NSDiffableDataSourceSnapshot<Date, String>()

        snapshot.appendSections(tableViewData.sections.map { $0.date })

        for section in tableViewData.sections {
            snapshot.appendItems(section.items.map { $0.identifier }, toSection: section.date)
        }

        let updatedItemIdentifiers = changes.compactMap { change in
            switch change.type {
            case .modification:
                return change.document.identifier
            default:
                return nil
            }
        }

        snapshot.reconfigureItems(updatedItemIdentifiers)

        return snapshot
    }
}

extension InboxItemTableViewDataSource {
    private class TableViewData {
        struct Section {
            let date: Date
            let items: [InboxItemProtocol]
        }

        let sections: [Section]

        init() {
            sections = []
        }

        init(items: [InboxItemProtocol]) {
            let itemsByDate = Dictionary<Date, [InboxItemProtocol]>(grouping: items) { (item) in
                var components = Calendar.current.dateComponents(in: TimeZone.current, from: item.creationDate!)
                components.hour = nil
                components.minute = nil
                components.second = nil
                components.nanosecond = nil
                return components.date!
            }

            self.sections = itemsByDate.keys.sorted().reversed().map { (date) in
                Section(date: date, items: itemsByDate[date]!)
            }
        }

        lazy var items: [InboxItemProtocol] = {
            return sections.flatMap { $0.items }
        }()
    }
}
