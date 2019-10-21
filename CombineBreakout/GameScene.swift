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

struct Brick {
    let row: Int
    let column: Int
    let color: NSColor
}

enum GameError: Error {
    case GameOver(finalScore: Int)
}

typealias InputSubject = CurrentValueSubject<NSEvent?, GameError>

enum GameEngine {
    static func start(in scene: SKScene, inputSubject: InputSubject) -> AnyPublisher<([Sprite], Int), GameError> {
        let ballStartPosition = CGPoint(x: scene.frame.size.width / 2.0, y: scene.frame.size.height / 2.0)
        let northEast = CGPoint(x:  1.0, y:  1.0)
        let northWest = CGPoint(x: -1.0, y:  1.0)
        let southEast = CGPoint(x:  1.0, y: -1.0)
        let southWest = CGPoint(x: -1.0, y: -1.0)
        
        var currentBallPosition = ballStartPosition
        var ballDirection = southWest
        var ballSpeed: CGFloat = 3.0
        
        let paddleWidth = CGFloat(100.0)
        let paddleSize = CGSize(width: paddleWidth, height: 10.0)
        let ballSize = CGSize(width: 10.0, height: 10.0)
        
        let brickSize = CGSize(width: 100.0, height: 20.0)
        let startingBricks = [
        Brick(row: 0, column: 0, color: .red), Brick(row: 0, column: 1, color: .green), Brick(row: 0, column: 2, color: .blue),
        Brick(row: 0, column: 3, color: .red), Brick(row: 0, column: 4, color: .green), Brick(row: 0, column: 5, color: .blue),
        Brick(row: 1, column: 0, color: .blue), Brick(row: 1, column: 1, color: .red), Brick(row: 1, column: 2, color: .green),
        Brick(row: 1, column: 3, color: .blue), Brick(row: 1, column: 4, color: .red), Brick(row: 1, column: 5, color: .green),
        Brick(row: 2, column: 0, color: .green), Brick(row: 2, column: 1, color: .blue), Brick(row: 2, column: 2, color: .red),
        Brick(row: 2, column: 3, color: .green), Brick(row: 2, column: 4, color: .blue), Brick(row: 2, column: 5, color: .red),
        ]
        var bricks = startingBricks
        
        var lastUpdate = Date()
        
        var multiplier = 1
        var score = 0
        var gameOver = false
        
        return Timer.publish(every: 1.0/60.0, on: RunLoop.current, in: .default)
            .autoconnect()
            .setFailureType(to: GameError.self)
            .combineLatest(inputSubject, { (date, event) -> (Date, CGFloat) in
                // handle input events
                if let event = event {
                    if event.type == .keyUp {
                        if event.keyCode == 12 {
                            gameOver = true
                        }
                    }
                    let point = event.location(in: scene)
                    let posx = point.x
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
                    gameOver = true
                } else if ballPosition.y > scene.frame.height - ballSize.height {
                    ballPosition = currentBallPosition
                    newDirection = ballDirection == northWest ? southWest : southEast
                }
                
                // ball-paddle collisions
                var leftPaddlePos = paddlePosition
                leftPaddlePos.x = leftPaddlePos.x - halfPaddleWidth
                let rightPaddlePos = paddlePosition
                let halfPaddleSize = CGSize(width: halfPaddleWidth, height: paddleSize.height)
                let leftPaddleRect = CGRect(origin: leftPaddlePos, size: halfPaddleSize)
                let rightPaddleRect = CGRect(origin: rightPaddlePos, size: halfPaddleSize)
                let ballRect = CGRect(origin: ballPosition, size: ballSize)
                if ballRect.intersects(leftPaddleRect) {
                    newDirection = northWest
                } else if ballRect.intersects(rightPaddleRect) {
                    newDirection = northEast
                }
                
                // ball-brick collisions
                var hits = [Int]()
                let center = scene.frame.width / 2.0
                let starty = scene.frame.height - brickSize.height - brickSize.height
                for (index, brick) in bricks.enumerated() {
                    let columnCount = startingBricks.reduce(0) { $0 + ($1.row == brick.row ? 1 : 0) }
                    let columnWidth = CGFloat(columnCount) * brickSize.width
                    let startx = center - (columnWidth / 2.0)
                    let position = CGPoint(x: startx + (CGFloat(brick.column) * brickSize.width),
                                           y: starty - (CGFloat(brick.row) * brickSize.height))
                    let brickRect = CGRect(origin: position, size: brickSize)
                    if ballRect.intersects(brickRect) {
                        hits.append(index)
                    }
                }
                for index in hits.reversed() {
                    newDirection = ballDirection == northWest ? southWest : southEast
                    ballSpeed = ballSpeed + 1.0
                    score = score + multiplier
                    bricks.remove(at: index)
                }
                
                ballDirection = newDirection ?? ballDirection
                
                return (ballPosition, clippedPaddlePosition)
            })
            .map({ (state) -> [Sprite] in
                // generate sprites
                let (ballPosition, paddlePosition) = state
                currentBallPosition = ballPosition
                
                let ballSprite = Sprite(position: ballPosition, size: ballSize)
                let paddleSprite = Sprite(position: paddlePosition, size: paddleSize)
                var sprites = [ballSprite, paddleSprite]
                
                let center = scene.frame.width / 2.0
                let starty = scene.frame.height - brickSize.height - brickSize.height
                for brick in bricks {
                    let columnCount = startingBricks.reduce(0) { $1.column > $0 ? $1.column : $0 } + 1
                    let columnWidth = CGFloat(columnCount) * brickSize.width
                    let startx = center - (columnWidth / 2.0)
                    let position = CGPoint(x: startx + (CGFloat(brick.column) * brickSize.width),
                                           y: starty - (CGFloat(brick.row) * brickSize.height))
                    let brickSprite = Sprite(position: position, size: brickSize, color: brick.color)
                    sprites.append(brickSprite)
                }
                
                return sprites
            })
            .tryMap({ (sprites) throws -> ([Sprite], Int) in
                if gameOver { throw GameError.GameOver(finalScore: score) }
                return (sprites, score)
            })
            .mapError({ (error) -> GameError in
                return error as! GameError
            })
            .eraseToAnyPublisher()
    }
}

