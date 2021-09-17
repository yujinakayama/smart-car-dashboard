//
//  SharedItemTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class SharedItemTableViewDataSource: UITableViewDiffableDataSource<Date, String> {
    var data = TableViewData()

    var isEmpty: Bool {
        return data.sections.isEmpty
    }

    lazy var sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        return formatter
    }()

    override init(tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Date, String>.CellProvider) {
        super.init(tableView: tableView, cellProvider: cellProvider)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        let section = data.sections[sectionIndex]
        return sectionHeaderDateFormatter.string(from: section.date)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Disable "Swipe to Delete" since unnintentional swipe operations may be made
        // in shaky car environment
        return tableView.isEditing
    }

    func setItems(_ items: [SharedItemProtocol]) {
        setItems(items, changes: [], animated: false)
    }

    func setItems(_ items: [SharedItemProtocol], changes: [SharedItemDatabase.Change], animated: Bool) {
        data = TableViewData(items: items)
        let dataSourceSnapshot = makeDataSourceSnapshot(data: data, changes: changes)
        apply(dataSourceSnapshot, animatingDifferences: animated)
    }

    private func makeDataSourceSnapshot(data: TableViewData, changes: [SharedItemDatabase.Change]) -> NSDiffableDataSourceSnapshot<Date, String> {
        var snapshot = NSDiffableDataSourceSnapshot<Date, String>()

        snapshot.appendSections(data.sections.map { $0.date })

        for section in data.sections {
            snapshot.appendItems(section.items.map { $0.identifier }, toSection: section.date)
        }

        let modifiedItemIndices = changes.filter { $0.type == .modification }.map { $0.newIndex }
        let modifiedItemIdentifiers = modifiedItemIndices.map { data.items[$0].identifier! }
        snapshot.reloadItems(modifiedItemIdentifiers)

        return snapshot
    }

    func item(for indexPath: IndexPath) -> SharedItemProtocol {
        return data.sections[indexPath.section].items[indexPath.row]
    }
}

extension SharedItemTableViewDataSource {
    class TableViewData {
        struct Section {
            let date: Date
            let items: [SharedItemProtocol]
        }

        let sections: [Section]

        init() {
            sections = []
        }

        init(items: [SharedItemProtocol]) {
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

        var items: [SharedItemProtocol] {
            return sections.flatMap { $0.items }
        }
    }
}
