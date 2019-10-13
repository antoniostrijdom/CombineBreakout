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
        let northEast = CGPoint(x:  1.0, y:  1.0)
        let northWest = CGPoint(x: -1.0, y:  1.0)
        let southEast = CGPoint(x:  1.0, y: -1.0)
        let southWest = CGPoint(x: -1.0, y: -1.0)
        
        var currentBallPosition = ballStartPosition
        var ballDirection = southWest
        var ballSpeed: CGFloat = 1.0
        
        let paddleWidth = CGFloat(100.0)
        let paddleSize = CGSize(width: paddleWidth, height: 10.0)
        let ballSize = CGSize(width: 10.0, height: 10.0)
        
        var lastUpdate = Date()
        
        return Timer.publish(every: 1.0/60.0, on: RunLoop.current, in: .default)
            .autoconnect()
            .combineLatest(inputSubject, { (date, event) -> (Date, CGFloat) in
                // handle input events
                if let event = event {
                    let point = event.location(in: scene)
                    let posx = point.x
                    print("X: \(posx)")
                    return (date, posx)
                }
                return (date, 0.0)
            })
            .map({(state) -> (CGPoint, CGPoint) in
                // calculate positions
                let (date, posx) = state
                
                // update ball
                let scale = CGAffineTransform(scaleX: ballSpeed, y: ballSpeed)
                let speed = ballDirection.applying(scale)
                let translate = CGAffineTransform(translationX: speed.x, y: speed.y)
                let ballPosition = currentBallPosition.applying(translate)
                
                // update paddle
                let paddlePosition = CGPoint(x: posx, y: 0.0)
                
                if date == lastUpdate {
                    return (currentBallPosition, paddlePosition)
                }
                
                // update date
                lastUpdate = date
                
                return (ballPosition, paddlePosition)
            })
            .map({(state) -> (CGPoint, CGPoint) in
                // check for collisions
                var (ballPosition, paddlePosition) = state
                
                // paddle-edge collisions
                let halfPaddleWidth = paddleWidth / 2.0
                let clippedXPos = min(max(paddlePosition.x - halfPaddleWidth, 0.0), scene.frame.width - paddleWidth)
                let clippedPaddlePosition = CGPoint(x: clippedXPos, y: 0.0)
                
                // ball-edge collisions
                var newDirection: CGPoint? = nil
                if ballPosition.x < 0 {
                    ballPosition = currentBallPosition
                    newDirection = ballDirection == southWest ? southEast : northEast
                } else if ballPosition.x > scene.frame.width - ballSize.width {
                    ballPosition = currentBallPosition
                    newDirection = ballDirection == southEast ? southWest : northWest
                }
                if ballPosition.y < 0 {
                    ballPosition = currentBallPosition
                    newDirection = ballDirection == southWest ? northWest : northEast
                } else if ballPosition.y > scene.frame.height - ballSize.height {
                    ballPosition = currentBallPosition
                    newDirection = ballDirection == northWest ? southWest : southEast
                }
                
                // ball-paddle collisions
                let paddleRect = CGRect(origin: paddlePosition, size: paddleSize)
                let ballRect = CGRect(origin: ballPosition, size: ballSize)
                if ballRect.intersects(paddleRect) {
                    newDirection = ballDirection == southWest ? northEast : northWest
                }
                
                ballDirection = newDirection ?? ballDirection
                
                return (ballPosition, clippedPaddlePosition)
            })
            .map({ (state) -> [Sprite] in
                // render sprites
                let (ballPosition, paddlePosition) = state
                currentBallPosition = ballPosition
                
                let ballSprite = Sprite(position: ballPosition, size: ballSize)
                let paddleSprite = Sprite(position: paddlePosition, size: paddleSize)
                
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
