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
    @IBOutlet weak var buttonCenterX: NSLayoutConstraint!
    @IBOutlet weak var buttonCenterY: NSLayoutConstraint!
    @IBOutlet weak var viewMessage: UIView!
    @IBOutlet weak var labelInfo: UILabel!
    
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
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(ViewController.panSOS(_:)))
        buttonMovable.addGestureRecognizer(pan)
        pan.delegate = self
    }
    
    
    
    func closeOverlay() {
        maskView.isHidden = true
    }
    
    @objc func panSOS(_ gestureRecognizer : UIPanGestureRecognizer) {
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        let translation = gestureRecognizer.translation(in: buttonMovable.superview)
        if gestureRecognizer.state == .began {
            // Use starting button center for applying adjustments as panning is occuring
            // Existing center will reflect centerX/centerY constraint constants
            buttonCenter = buttonMovable.center
            print(".began \(buttonCenterX.constant) \(buttonCenterY.constant)")
        }
        if gestureRecognizer.state == .ended || gestureRecognizer.state == .failed || gestureRecognizer.state == .cancelled{
            let adjusted = adjustedTranslation(inPoint: translation)
            // Since not moving anymore, update constants based on full x/y adjustment since started moving
            buttonCenterX.constant = buttonCenterX.constant + adjusted.x
            buttonCenterY.constant = buttonCenterY.constant + adjusted.y
            UserDefaults.standard.set(buttonCenterX.constant, forKey: KeysButton.centerX)
            UserDefaults.standard.set(buttonCenterY.constant, forKey: KeysButton.centerY)
            
        }
        else {
            //Movement continuing so adjust position if exceeding edges
            let adjusted = adjustedTranslation(inPoint: translation)
            let newCenter = CGPoint(x: buttonCenter.x + adjusted.x, y: buttonCenter.y + adjusted.y)
            buttonMovable.center = newCenter
        }
    }
    
    
    func adjustedTranslation(inPoint: CGPoint) -> CGPoint
    {
        // these are how much moved, not absolute values of what the constraint constant was
        var xTrans = inPoint.x
        var yTrans = inPoint.y
        
        xTransMin = buttonRadius - buttonCenter.x
        xTransMax = boundsWidth - buttonCenter.x - buttonRadius
        yTransMin = buttonRadius - buttonCenter.y
        yTransMax = boundsHeight - buttonCenter.y - buttonRadius
        
        // Check actual trans with min/max values and adjust if necessary
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
        self.maskLayer()
        
        // Done button on the overlay to close it
        let button = UIButton()
        button.setTitle("Done", for: .normal)
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 40)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        
        let centerX = self.bounds.width/2
        //let centerY = self.bounds.height/2
        let center = CGPoint(x: centerX, y: self.bounds.height * 0.35)
        
        button.center = center
        
        button.addTarget(self, action: #selector(donePressed(_:)), for: .touchUpInside)
        self.addSubview(button)
        
        let locLabel = CGPoint(x: centerX, y: self.bounds.height * 0.2)
        
        // label for user instructions
        let label = PaddedLabel(frame: CGRect(x: 0, y: 0, width: 280, height: 100))
        label.center = locLabel
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
    func maskLayer() {
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

