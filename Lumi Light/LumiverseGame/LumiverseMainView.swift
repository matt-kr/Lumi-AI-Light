//
//  LumiverseMainView.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/29/25.
//

/*import Foundation
// File: LumiverseGame/LumiverseMainView.swift
import SwiftUI

struct LumiverseMainView: View {
    @Environment(\.dismiss) var dismiss

    // In later phases, you'll introduce a @StateObject for GameState here:
    // @StateObject var gameState = GameState()

    let customFontName = "Nasalization-Regular"
    let toolbarTitleFontSize: CGFloat = 20

    var body: some View {
        NavigationView {
            NavigatorMenuView() // The first screen of the game
                // .environmentObject(gameState) // Pass game state down in later phases
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            // Consider any game saving logic here if needed before dismissing
                            print("Exiting Lumiverse Game.")
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .foregroundColor(.gray) // Adjust color for visibility
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("LUMIVERSE")
                            .font(Font.custom(customFontName, size: toolbarTitleFontSize))
                            .foregroundColor(Color(UIColor.label)) // Adapts to light/dark theme
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                // Hides the system back button text if a view pushes from here
                .navigationViewStyle(StackNavigationViewStyle())
        }
        // If your game should always be dark, uncomment the line below:
        // .preferredColorScheme(.dark)
    }
}

struct LumiverseMainView_Previews: PreviewProvider {
    static var previews: some View {
        LumiverseMainView()
            // .preferredColorScheme(.dark) // Preview in dark mode
    }
}*/
