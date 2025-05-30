// File: LumiverseGame/Navigator/NavigatorGameView.swift
import SwiftUI
import SpriteKit

struct NavigatorGameView: View {
    @Environment(\.presentationMode) var presentationMode

    // Lazily create the scene to ensure its size is correctly initialized by SpriteView
    var scene: SKScene = {
        let scene = NavigatorScene()
        // The size will be set by the SpriteView automatically.
        // If you need to pass initial data to the scene, do it here.
        scene.scaleMode = .resizeFill // Fills the view, might crop slightly
        // scene.scaleMode = .aspectFill // Fills, maintains aspect ratio, might crop
        // scene.scaleMode = .aspectFit // Fits, maintains aspect ratio, might show letterbox
        return scene
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteView(scene: scene)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all) // Make the game truly full screen

            // Simple "Back" button overlay
            Button {
                print("Back button tapped in NavigatorGameView.")
                // Consider any cleanup for the scene if needed
                // scene.removeAllActions()
                // scene.removeAllChildren()
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(.system(size: 30)) // Using system font for SF Symbol sizing
                    .padding()
                    .foregroundColor(.white.opacity(0.6)) // Semi-transparent white
                    .background(Color.black.opacity(0.2)) // Slight background for visibility
                    .clipShape(Circle())
            }
            // Adjust padding to respect safe area, especially if top UI elements are present
            .padding(.leading)
            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)

        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true) // Explicitly hide the default back button
        .statusBar(hidden: true) // Optionally hide the status bar for full immersion
    }
}

struct NavigatorGameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigatorGameView()
            // .preferredColorScheme(.dark) // Preview in dark mode
            // .edgesIgnoringSafeArea(.all) // Ensure preview matches runtime if needed
    }
}