class Renderer {
    func render(sprites: [Sprite], score: Int, in scene: SKScene) {
        scene.removeAllChildren()
        for sprite in sprites {
            let rect = CGRect(origin: sprite.position, size: sprite.size)
            let node = SKShapeNode(rect: rect)
            node.fillColor = sprite.color
            scene.addChild(node)
        }
        let scoreSprite = SKLabelNode(text: "Score: \(score)")
        scoreSprite.position = CGPoint(x: 15.0, y: scene.frame.size.height - 10.0)
        scoreSprite.fontSize = 8
        scoreSprite.fontColor = NSColor.white
        scene.addChild(scoreSprite)
    }
    
    func renderTitle(in scene: SKScene) {
        scene.removeAllChildren()
        let centerX = scene.frame.width / 2.0
        let centerY = scene.frame.height / 2.0
        let title = SKLabelNode(text: "Combine Breakout")
        title.position = CGPoint(x: centerX, y: centerY)
        title.fontSize = 20
        title.fontColor = NSColor.white
        scene.addChild(title)
        let subTitle = SKLabelNode(text: "(click to start)")
        subTitle.position =
            CGPoint(x: centerX, y: centerY - title.calculateAccumulatedFrame().size.height)
        subTitle.fontSize = 8
        subTitle.fontColor = NSColor.white
        scene.addChild(subTitle)
    }
    
    func renderGameOver(in scene: SKScene) {
        scene.removeAllChildren()
        let node = SKLabelNode(text: "Game Over")
        let centerX = scene.frame.width / 2.0
        let centerY = scene.frame.height / 2.0
        node.position = CGPoint(x: centerX, y: centerY)
        node.fontSize = 20
        node.fontColor = NSColor.white
        scene.addChild(node)
        let subTitle = SKLabelNode(text: "(click to restart)")
        subTitle.position =
            CGPoint(x: centerX, y: centerY - node.calculateAccumulatedFrame().size.height)
        subTitle.fontSize = 8
        subTitle.fontColor = NSColor.white
        scene.addChild(subTitle)
    }
}

class GameScene: SKScene {
    
    private var cancellable: Cancellable? = nil
    private var inputSubject = InputSubject(nil)
    private let renderer = Renderer()
    
    override func didMove(to view: SKView) {
        renderer.renderTitle(in: self)
    }
    
    override func keyUp(with event: NSEvent) {
        inputSubject.send(event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        inputSubject.send(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        if nil == self.cancellable {
            self.cancellable = GameEngine.start(in: self, inputSubject: self.inputSubject)
                .sink(receiveCompletion: { (_) in
                    self.renderer.renderGameOver(in: self)
                    self.cancellable = nil
                }, receiveValue: { (sprites) in
                    self.renderer.render(sprites: sprites.0, score: sprites.1, in: self)
                })
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
