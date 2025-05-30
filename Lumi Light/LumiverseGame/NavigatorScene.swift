//
//  NavigatorScene.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/30/25.
//


// File: LumiverseGame/Navigator/NavigatorScene.swift
import SpriteKit
// import GameplayKit // Keep for later use (randomization, AI, etc.)

class NavigatorScene: SKScene, SKPhysicsContactDelegate {

    private var player: SKShapeNode?
    private var lastTouchLocation: CGPoint?
    
    // Ensure this string matches the actual font name as recognized by iOS
    // (e.g., check Font Book on Mac for the PostScript name if unsure)
    private let gameFontName = "Nasalization-Regular"

    // Labels
    private var welcomeLabel: SKLabelNode!
    private var instructionsLabel: SKLabelNode!
    
    // Movement parameters
    private let playerSpeed: CGFloat = 7.0 // Increased speed a bit

    override func sceneDidLoad() {
        super.sceneDidLoad() // Good practice to call super
        
        // Initial setup that depends on the scene's size being available
        // This is often a better place than didMove(to:) for size-dependent initializations if
        // you find didMove(to:) gets called before size is fully established by SpriteView.
        // However, for most basic setups, didMove(to:) is fine.
    }

    override func didMove(to view: SKView) {
        print("NavigatorScene didMove to view with size: \(view.frame.size)")
        backgroundColor = SKColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1.0) // Even darker space

        // Welcome Label
        welcomeLabel = SKLabelNode(fontNamed: gameFontName)
        welcomeLabel.text = "LUMI NAVIGATOR" // Changed text
        welcomeLabel.fontSize = 28 // Adjusted size
        welcomeLabel.fontColor = .cyan.withAlphaComponent(0.9)
        welcomeLabel.position = CGPoint(x: frame.midX, y: frame.midY + 60) // Adjusted position
        addChild(welcomeLabel)

        // Instructions Label
        instructionsLabel = SKLabelNode(fontNamed: gameFontName)
        instructionsLabel.text = "Touch & Drag to Explore" // Changed text
        instructionsLabel.fontSize = 18 // Adjusted size
        instructionsLabel.fontColor = .white.withAlphaComponent(0.8)
        instructionsLabel.position = CGPoint(x: frame.midX, y: frame.midY + 20) // Adjusted position
        addChild(instructionsLabel)
        
        // Create placeholder player node
        player = SKShapeNode(circleOfRadius: 25) // Slightly larger
        player?.fillColor = SKColor.orange.withAlphaComponent(0.8)
        player?.strokeColor = SKColor.yellow.withAlphaComponent(0.9)
        player?.lineWidth = 2.5
        // Glow effect for the player
        if let playerNode = player {
            let effectNode = SKEffectNode()
            effectNode.shouldRasterize = true // For performance with filters
            effectNode.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 10])
            playerNode.glowWidth = 1.0 // This is for SKShapeNode, not directly a "glow" like SpriteKit's SKEmitterNode
                                       // For a true glow, you might use an SKEmitterNode or an SKLightNode

            let playerTextureNode = SKShapeNode(circleOfRadius: 25) // Node for texture effect if needed
            playerTextureNode.fillColor = SKColor.orange.withAlphaComponent(0.8)
            playerTextureNode.strokeColor = SKColor.yellow.withAlphaComponent(0.9)
            playerTextureNode.lineWidth = 2.5
            effectNode.addChild(playerTextureNode) // Add a shape to blur for a glow effect

            // playerNode.addChild(effectNode) // This would make the glow part of the player node itself
                                           // For now, let's keep the player simple.
            // You could also create a separate SKEmitterNode for a particle-based glow.
        }


        player?.position = CGPoint(x: frame.midX, y: frame.midY - 80) // Adjusted position
        if let player = player {
            addChild(player)
        }
        
        // Example: Add a subtle starfield
        if let starfield = SKEmitterNode(fileNamed: "Starfield.sks") { // Create Starfield.sks particle file
            starfield.position = CGPoint(x: frame.midX, y: frame.midY)
            starfield.zPosition = -1 // Behind everything
            // Make sure the particle texture is in your bundle
            // starfield.particleTexture = SKTexture(imageNamed: "spark") // Or your particle image
            addChild(starfield)
        } else {
            print("Could not load Starfield.sks - ensure it's in your project and target.")
        }
        
        // Physics World Setup (Uncomment and configure when you add physics-based elements)
        // physicsWorld.gravity = CGVector(dx: 0, dy: 0) // No gravity for space game
        // physicsWorld.contactDelegate = self // To handle collision callbacks
    }

    // --- Touch Handling ---
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchLocation = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchLocation = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Optionally stop movement or clear lastTouchLocation when touch ends
        // lastTouchLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Same as touchesEnded in many cases
        // lastTouchLocation = nil
    }

    // --- Game Loop ---
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        movePlayerIfNeeded()
    }
    
    private func movePlayerIfNeeded() {
        guard let player = player, let targetLocation = lastTouchLocation else { return }

        let currentPosition = player.position
        let dx = targetLocation.x - currentPosition.x
        let dy = targetLocation.y - currentPosition.y
        let distance = hypot(dx, dy) // More concise way to get distance

        // Only move if not already very close to the target, to prevent jitter
        if distance > 1.0 {
            // Normalize direction vector
            let directionX = dx / distance
            let directionY = dy / distance
            
            // Calculate new position
            let newX = currentPosition.x + directionX * playerSpeed
            let newY = currentPosition.y + directionY * playerSpeed
            
            player.position = CGPoint(x: newX, y: newY)
        } else {
            // Reached the target or very close, optionally stop targeting.
            // If you want continuous movement towards where finger is held,
            // you wouldn't set lastTouchLocation to nil here.
            // For a "tap to move to point" behavior, you might nil it out:
            // lastTouchLocation = nil
        }
    }
    
    // --- SKPhysicsContactDelegate Methods (Implement when using physics for collisions) ---
    // func didBegin(_ contact: SKPhysicsContact) {
    //    print("Contact began between \(contact.bodyA.node?.name ?? "A") and \(contact.bodyB.node?.name ?? "B")")
    //    // Add collision handling logic here
    // }
}