//
//  RoundButton.swift
//  RoundButton
//
//  Created by Lawrence F MacFadyen on 2016-03-16.
//  Copyright © 2016 LawrenceM. All rights reserved.
//

import UIKit

@IBDesignable public class RoundButton: UIButton {
    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 0.5 * bounds.size.width
        clipsToBounds = true
    }
}
