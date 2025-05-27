import SwiftUI

struct ContentView: View {
    private let menuWidth: CGFloat = 250
    @State private var currentMenuOffset: CGFloat = 0 // 0 is closed, menuWidth is open
    @GestureState private var dragGestureOffset: CGFloat = .zero

    // Computed properties for clarity
    private var actualVisualOffset: CGFloat {
        currentMenuOffset + dragGestureOffset
    }

    private var clampedOffset: CGFloat {
        max(0, min(actualVisualOffset, menuWidth))
    }

    private var openPercentage: CGFloat {
        clampedOffset / menuWidth
    }

    // To pass to SideMenuView for internal logic if needed, or for ChatView button
    private var isMenuConsideredOpen: Bool { // This isn't strictly used by the menu opening logic itself anymore but can be useful
        currentMenuOffset == menuWidth
    }
    
    // Access LlmInferenceService for the "New Chat" button if needed from ChatView's StateObject
    // ... (your existing comments)

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) {
                SideMenuView(openPercentage: openPercentage)
                    .frame(width: menuWidth)
                    .offset(x: clampedOffset - menuWidth) // Slides from -menuWidth to 0
                    .zIndex(0)

                // Container for ChatView and its specific interactive dimming/blur overlay
                ZStack {
                    ChatView() // No longer takes isMenuOpen

                    // Dimming overlay for ChatView content
                    Color.black
                        .opacity(openPercentage * 0.4) // Adjust dim amount as needed
                        .allowsHitTesting(openPercentage > 0.01) // Active when even slightly open
                        .onTapGesture { // Tap on dimmed ChatView closes menu
                            withAnimation(.interactiveSpring()) {
                                currentMenuOffset = 0
                            }
                        }
                }
                .offset(x: clampedOffset)
                .blur(radius: openPercentage * 4.0) // Adjust blur amount
                .disabled(openPercentage > 0.01 && dragGestureOffset == .zero)
                .zIndex(1)

                // Full screen tap-to-close overlay (catches taps outside menu)
                // You have this commented out, which is fine as the above overlay handles taps on ChatView
                // if openPercentage > 0.01 && dragGestureOffset == .zero {
                //     Color.clear
                //         .contentShape(Rectangle())
                //         .onTapGesture {
                //             withAnimation(.interactiveSpring()) {
                //                 currentMenuOffset = 0
                //             }
                //         }
                //         .zIndex(2) // On top of everything else
                // }
            }
            .gesture(dragGesture()) // Apply the gesture
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // --- KEYBOARD FIX FOR BUTTON ---
                        hideKeyboard()
                        // --- END FIX ---
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) { // Explicit animation for button tap
                            currentMenuOffset = (currentMenuOffset == 0) ? menuWidth : 0
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(Color.sl_textPrimary) // Use your color
                    }
                }
                // ... (Your comments about "New Chat" button)
            }
            .navigationTitle("Lumi")
            .navigationBarTitleDisplayMode(.inline)
            // This animation applies to changes in currentMenuOffset (e.g., from drag end)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: currentMenuOffset)
        }
        .environment(\.colorScheme, .dark)
    }

    func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 10) // Only act on a real drag
            .updating($dragGestureOffset) { value, state, transaction in
                // --- KEYBOARD FIX FOR SWIPE (START) ---
                // If menu is mostly closed and user is dragging to open it significantly
                if self.currentMenuOffset < self.menuWidth * 0.25 && value.translation.width > 15 {
                    self.hideKeyboard()
                }
                // --- END FIX ---
                state = value.translation.width
            }
            .onEnded { value in
                let combinedOffset = currentMenuOffset + value.translation.width
                let predictedEndOffset = currentMenuOffset + value.predictedEndTranslation.width
                let threshold = menuWidth / 3
                let predictiveThreshold = menuWidth / 2
                
                var newTargetOffset: CGFloat = 0

                if (predictedEndOffset > predictiveThreshold && value.translation.width > 0) ||
                   (combinedOffset > threshold && value.translation.width > 0 && currentMenuOffset == 0) {
                    newTargetOffset = menuWidth // Snap open
                } else if (predictedEndOffset < predictiveThreshold && value.translation.width < 0) ||
                          (combinedOffset < menuWidth - threshold && value.translation.width < 0 && currentMenuOffset == menuWidth) {
                    newTargetOffset = 0 // Snap closed
                } else if combinedOffset > menuWidth / 2 {
                    newTargetOffset = menuWidth
                } else {
                    newTargetOffset = 0
                }

                // --- KEYBOARD FIX FOR SWIPE (END) ---
                // Ensure keyboard is dismissed if menu ends up open
                if newTargetOffset == menuWidth {
                    self.hideKeyboard()
                }
                // --- END FIX ---
                
                // The .animation modifier on the ZStack will handle animating this change
                currentMenuOffset = newTargetOffset
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserData.shared)
}
