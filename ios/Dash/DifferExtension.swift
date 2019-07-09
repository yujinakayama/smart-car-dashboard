//
//  DifferExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/06/19.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import Differ

extension UITableView {
    // Modified version of Differ's animateRowChanges() without moves (i.e. only deletion and insertions).
    func animateRowChangesWithoutMoves<T: Collection>(
        oldData: T,
        newData: T,
        deletionAnimation: DiffRowAnimation = .automatic,
        insertionAnimation: DiffRowAnimation = .automatic
    ) where T.Element: Equatable
    {
        let diff = oldData.diff(newData)

        var deletions: [IndexPath] = []
        var insertions: [IndexPath] = []

        diff.forEach({ (element) in
            switch element {
            case let .delete(at):
                deletions.append(IndexPath(row: at, section: 0))
            case let .insert(at):
                insertions.append(IndexPath(row: at, section: 0))
            }
        })

        beginUpdates()
        deleteRows(at: deletions, with: deletionAnimation)
        insertRows(at: insertions, with: insertionAnimation)
        endUpdates()
    }
}
