import SpriteKit

final class SafeGameScene: SKScene, SKPhysicsContactDelegate {

    weak var gameManager: SafeGameManager?

    private var ship: SKNode! // Container node for all ship components
    private var shipPhysicsBody: SKPhysicsBody?
    private var lastUpdateTime: TimeInterval = 0
    private var survivalTime: TimeInterval = 0

    private let targetSurvival: TimeInterval = 10   // seconds to unlock
    private var isWarping = false

    struct Category {
        static let ship: UInt32      = 0x1 << 0
        static let asteroid: UInt32  = 0x1 << 1
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.contactDelegate = self

        setupStarfield()
        setupShip()
        startAsteroidSpawning()
    }

    // MARK: - Setup

    private func setupShip() {
        // Style C: Rounded triangle/teardrop spaceship pointing upward
        let shipWidth: CGFloat = 50
        let shipHeight: CGFloat = 70
        let shipY = size.height * 0.18
        
        // Create container node for all ship components
        ship = SKNode()
        ship.position = CGPoint(x: size.width / 2, y: shipY)
        ship.zPosition = 10
        ship.name = "ship"
        
        // Create teardrop/rounded triangle body path (relative to container)
        let bodyPath = CGMutablePath()
        let topPoint = CGPoint(x: shipWidth / 2, y: shipHeight) // top (nose)
        let leftBottom = CGPoint(x: shipWidth * 0.2, y: 0) // bottom left
        let rightBottom = CGPoint(x: shipWidth * 0.8, y: 0) // bottom right
        
        bodyPath.move(to: topPoint)
        bodyPath.addQuadCurve(to: leftBottom, control: CGPoint(x: 0, y: shipHeight * 0.3))
        bodyPath.addQuadCurve(to: rightBottom, control: CGPoint(x: shipWidth / 2, y: -shipHeight * 0.1))
        bodyPath.addQuadCurve(to: topPoint, control: CGPoint(x: shipWidth, y: shipHeight * 0.3))
        bodyPath.closeSubpath()
        
        // Overall ship glow (subtle) - positioned at origin relative to container
        let shipGlow = SKShapeNode(path: bodyPath)
        shipGlow.fillColor = .cyan
        shipGlow.alpha = 0.15
        shipGlow.position = .zero
        shipGlow.zPosition = 1
        ship.addChild(shipGlow)
        
        // Main body (dark inner)
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = UIColor(white: 0.05, alpha: 1.0) // very dark gray/almost black
        body.strokeColor = .clear
        body.position = .zero
        body.zPosition = 2
        
        // Add a secondary outline layer for gradient effect (magenta/pink)
        let outline2 = SKShapeNode(path: bodyPath)
        outline2.fillColor = .clear
        outline2.strokeColor = UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.6) // magenta
        outline2.lineWidth = 2
        outline2.glowWidth = 1
        outline2.position = .zero
        outline2.zPosition = 2.5
        
        // Neon outline with glow (cyan-blue-magenta gradient effect)
        let outline = SKShapeNode(path: bodyPath)
        outline.fillColor = .clear
        outline.strokeColor = .cyan
        outline.lineWidth = 3
        outline.glowWidth = 2
        outline.position = .zero
        outline.zPosition = 3
        
        // Engine thruster glow (soft blue extending downward)
        let thrusterLeft = SKShapeNode(rectOf: CGSize(width: 4, height: 8))
        thrusterLeft.fillColor = .cyan
        thrusterLeft.alpha = 0.4
        thrusterLeft.position = CGPoint(x: shipWidth / 2 - 5, y: -shipHeight * 0.3)
        thrusterLeft.zPosition = 1
        
        let thrusterRight = SKShapeNode(rectOf: CGSize(width: 4, height: 8))
        thrusterRight.fillColor = .cyan
        thrusterRight.alpha = 0.4
        thrusterRight.position = CGPoint(x: shipWidth / 2 + 5, y: -shipHeight * 0.3)
        thrusterRight.zPosition = 1
        
        // Engine circles (back/bottom, one on each side)
        let engineSize: CGFloat = 3
        let engineSpacing: CGFloat = 10
        
        let engineLeft = SKShapeNode(circleOfRadius: engineSize)
        engineLeft.fillColor = .cyan
        engineLeft.strokeColor = .clear
        engineLeft.glowWidth = 6
        engineLeft.position = CGPoint(x: shipWidth / 2 - engineSpacing / 2, y: -shipHeight * 0.25)
        engineLeft.zPosition = 4
        
        let engineRight = SKShapeNode(circleOfRadius: engineSize)
        engineRight.fillColor = .cyan
        engineRight.strokeColor = .clear
        engineRight.glowWidth = 6
        engineRight.position = CGPoint(x: shipWidth / 2 + engineSpacing / 2, y: -shipHeight * 0.25)
        engineRight.zPosition = 4
        
        // Cockpit glow (cyan tint)
        let cockpitGlow = SKShapeNode(circleOfRadius: 10)
        cockpitGlow.fillColor = .cyan
        cockpitGlow.alpha = 0.3
        cockpitGlow.position = CGPoint(x: shipWidth / 2, y: shipHeight * 0.15)
        cockpitGlow.zPosition = 3.5
        
        // Cockpit circle (center-middle)
        let cockpit = SKShapeNode(circleOfRadius: 8)
        cockpit.fillColor = UIColor(white: 0.95, alpha: 0.9) // soft white
        cockpit.strokeColor = .clear
        cockpit.glowWidth = 4
        cockpit.position = CGPoint(x: shipWidth / 2, y: shipHeight * 0.15)
        cockpit.zPosition = 4
        
