//
//  ScrollViewPagination.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/02/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import UIKit

class ScrollViewPagination {
    static let bottomInsetForPagination: CGFloat = 200

    let scrollView: UIScrollView

    private var wasAtBottom = false

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    func shouldLoadNextPage() -> Bool {
        let currentBottom = scrollView.contentOffset.y + scrollView.bounds.height
        let maxScrollableBottom = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom
        let isAtBottom = currentBottom >= maxScrollableBottom - Self.bottomInsetForPagination
        let shouldLoadNextPage = isAtBottom && !wasAtBottom
        wasAtBottom = isAtBottom
        return shouldLoadNextPage
    }
}
