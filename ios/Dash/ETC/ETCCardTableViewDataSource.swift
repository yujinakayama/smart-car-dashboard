//
//  ETCCardTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestore

@MainActor
class ETCCardTableViewDataSource: UITableViewDiffableDataSource<ETCCardTableViewDataSource.Section, UUID> {
    static let allPaymentsRowUUID = UUID(uuidString: "C0FB3D15-A402-46E7-81C1-841562285C4E")!

    private var cards: [ETCCard] = []
    private var querySubscription: FirestoreQuery<ETCCard>.Subscription!

    init(database: ETCDatabase, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Section, UUID>.CellProvider) {
        super.init(tableView: tableView, cellProvider: cellProvider)

        querySubscription = database.allCards.subscribeToUpdates { [weak self] (result) in
            self?.onUpdate(result: result)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(deviceManagerDidUpdateCurrentCard), name: .ETCDeviceManagerDidUpdateCurrentCard, object: nil)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        switch Section(sectionIndex) {
        case .allPayments:
            return nil
        case .cards:
            return String(localized: "Cards")
        default:
            return nil
        }
    }

    func card(for indexPath: IndexPath) -> ETCCard? {
        switch Section(indexPath) {
        case .allPayments:
            return nil
        case .cards:
            return cards[indexPath.row]
        default:
            return nil
        }
    }

    private func onUpdate(result: Result<FirestoreQuery<ETCCard>.Subscription.Update, Error>) {
        let isInitialUpdate = cards.isEmpty

        do {
            let update = try result.get()
            let cards = update.documents
            let dataSourceSnapshot = Self.makeDataSourceSnapshot(cards: cards, changes: update.changes)

            DispatchQueue.main.async {
                self.cards = cards
                self.apply(dataSourceSnapshot, animatingDifferences: !isInitialUpdate)
            }
        } catch {
            logger.error(error)
        }
    }

    private static func makeDataSourceSnapshot(cards: [ETCCard], changes: [DocumentChange]) -> NSDiffableDataSourceSnapshot<Section, UUID> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, UUID>()

        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([Self.allPaymentsRowUUID], toSection: .allPayments)
        snapshot.appendItems(cards.map { $0.uuid }, toSection: .cards)

        let modifiedCardIndices = changes.filter { $0.type == .modified }.map { Int($0.newIndex) }
        let modifiedCardUUIDs = modifiedCardIndices.map { cards[$0].uuid }
        snapshot.reloadItems(modifiedCardUUIDs)

        return snapshot
    }

    @objc private func deviceManagerDidUpdateCurrentCard() {
        var snapshot = snapshot()
        snapshot.reloadSections([Section.cards])
        apply(snapshot, animatingDifferences: false)
    }
}

extension ETCCardTableViewDataSource {
    enum Section: Int, CaseIterable {
        case allPayments = 0
        case cards

        init?(_ sectionIndex: Int) {
            if let section = Section(rawValue: sectionIndex) {
                self = section
            } else {
                return nil
            }
        }

        init?(_ indexPath: IndexPath) {
            if let section = Section(rawValue: indexPath.section) {
                self = section
            } else {
                return nil
            }
        }
    }
}
