//
//  ViewController.swift
//  ButtonMoveOverlay
//
//  Created by Lawrence F MacFadyen on 2020-05-11.
//  Copyright © 2020 Lawrence F MacFadyen. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var buttonMovable: RoundButton!
    @IBOutlet weak var viewOpening: UIView!
    @IBOutlet weak var viewMessage: UIView!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var buttonCenterX: NSLayoutConstraint!
    @IBOutlet weak var buttonCenterY: NSLayoutConstraint!
    
    // Lazy initialization of maskView, keeping init code out of viewDidLoad
    lazy var maskView: MaskView = {
        // convert viewOpening to viewMaskArea coordinate system
        let openingFrame = viewOpening.convert(viewOpening.bounds, to: self.view)
        let mv = MaskView(frame: self.view.bounds, opening: openingFrame)
        mv.isHidden = true
        mv.closeHandler = { [weak self] () in
            DispatchQueue.main.async {
                self?.closeOverlay()
            }
        }
        return mv
    }()
    
    // Properties for handling button movement
    var boundsHeight = CGFloat(0.0)
    var boundsWidth = CGFloat(0.0)
    var buttonRadius = CGFloat(0.0)
    var buttonCenter = CGPoint()
    var xTransMin = CGFloat(0.0)
    var xTransMax = CGFloat(0.0)
    var yTransMin = CGFloat(0.0)
    var yTransMax = CGFloat(0.0)
    
    @IBAction func slidersPressed(_ sender: Any) {
        if(maskView.isHidden){
            maskView.isHidden = false
        }
    }
    
    @IBAction func buttonTouchUpInside(_ sender: Any) {
        if(!maskView.isHidden) {return}
        // ... normal action if overlay is hidden
        let alertController = UIAlertController(title: "Button", message: "You pressed the button!", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true, completion:nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(maskView) // will lazy initialize maskView
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(ViewController.panButton(_:)))
        buttonMovable.addGestureRecognizer(pan)
        pan.delegate = self
    }
    
    func closeOverlay() {
        maskView.isHidden = true
    }
    
    @objc func panButton(_ gestureRecognizer : UIPanGestureRecognizer) {
        // Get the changes in the X and Y directions in the superview's coordinate
        // space and relative to the start of movement, not compared to the last change
        let translation = gestureRecognizer.translation(in: buttonMovable.superview)
        if gestureRecognizer.state == .began {
            // Use starting button center for applying adjustments as panning is occuring
            // Existing center will reflect centerX/centerY constraint constants
            buttonCenter = buttonMovable.center
        }
        if gestureRecognizer.state == .ended || gestureRecognizer.state == .failed || gestureRecognizer.state == .cancelled{
            // Not moving anymore, so get adjusted x/y, ie. how much the button has moved for x and y
            // since the gesture started
            let adjusted = adjustedTranslation(inPoint: translation)
            // Update constants based on starting constants plus x/y adjustments since started moving
            buttonCenterX.constant = buttonCenterX.constant + adjusted.x
            buttonCenterY.constant = buttonCenterY.constant + adjusted.y
            // Set the new constants in UserDefaults
            UserDefaults.standard.set(buttonCenterX.constant, forKey: KeysButton.centerX)
            UserDefaults.standard.set(buttonCenterY.constant, forKey: KeysButton.centerY)
        }
        else {
            // Button still moving, so get translation from starting position
            // Note that adjustedTranslation will adjust as needed so button stays in opening
            let adjusted = adjustedTranslation(inPoint: translation)
            // Calculate desired center of the button, so if it had moved outside opening, it would
            // have been adjusted to just be at the edges, thus to the user, it never goes beyond opening
            let newCenter = CGPoint(x: buttonCenter.x + adjusted.x, y: buttonCenter.y + adjusted.y)
            // Set current button center to what was calculated - it could match where it moved to
            // or it could be adjusted if it was going beyond the edges of opening space
            buttonMovable.center = newCenter
        }
    }
    
    
    func adjustedTranslation(inPoint: CGPoint) -> CGPoint
    {
        // Get the translation - how much the gesture has moved the button
        // since gesture start, not since last translation
        var xTrans = inPoint.x
        var yTrans = inPoint.y
        
        // The min and max X and Y translations allowed based on the size
        // of the opening space, factoring in button radius, and where the buttonCenter
        // started as beginning of the gesture
        xTransMin = buttonRadius - buttonCenter.x
        xTransMax = boundsWidth - buttonCenter.x - buttonRadius
        yTransMin = buttonRadius - buttonCenter.y
        yTransMax = boundsHeight - buttonCenter.y - buttonRadius
        
        // Check actual translation with min/max values and adjust if necessary
        // to keep button within required space
        if(xTrans <= xTransMin) {
            xTrans = xTransMin
        }
        if(xTrans >= xTransMax) {
            xTrans = xTransMax
        }
        
        if(yTrans <= yTransMin) {
            yTrans = yTransMin
        }
        if(yTrans >= yTransMax) {
            yTrans = yTransMax
        }
        // Return the adjusted translation CGPoint that keeps button in opening
        let result = CGPoint(x: xTrans, y: yTrans)
        return result
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            if (!maskView.isHidden) {return true}
            return false
        }
        return true
    }
    
    override func viewDidLayoutSubviews() {
        setupButton()
    }
    
    func setupButton(){
        // set X and Y to point center of view
        boundsHeight = viewOpening.bounds.height
        boundsWidth = viewOpening.bounds.width
        buttonRadius = buttonMovable.bounds.width/2
        
        var x = CGFloat(0)
        var y = CGFloat(0)
        
        // check values from defaults and change if they are there
        if let centerX = UserDefaults.standard.object(forKey: KeysButton.centerX) as? CGFloat {
            x = centerX
        }
        if let centerY = UserDefaults.standard.object(forKey: KeysButton.centerY) as? CGFloat {
            y = centerY
        }
        
        // set button center initially
        buttonCenterX.constant = x
        buttonCenterY.constant = y
    }
    
}

