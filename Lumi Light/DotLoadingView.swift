import SwiftUI

struct DotLoadingView: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat
    let animationDuration: Double
    let scaleEffect: CGFloat // How much it shrinks

    @State private var scales: [CGFloat] = [1, 1, 1]

    // Explicit Initializer with default values ONLY in the signature
        init(color: Color,
             dotSize: CGFloat = 7,         // Default value in init signature
             spacing: CGFloat = 3,         // Default value in init signature
             animationDuration: Double = 0.6,// Default value in init signature
             scaleEffect: CGFloat = 0.5) { // Default value in init signature
            self.color = color
            self.dotSize = dotSize
            self.spacing = spacing
            self.animationDuration = animationDuration
            self.scaleEffect = scaleEffect
        }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scales[i])
            }
        }
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                Animation.easeInOut(duration: animationDuration)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * (animationDuration / 2.5)) // Stagger the animation
            ) {
                scales[i] = scaleEffect
            }
        }
    }
}
//  DotLoadingView.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/11/25.
//

