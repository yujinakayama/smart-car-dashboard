//
//  SharedItemTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class SharedItemTableViewDataSource: UITableViewDiffableDataSource<Date, SharedItem.Identifier> {
    var titleForHeaderInSection: ((UITableView, Int) -> String?)?
    var commitForRowAt: ((UITableViewCell.EditingStyle, IndexPath) -> Void)?

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let titleForHeaderInSection = titleForHeaderInSection {
            return titleForHeaderInSection(tableView, section)
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Disable "Swipe to Delete" since unnintentional swipe operations may be made
        // in shaky car environment
        return tableView.isEditing
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        commitForRowAt?(editingStyle, indexPath)
    }
}