class MaskView: UIView {
    let opening: CGRect
    
    var closeHandler: () -> Void = {}
    
    required init?(coder aDecoder: NSCoder) {
        preconditionFailure("Cannot initialize from coder")
    }
    
    init(frame: CGRect, opening: CGRect) {
        self.opening = opening
        super.init(frame: frame)
        customInit()
    }
    
    func customInit() {
        
        // overlay color
        let color = UIColor.label
        self.backgroundColor = color.withAlphaComponent(0.6)
        // make the overlay and opening
        self.configureMask()
        
        // Done button on the overlay to close it
        let button = UIButton()
        button.setTitle("Done", for: .normal)
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 40)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        
        let centerX = self.bounds.width/2
        let buttonLocation = CGPoint(x: centerX, y: self.bounds.height * 0.35)
        button.center = buttonLocation
        button.addTarget(self, action: #selector(donePressed(_:)), for: .touchUpInside)
        self.addSubview(button)
        
        // label for user instructions
        let label = PaddedLabel(frame: CGRect(x: 0, y: 0, width: 280, height: 100))
        let labelLocation = CGPoint(x: centerX, y: self.bounds.height * 0.2)
        label.center = labelLocation
        label.backgroundColor = .secondarySystemBackground
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.text = "Drag your finger to change the button location and then click Done"
        label.numberOfLines = 0
        label.layer.cornerRadius = 5.0
        label.layer.masksToBounds = true
        self.addSubview(label)
    }
    
    @IBAction func donePressed(_ sender: Any) {
        closeHandler()
    }
    
    // Good techical resource for how to do the masking
    // https://www.calayer.com/core-animation/2016/05/22/cashapelayer-in-depth.html
    func configureMask() {
        // Create the mask layer
        let maskLayer = CAShapeLayer()
        // Create a path for the whole mask area
        let wholeMaskPath = UIBezierPath(rect: self.bounds)
        // Create the rectangle opening path
        let openingPath = UIBezierPath(rect: opening)
        // Append openingPath to the wholeMaskPath
        wholeMaskPath.append(openingPath)
        // Fill rule to fill only where paths do not overlap
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        // Set path of the mask layer
        maskLayer.path = wholeMaskPath.cgPath
        // Mask our UIView with the maskLayer so only opening rectangle shows through
        self.layer.mask = maskLayer
    }
    
    // Check where an event lands to decide whether to pass through this UIView
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if(opening.contains(point)) {
            /* return false to send event up responder chain so maskView doesn't handle event
             over the opening, and instead controls within opening
             will receive it
             */
            return false
        }
        else {
            // outside opening area so don't send event up responder chain
            return true
        }
    }
}

// Store the button position for app relaunches
struct KeysButton {
    static let centerX = "centerX"
    static let centerY = "centerY"
}

