//
//  ViewController.swift
//  CombineBreakout
//
//  Created by Antonio Strijdom on 13/10/2019.
//  Copyright © 2019 Antonio Strijdom. All rights reserved.
//

import Cocoa
import SpriteKit
import GameplayKit

class ViewController: NSViewController {

    @IBOutlet var skView: SKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let sceneView = self.skView {
            // Create the scene
            let sceneSize = CGSize(width: 640, height: 480)
            let sceneFrame = CGRect(x:0 , y:0, width: sceneSize.width, height: sceneSize.height)
            let options = NSTrackingArea.Options([NSTrackingArea.Options.mouseMoved,
                                                  NSTrackingArea.Options.activeInKeyWindow,
                                                  NSTrackingArea.Options.activeAlways,
                                                  NSTrackingArea.Options.inVisibleRect])
            let trackingArea = NSTrackingArea(rect: sceneFrame, options: options, owner: sceneView, userInfo: nil)
            sceneView.addTrackingArea(trackingArea)
            let scene = GameScene(size: sceneSize)
            
            // Set the scale mode to scale to fit the window
            scene.scaleMode = .aspectFill
                
            // Present the scene
            sceneView.presentScene(scene)
            sceneView.ignoresSiblingOrder = true
            sceneView.showsFPS = true
            sceneView.showsNodeCount = true
        }
    }
}

