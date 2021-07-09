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
            function getElements(xpath) {
                const result = document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);

                const elements = [];

                for (let i = 0; i < result.snapshotLength; i++) {
                    elements.push(result.snapshotItem(i));
                }

                return elements;
            }

            const tagImportance = {
                H1: 100,
                H2: 99,
                H3: 98,
                H4: 97,
                H5: 96,
                H6: 95,
                DIV: 10,
                A: -1,
            };

            function importanceOf(element) {
                return tagImportance[element.tagName] || 0;
            }

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

            const xpath = `//body//*[text()[contains(., "${searchText}")]]`; // TODO: Escape searchText properly
            const elements = getElements(xpath);
            elements.sort((a, b) => { return importanceOf(b) - importanceOf(a) });
            const bestElement = elements[0];

            if (!bestElement) {
                return;
            }

            const absoluteElementTop = bestElement.getBoundingClientRect().top + window.pageYOffset;
            scrollTo(absoluteElementTop - (window.innerHeight / 4), 500);

            if (highlight) {
                bestElement.style.backgroundColor = '#fffd54';
                bestElement.style.borderRadius = '0.2em';
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
