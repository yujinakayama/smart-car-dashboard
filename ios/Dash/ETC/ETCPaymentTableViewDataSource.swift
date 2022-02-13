//
//  ETCPaymentTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestore

@MainActor
class ETCPaymentTableViewDataSource: UITableViewDiffableDataSource<Date, Date> {
    private var tableViewData = TableViewData()
    private var querySubscription: FirestoreQuery<ETCPayment>.PaginatedSubscription!

    init(database: ETCDatabase, card: ETCCard?, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Date, Date>.CellProvider) throws {
        super.init(tableView: tableView, cellProvider: cellProvider)

        let query: FirestoreQuery<ETCPayment>

        if let card = card {
            query = try database.payments(for: card)
        } else {
            query = database.allPayments
        }

        querySubscription = query.subscribeToUpdates(documentCountPerPage: 20) { [weak self] (result) in
            self?.onUpdate(result: result)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        let section = tableViewData.sections[sectionIndex]
        return sectionHeaderDateFormatter.string(from: section.date)
    }

    private let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    var isLoadingNewPage: Bool {
        get async {
            return await querySubscription.isLoadingNewPage
        }
    }

    func incrementPage() async {
        await querySubscription.incrementPage()
    }

    func payment(for indexPath: IndexPath) -> ETCPayment? {
        return tableViewData.sections[indexPath.section].payments[indexPath.row]
    }

    private func onUpdate(result: Result<FirestoreQuery<ETCPayment>.PaginatedSubscription.Update, Error>) {
        do {
            let update = try result.get()
            tableViewData = TableViewData(payments: update.documents)
            let dataSourceSnapshot = Self.makeDataSourceSnapshot(tableViewData: tableViewData, changes: update.changes)

            DispatchQueue.main.async {
                self.apply(dataSourceSnapshot, animatingDifferences: !update.isCausedByPagination)
            }
        } catch {
            logger.error(error)
        }
    }

    private static func makeDataSourceSnapshot(tableViewData: TableViewData, changes: [DocumentChange]) -> NSDiffableDataSourceSnapshot<Date, Date> {
        var snapshot = NSDiffableDataSourceSnapshot<Date, Date>()

        snapshot.appendSections(tableViewData.sections.map { $0.date })

        for section in tableViewData.sections {
            snapshot.appendItems(section.payments.map { $0.exitDate }, toSection: section.date)
        }

        let modifiedPaymentIndices = changes.filter { $0.type == .modified }.map { Int($0.newIndex) }
        let modifiedPaymentDates = modifiedPaymentIndices.map { tableViewData.payments[$0].exitDate }
        snapshot.reloadItems(modifiedPaymentDates)

        return snapshot
    }
}

extension ETCPaymentTableViewDataSource {
    private class TableViewData {
        struct Section {
            let date: Date
            let payments: [ETCPayment]
        }

        let sections: [Section]

        init() {
            sections = []
        }

        init(payments: [ETCPayment]) {
            let paymentsByDate = Dictionary<Date, [ETCPayment]>(grouping: payments) { (payment) in
                var components = Calendar.current.dateComponents(in: TimeZone.current, from: payment.exitDate)
                components.hour = nil
                components.minute = nil
                components.second = nil
                components.nanosecond = nil
                return components.date!
            }

            self.sections = paymentsByDate.keys.sorted().reversed().map { (date) in
                Section(date: date, payments: paymentsByDate[date]!)
            }
        }

        lazy var payments: [ETCPayment] = {
            return sections.flatMap { $0.payments }
        }()
    }
}
