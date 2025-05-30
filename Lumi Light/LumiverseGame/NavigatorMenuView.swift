//
//  NavigatorMenuView.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/30/25.
//


// File: LumiverseGame/Navigator/NavigatorMenuView.swift
/* import SwiftUI

// TODO: Consider moving this Color extension to a more global utilities file if used elsewhere.
extension Color {
    init(hex: String) { // redundant with colorpalette
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Default to black if invalid
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct NavigatorMenuView: View {
    @State private var isGameActive = false // Controls navigation to the game scene

    // Font settings
    let customFontName = "Nasalization-Regular"
    let titleFontSize: CGFloat = 34 // Adjusted for impact
    let buttonFontSize: CGFloat = 18

    var body: some View {
        ZStack {
            // Themed background
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#0A121F"), Color(hex: "#03080F")]), // Darker, space-like
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            // Subtle starfield or abstract network for background could be added here later as another ZStack layer

            VStack(spacing: 35) { // Increased spacing a bit
                Spacer()
                
                Text("LUMI NAVIGATOR")
                    .font(Font.custom(customFontName, size: titleFontSize))
                    .kerning(1.5) // Add some letter spacing for style
                    .foregroundColor(Color.cyan.opacity(0.9))
                    .shadow(color: .cyan.opacity(0.7), radius: 8, x: 0, y: 0) // Enhanced glow
                    .padding(.bottom, 50)

                // NavigationLink is hidden and activated by the button's state change
                NavigationLink(destination: NavigatorGameView(), isActive: $isGameActive) {
                    EmptyView()
                }
                .isDetailLink(false) // Important for correct push navigation behavior

                Button {
                    print("Start Data Harvest Run button tapped")
                    isGameActive = true // This will trigger the NavigationLink
                } label: {
                    Text("START DATA HARVEST")
                        .font(Font.custom(customFontName, size: buttonFontSize))
                        .padding(EdgeInsets(top: 15, leading: 25, bottom: 15, trailing: 25))
                        .frame(maxWidth: 320)
                        .background(Color.cyan.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan, lineWidth: 1)
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 5)
                }

                Button {
                    // TODO: Implement navigation to the Navigator Upgrades screen (Phase 2)
                    print("View Upgrades button tapped (Not implemented yet)")
                } label: {
                    Text("VIEW UPGRADES")
                        .font(Font.custom(customFontName, size: buttonFontSize))
                        .padding(EdgeInsets(top: 15, leading: 25, bottom: 15, trailing: 25))
                        .frame(maxWidth: 320)
                        .background(Color.orange.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 5)
                }
                
                // Placeholder for Orbital Ops button (Phase 3)
                // Button("ORBITAL OPS") { /* Logic to navigate to OrbitalOpsView */ }
                // .font(Font.custom(customFontName, size: buttonFontSize))
                // ... styling ...

                Spacer()
                Spacer() // Pushes content towards center more
            }
            .padding(.horizontal, 30) // Main content padding
        }
        .navigationBarHidden(true) // Keep Nav bar hidden for a clean game menu
    }
}

struct NavigatorMenuView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Essential for NavigationLink previews
            NavigatorMenuView()
        }
        // .preferredColorScheme(.dark) // Preview in dark mode
    }
}*/

