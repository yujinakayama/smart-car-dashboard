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

    private var justChangedFromUI = false
    
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

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return Section(indexPath) == .cards
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard Section(sourceIndexPath) == .cards else { return }

        justChangedFromUI = true
        
        var reorderedCards = cards
        let movedCard = reorderedCards.remove(at: sourceIndexPath.row)
        reorderedCards.insert(movedCard, at: destinationIndexPath.row)

        let batch = self.querySubscription.query.firestore.batch()
        for (index, card) in reorderedCards.enumerated() {
            batch.updateData([ETCCard.orderFieldKey: UInt(index + 1)], forDocument: card.documentReference)
        }
        batch.commit()
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

                if self.justChangedFromUI {
                    self.justChangedFromUI = false
                    // Disable diff calculation and animation
                    // because the table view is already showing the expected list
                    self.applySnapshotUsingReloadData(dataSourceSnapshot)
                } else {
                    self.apply(dataSourceSnapshot, animatingDifferences: !isInitialUpdate)
                }
            }
        } catch {
            logger.error(error)
        }
    }

    private static func makeDataSourceSnapshot(cards: [ETCCard], changes: [FirestoreDocumentChange]) -> NSDiffableDataSourceSnapshot<Section, UUID> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, UUID>()

        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([Self.allPaymentsRowUUID], toSection: .allPayments)
        snapshot.appendItems(cards.map { $0.uuid }, toSection: .cards)

        let updatedCardUUIDs = changes.compactMap { change in
            if case .update(let index) = change {
                return cards[Int(index)].uuid
            } else {
                return nil
            }
        }

        snapshot.reconfigureItems(updatedCardUUIDs)

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
