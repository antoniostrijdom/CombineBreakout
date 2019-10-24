# CombineBreakout: My attempt to learn Combine basics through the crucible of video games

This project was my first go at writing a Combine powered application. It is a simple game of Breakout (in the Wozniak tradition).

## Requirements

### Runtime

****macOS**** Catalina 10.15

### Build

Xcode 11.0, Swift 5

## Why a game?

Well, Apple describes Combine as *"a declarative Swift API for processing values over time."* What else basically boils down to values over time? That's right, videogames. And what game would be most appropriate? [Breakout](https://en.wikipedia.org/wiki/Breakout_(video_game)), of course.

This game of Breakout uses [SpriteKit](https://developer.apple.com/documentation/spritekit) for graphics and input and [Combine](https://developer.apple.com/documentation/combine) for the back end.

## How does it work?

### Initial setup

After the initial SpriteKit setup, the game calls the one static `start`  function on the `GameEngine`  `enum` .

`static func start(in scene: SKScene, inputSubject: InputSubject) -> AnyPublisher<([Sprite], Int, Int), GameError>`

This function returns an `AnyPublisher` with an `Output` of  `[Sprite]`[^1].

This `Publisher` is connected to a `Subscriber` via the [`sink`](https://developer.apple.com/documentation/combine/publisher/3343978-sink) method. This method takes two closures: one is called when the `Publisher` publishes a new value and the other closure is called when the `Publisher` sends a completion.

In *CombineBreakout*'s case, the `Publisher` publishes `Sprite`s until the game ends with a Game Over. The `Sprite`s are sent to an instance of the `Renderer` class, which is responsible for updating the scene.

[^1]: Actually, the `Output` is a tuple of the sprites and the player's score and remaining lives.

### Pipeline

The game pipeline is broken up into several stages. Each stage is handled by an operator. This turned out to be an excellent way to learn about a few of `Publisher`'s operators, which I'm going to attempt to pass on here. As each operator returns a `Publisher` it is easy to chain them into complex pipelines.

**[**Timer.publish**](https://developer.apple.com/documentation/foundation/timer/3329589-publish)**

Every (realtime) game ever made relies on a timer to drive the game forward. Luckily Apple provides the Foundation Timer class that provides the subsecond precision we need (60hz!) and, when introducing Combine, they added a `publish` method that returns a `TimerPublisher`.

`static func publish(every interval: TimeInterval, tolerance: TimeInterval? = nil, on runLoop: RunLoop, in mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) -> Timer.TimerPublisher`

Our pipeline starts with the `TimerPublisher`. It is worth pointing out that `TimerPublisher` doesn't start publishing until you call `connect()` or `autoconnect()` operator. This is inherited from its conformance to [`ConnectablePublisher`](https://developer.apple.com/documentation/combine/connectablepublisher).

CombineBreakout calls `autoconnect()` which causes the `TimerPublisher` to start publishing events when the `Subscriber` connects.

****Input****

Of course sprites and an update loop are great, but a game isn't a game until you can control it. Input in SpriteKit is handled via traditional input events, working them into the game pipeline required a bit of plumbing.

For CombineBreakout we want to control the paddle with the mouse. In order to do this in SpriteKit, we need to listen for `mouseMoved` events[^2]. These events are then published via a [`CurrentValueSubject`](https://developer.apple.com/documentation/combine/currentvaluesubject). This `Subject`[^3] publishes the current input event (which it caches).

These input events are then fed into the pipeline by using the [`combineLatest`](https://developer.apple.com/documentation/combine/publisher/3333679-combinelatest) operator. This does as the name suggests - combining the latest value of the specified `Publisher` (in this case, the last mouse moved event) and the target (the `TimerPublisher`'s output, the date of the latest event).

[^2]: It is worth mentioning that SpriteKit doesn't track mouse movement events by default. I needed to setup a tracking area, as mentioned on [this stackoverflow post](https://stackoverflow.com/questions/43059990/mousemoved-function-not-called-when-i-move-the-mouse)

[^3]: A [`Subject`](https://developer.apple.com/documentation/combine/subject) is a `Publisher` that provides a method that allows imperitive code to inject values into the `Publisher` pipeline.

**[**map**](https://developer.apple.com/documentation/combine/publisher/3204718-map)**

The next few stages of the pipeline use the `map` operator to transform the mouse move event coordinates into a new paddle `Point` and update the ball `Point`, transform these raw `Point`s into clipped `Point`s and check for collisions.

The final `map` transforms these coordinates into the array of `Sprite`s.

**[**tryMap**](https://developer.apple.com/documentation/combine/publisher/3204772-trymap)**

`tryMap` is exactly the same as `map`, but it takes a `throw`ing closure, allowing this stage in the pipeline to `throw` a `GameError.GameOver` error when the player runs out of lives. This causes the `Publisher` to send a completion, ending the game loop.

**[`mapError`](https://developer.apple.com/documentation/combine/publisher/3204719-maperror)**

As `tryMap` throws a generic `Error` and our `Publisher` has a `GameError` `Failure` type, we need to transform the `Error` into a `GameError`. This is done by calling the `mapError` operator.

**[**eraseToAnyPublisher**](https://developer.apple.com/documentation/combine/publisher/3241548-erasetoanypublisher)**

Wraps our `Publisher` in a type erased `AnyPublisher`.

## Conclusion

Hopefully this readme and this code helps someone understand how Combine's `Publisher`s and their operators function. I highly recommend watching Apple's WWDC sessions: [Introducing Combine](https://developer.apple.com/videos/play/wwdc2019/722/) and [Combine in Practice](https://developer.apple.com/videos/play/wwdc2019/721/).

Combine promises to bring reactive programming to mainstream Swift. It represents a slightly different way of architecting your application, but ultimately will lead to writing less code that is easier to reason about and is (hopefully) more stable.
