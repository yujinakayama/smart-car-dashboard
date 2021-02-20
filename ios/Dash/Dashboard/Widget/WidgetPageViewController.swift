//
//  WidgetPageViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class WidgetPageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    lazy var widgetViewControllers: [UIViewController] = [
        RearviewWidgetViewController(),
        storyboard!.instantiateViewController(identifier: "AltitudeWidgetViewController"),
    ]

    lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = widgetViewControllers.count
        pageControl.currentPageIndicatorTintColor = .secondaryLabel
        pageControl.pageIndicatorTintColor = .quaternaryLabel
        pageControl.hidesForSinglePage = true

        view.addSubview(pageControl)

        pageControl.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            view.bottomAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 4)
        ])

        return pageControl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        dataSource = self

        view.translatesAutoresizingMaskIntoConstraints = false
        _ = pageControl
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // We should not do this in viewDidLoad()
        // because setViewControllers() invokes the view controller's viewWillAppear() unintentionally.
        if viewControllers == nil || viewControllers!.isEmpty {
            setViewControllers([widgetViewControllers.first!], direction: .forward, animated: false)
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let nextIndex = widgetViewControllers.firstIndex(of: viewController) else { return nil }
        return widgetViewController(at: nextIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let previousIndex = widgetViewControllers.firstIndex(of: viewController) else { return nil }
        return widgetViewController(at: previousIndex + 1)
    }

    private func widgetViewController(at index: Int) -> UIViewController? {
        let indexRange = widgetViewControllers.startIndex..<widgetViewControllers.endIndex

        if indexRange.contains(index) {
            return widgetViewControllers[index]
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let currentViewController = viewControllers?.first else { return }
        guard let index = widgetViewControllers.firstIndex(of: currentViewController) else { return }
        pageControl.currentPage = index
    }
}
