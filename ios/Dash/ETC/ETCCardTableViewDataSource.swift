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

    // If true, the current source of truth is UI
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
        do {
            let update = try result.get()

            if justChangedFromUI {
                justChangedFromUI = false
                let snapshot = makeSnapshotForListUpdate(cards: update.documents)

                // Delay reloading a bit so that ongoing UI animation won't be canceled
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.cards = update.documents
                    // Disable diff calculation and animation
                    // because the table view is already showing the expected list
                    self.applySnapshotUsingReloadData(snapshot)
                }
            } else {
                let isInitialUpdate = cards.isEmpty

                // Splitting snapshots for list update (addition, removal, and automatic reordering by identifier diff)
                // and item updates (reconfiguring or reloading each cell)
                // because it seems that calling `snapshot.reconfigureItems()` overwrites internal reordering operation flag
                // and it causes strange broken behavior when reordering cells from UI.
                let snapshotForListUpdate = makeSnapshotForListUpdate(cards: update.documents)
                let snapshotForItemUpdates = makeSnapshotForItemUpdates(baseSnapshot: snapshotForListUpdate, changes: update.changes)

                DispatchQueue.main.async {
                    self.cards = update.documents
                    self.apply(snapshotForListUpdate, animatingDifferences: !isInitialUpdate)
                    self.apply(snapshotForItemUpdates, animatingDifferences: !isInitialUpdate)
                }
            }
        } catch {
            logger.error(error)
        }
    }

    private func makeSnapshotForListUpdate(cards: [ETCCard]) -> NSDiffableDataSourceSnapshot<Section, UUID> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, UUID>()
        snapshot.appendSections(Section.allCases)
        snapshot.appendItems([Self.allPaymentsRowUUID], toSection: .allPayments)
        snapshot.appendItems(cards.map { $0.uuid }, toSection: .cards)
        return snapshot
    }

    private func makeSnapshotForItemUpdates(baseSnapshot: NSDiffableDataSourceSnapshot<Section, UUID>, changes: [FirestoreDocumentChange<ETCCard>]) -> NSDiffableDataSourceSnapshot<Section, UUID> {
        let updatedCardUUIDs = changes.compactMap { change in
            switch change.type {
            case .modification:
                return change.document.uuid
            default:
                return nil
            }
        }

        var snapshot = baseSnapshot
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