        // Add all components to container
        ship.addChild(body)
        ship.addChild(outline2)
        ship.addChild(outline)
        ship.addChild(thrusterLeft)
        ship.addChild(thrusterRight)
        ship.addChild(cockpitGlow)
        ship.addChild(cockpit)
        ship.addChild(engineLeft)
        ship.addChild(engineRight)
        
        // Physics body based on the teardrop shape (offset to match container position)
        let physicsPath = CGMutablePath()
        physicsPath.move(to: CGPoint(x: topPoint.x, y: topPoint.y))
        physicsPath.addQuadCurve(to: CGPoint(x: leftBottom.x, y: leftBottom.y), control: CGPoint(x: 0, y: shipHeight * 0.3))
        physicsPath.addQuadCurve(to: CGPoint(x: rightBottom.x, y: rightBottom.y), control: CGPoint(x: shipWidth / 2, y: -shipHeight * 0.1))
        physicsPath.addQuadCurve(to: CGPoint(x: topPoint.x, y: topPoint.y), control: CGPoint(x: shipWidth, y: shipHeight * 0.3))
        physicsPath.closeSubpath()
        
        shipPhysicsBody = SKPhysicsBody(polygonFrom: physicsPath)
        shipPhysicsBody?.isDynamic = true
        shipPhysicsBody?.categoryBitMask = Category.ship
        shipPhysicsBody?.contactTestBitMask = Category.asteroid
        shipPhysicsBody?.collisionBitMask = 0
        
        // Attach physics body to container
        ship.physicsBody = shipPhysicsBody
        
        addChild(ship)
    }

    private func setupStarfield() {
        // background stars drifting down
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = SKTexture(imageNamed: "spark") // or use built-in circle
        starEmitter.particleColor = .white
        starEmitter.particleBirthRate = 80
        starEmitter.particleLifetime = 4
        starEmitter.particleSpeed = -100
        starEmitter.particleSpeedRange = 40
        starEmitter.particleSize = CGSize(width: 2, height: 2)
        starEmitter.position = CGPoint(x: size.width/2, y: size.height)
        starEmitter.zPosition = -5
        starEmitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        addChild(starEmitter)
    }

    private func startAsteroidSpawning() {
        let spawn = SKAction.run { [weak self] in
            self?.spawnAsteroid()
        }
        let wait = SKAction.wait(forDuration: 0.7, withRange: 0.4)
        run(.repeatForever(.sequence([spawn, wait])), withKey: "spawnAsteroids")
    }

    private func spawnAsteroid() {
        let radius = CGFloat.random(in: 18...34)
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = .gray
        node.strokeColor = .white.withAlphaComponent(0.4)
        node.glowWidth = 4
        node.zPosition = 5

        let x = CGFloat.random(in: radius...(size.width - radius))
        node.position = CGPoint(x: x, y: size.height + radius)

        node.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        node.physicsBody?.isDynamic = true
        node.physicsBody?.categoryBitMask = Category.asteroid
        node.physicsBody?.contactTestBitMask = Category.ship
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.velocity = CGVector(dx: 0, dy: -CGFloat.random(in: 180...260))
        node.physicsBody?.linearDamping = 0

        addChild(node)
    }

    // MARK: - Touch control (drag left / right)

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !isWarping else { return }
        let location = touch.location(in: self)
        let shipWidth: CGFloat = 50
        let clampedX = min(max(location.x, shipWidth / 2), size.width - shipWidth / 2)
        
        // Move the container node (all children move with it)
        ship.position.x = clampedX
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event) // allow tap-drag instantly
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard !isWarping else { return }

        survivalTime += delta

        // remove asteroids that left the screen
        enumerateChildNodes(withName: "//") { node, _ in
            if node.position.y < -100 {
                node.removeFromParent()
            }
        }

        if survivalTime >= targetSurvival {
            triggerHyperSpeed()
        }
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isWarping else { return }

        if (contact.bodyA.categoryBitMask == Category.ship &&
            contact.bodyB.categoryBitMask == Category.asteroid) ||
           (contact.bodyB.categoryBitMask == Category.ship &&
            contact.bodyA.categoryBitMask == Category.asteroid) {

            // hit asteroid → reset to locked
            gameManager?.state = .locked
        }
    }

    // MARK: - Hyper-speed unlock

    private func triggerHyperSpeed() {
        isWarping = true
        removeAction(forKey: "spawnAsteroids")

        let warpEmitter = SKEmitterNode()
        warpEmitter.particleTexture = SKTexture(imageNamed: "spark")
        warpEmitter.particleColor = .white
        warpEmitter.particleBirthRate = 600
        warpEmitter.particleLifetime = 0.6
        warpEmitter.particleSpeed = -900
        warpEmitter.particleSpeedRange = 200
        warpEmitter.particleSize = CGSize(width: 3, height: 18)
        warpEmitter.position = CGPoint(x: size.width/2, y: size.height)
        warpEmitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        warpEmitter.zPosition = -3
        addChild(warpEmitter)

        // quick zoom-in and fade to unlocked state
        let zoom = SKAction.scale(to: 1.4, duration: 0.7)
        let fade = SKAction.fadeOut(withDuration: 0.7)
        let group = SKAction.group([zoom, fade])

        run(group) { [weak self] in
            self?.gameManager?.state = .unlocked
        }
    }
}

