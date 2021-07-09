//
//  OfficialParkingInformationWebViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/09.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

class OfficialParkingInformationWebViewController: WebViewController {
    override init() {
        super.init()
        preferredContentMode = .mobile
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToParkingInformation()
    }

    func scrollToParkingInformation() {
        scrollToElement(containing: "駐車場", highlight: true)
    }

    private func scrollToElement(containing text: String, highlight: Bool = false) {
        let script = """
            function scrollTo(y, duration) {
                let initialTimestamp = null;

                function step(currentTimestamp) {
                    if (initialTimestamp) {
                        const progressRate = (currentTimestamp - initialTimestamp) / duration;

                        if (progressRate >= 1) {
                          document.scrollingElement.scrollTop = y;
                          return;
                        }

                        const yRate = (-Math.cos(progressRate * Math.PI) + 1) / 2
                        document.scrollingElement.scrollTop = y * yRate;
                    } else {
                      initialTimestamp = currentTimestamp;
                    }

                    window.requestAnimationFrame(step);
                }

                window.requestAnimationFrame(step);
            }

            const xpath = `//*[text()[contains(., "${searchText}")]]`; // TODO: Escape searchText properly
            const element = document.evaluate(xpath, document.body, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;

            if (!element) {
                return;
            }

            const absoluteElementTop = element.getBoundingClientRect().top + window.pageYOffset;
            scrollTo(absoluteElementTop - (window.innerHeight / 4), 500);

            if (highlight) {
                element.style.backgroundColor = '#fffd54';
                element.style.borderRadius = '0.2em';
            }
        """

        webView.callAsyncJavaScript(
            script,
            arguments: ["searchText": text, "highlight": highlight],
            in: nil,
            in: .defaultClient)
        { (result) in
            switch result {
            case .success:
                break
            case .failure(let error):
                logger.error(error)
            }
        }
    }
}
