//
//  OfficialParkingInformationWebViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/09.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import ParkingSearchKit
import WebKit

class OfficialParkingInformationWebViewController: WebViewController {
    let officialParkingSearch: OfficialParkingSearch

    var hasHighlightedElementDescribingParking = false

    init(officialParkingSearch: OfficialParkingSearch) {
        self.officialParkingSearch = officialParkingSearch
        super.init(webView: officialParkingSearch.webView, contentMode: .mobile)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !hasHighlightedElementDescribingParking {
            highlightElementDescribingParking()
            hasHighlightedElementDescribingParking = true
        }
    }

    private func highlightElementDescribingParking() {
        let function = """
            (element) => {
                function highlight(element) {
                    element.style.color = '#000000';
                    element.style.backgroundColor = '#fffd54';
                    element.style.borderRadius = '0.2em';
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

                if (!element) {
                    return;
                }

                highlight(element);

                const absoluteElementTop = element.getBoundingClientRect().top + window.pageYOffset;
                scrollTo(absoluteElementTop - (window.innerHeight / 4), 500);
            }
        """

        officialParkingSearch.evaluateJavaScriptWithElementDescribingParking(function) { (result) in
            switch result {
            case .success:
                break
            case .failure(let error):
                logger.error(error)
            }
        }
    }
}
