//
//  GameScene.swift
//  CombineBreakout
//
//  Created by Antonio Strijdom on 13/10/2019.
//  Copyright © 2019 Antonio Strijdom. All rights reserved.
//

import SpriteKit
import GameplayKit
import Combine

struct Sprite {
    var position = CGPoint.zero
    var size = CGSize.zero
    var color = NSColor.white
}

typealias InputSubject = CurrentValueSubject<NSEvent?, Never>

enum GameEngine {
    static func start(in scene: SKScene, inputSubject: InputSubject) -> AnyPublisher<[Sprite], Never> {
        let ballStartPosition = CGPoint(x: scene.frame.size.width / 2.0, y: scene.frame.size.height / 2.0)
        let northEast = CGPoint(x: -1.0, y:  1.0)
        let northWest = CGPoint(x:  1.0, y:  1.0)
        let southEast = CGPoint(x: -1.0, y: -1.0)
        let southWest = CGPoint(x:  1.0, y: -1.0)
        
        var ballPosition = ballStartPosition
        var ballDirection = southEast
        var ballSpeed: CGFloat = 1.0
        
        var lastUpdate = Date()
        
        return Timer.publish(every: 1.0/60.0, on: RunLoop.current, in: .default)
            .autoconnect()
            .combineLatest(inputSubject, { (date, event) -> (Date, CGFloat) in
                if let event = event {
                    let point = event.location(in: scene)
                    let posx = point.x
                    print("X: \(posx)")
                    return (date, posx)
                }
                return (date, 0.0)
            })
            .map({ (state) -> [Sprite] in
                let date = state.0
                let posx = state.1
                
                // update ball
                let ballSprite = Sprite(position: ballPosition, size: CGSize(width: 10.0, height: 10.0))
                let scale = CGAffineTransform(scaleX: ballSpeed, y: ballSpeed)
                let speed = ballDirection.applying(scale)
                let translate = CGAffineTransform(translationX: speed.x, y: speed.y)
                ballPosition = ballPosition.applying(translate)
                
                // update paddle
                let paddleWidth = CGFloat(100.0)
                let halfPaddleWidth = paddleWidth / 2.0
                let clippedXPos = min(max(posx - halfPaddleWidth, 0.0), scene.frame.width - paddleWidth)
                let paddlePosition = CGPoint(x: clippedXPos, y: 0.0)
                let paddleSprite = Sprite(position: paddlePosition, size: CGSize(width: paddleWidth, height: 10.0))
                
                // update date
                lastUpdate = date
                
                return [ballSprite, paddleSprite]
            })
            .eraseToAnyPublisher()
    }
}

class Renderer {
    func render(sprites: [Sprite], in scene: SKScene) {
        scene.removeAllChildren()
        for sprite in sprites {
            let rect = CGRect(origin: sprite.position, size: sprite.size)
            let node = SKShapeNode(rect: rect)
            node.fillColor = sprite.color
            scene.addChild(node)
        }
    }
}

class GameScene: SKScene {
    
    private var cancellable: Cancellable? = nil
    private var inputSubject = InputSubject(nil)
    private let renderer = Renderer()
    
    override func didMove(to view: SKView) {
        self.cancellable = GameEngine.start(in: self, inputSubject: self.inputSubject)
            .sink { (sprites) in
                self.renderer.render(sprites: sprites, in: self)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        inputSubject.send(event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        inputSubject.send(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        inputSubject.send(event)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
