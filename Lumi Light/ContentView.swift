import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var llmService: LlmInferenceService // Ensure LlmInferenceService is ObservableObject
    @EnvironmentObject private var userData: UserData // Ensure UserData is ObservableObject
    // @Environment(\.modelContext) private var modelContext // Only if directly needed by ContentView save logic

    private let menuWidth: CGFloat = 250
    @State private var currentMenuOffset: CGFloat = 0 // 0 is closed, menuWidth is open
    @GestureState private var dragGestureOffset: CGFloat = .zero // Tracks real-time drag translation

    // State to manage the rename prompt presentation
    @State private var sessionToRename: ConversationSession? = nil

    // Computed properties for menu state
    private var actualVisualOffset: CGFloat { currentMenuOffset + dragGestureOffset }
    private var clampedOffset: CGFloat { max(0, min(actualVisualOffset, menuWidth)) }
    private var openPercentage: CGFloat { clampedOffset / menuWidth }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) { // Main ZStack for layering menu, content, and modal
                
                // ChatView Container (middle layer)
                ZStack {
                    ChatView()
                        // Disable ChatView content interaction if menu is open (and not being dragged)
                        // AND if the rename modal is NOT being shown
                        .disabled(openPercentage > 0.01 && dragGestureOffset == .zero && sessionToRename == nil)

                    // Dimming overlay for when the side menu is open
                    Color.black
                        // Dim effect is less if the rename modal (which has its own dim) is also up
                        .opacity(openPercentage * 0.4 * (sessionToRename != nil ? 0.3 : 1.0))
                        // Allow tap to close side menu only if menu is open AND rename modal is NOT shown
                        .allowsHitTesting(openPercentage > 0.01 && sessionToRename == nil)
                        .onTapGesture {
                            withAnimation(.interactiveSpring()) {
                                currentMenuOffset = 0 // Close side menu
                            }
                            hideKeyboard()
                        }
                }
                .offset(x: clampedOffset) // Moves ChatView to reveal SideMenu
                .blur(radius: (openPercentage * 4.0) + (sessionToRename != nil ? 3.0 : 0.0)) // More blur if modal up
                .zIndex(1) // ChatView container is above SideMenu content layer

                // SideMenu (bottom layer, revealed by ChatView offset)
                SideMenuView(
                    openPercentage: openPercentage,
                    closeMenuAction: {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                            currentMenuOffset = 0 // Close side menu
                        }
                        hideKeyboard()
                    },
                    onRequestRename: { session in // Callback from SideMenu
                        self.sessionToRename = session // Trigger the rename modal
                    }
                )
                .frame(width: menuWidth)
                .offset(x: clampedOffset - menuWidth) // Positions SideMenu off-screen or on-screen
                .zIndex(0) // SideMenu content layer

                // MODAL PRESENTATION LAYER (Topmost)
                if sessionToRename != nil {
                    // This ZStack ensures the modal components (dimming + prompt) are centered
                    ZStack {
                        // Dimming background for the modal
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .onTapGesture {
                                self.sessionToRename = nil // Dismiss modal on tap outside
                                hideKeyboard()
                            }

                        // Rename Prompt View (the card)
                        RenamePromptView(
                            sessionToRename: sessionToRename!, // Safe due to the if condition
                            onSave: {
                                // RenamePromptView modifies the @Bindable sessionToRename directly.
                                // This closure is now primarily for dismissal.
                                self.sessionToRename = nil
                                hideKeyboard()
                            },
                            onCancel: {
                                self.sessionToRename = nil
                                hideKeyboard()
                            }
                        )
                        // RenamePromptView has its own internal styling (card background, shadow, maxWidth)
                    }
                    .zIndex(2) // Modal layer on top of ChatView (1) and SideMenu (0)
                    .transition(.asymmetric( // Transition for modal appearance
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                                       .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.2)),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                                       .animation(.easeOut(duration: 0.25))
                    ))
                }
            }
            .gesture(dragGesture()) // Main drag gesture for opening/closing the side menu
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        hideKeyboard()
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                            currentMenuOffset = (currentMenuOffset == 0) ? menuWidth : 0 // Toggle menu
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(Color.sl_textPrimary) // Ensure this color is defined
                    }
                }
            }
            .navigationTitle("Lumi")
            .navigationBarTitleDisplayMode(.inline)
            // Animation for SideMenu sliding based on currentMenuOffset
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: currentMenuOffset)
            // Animation for modal presence/absence
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionToRename != nil)
        }
        .environment(\.colorScheme, .dark)
    }

    // Corrected dragGesture function
    func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragGestureOffset) { value, state, transaction in
                // Attempt to restrict drag initiation to the edge when menu is closed
                if currentMenuOffset == 0 && value.startLocation.x > 50 { // 50 is an arbitrary edge width
                     state = 0 // Prevent dragGestureOffset from updating if drag starts too far from edge
                     return
                }
                
                // Hide keyboard if dragging to open significantly
                if self.currentMenuOffset < self.menuWidth * 0.25 && value.translation.width > 15 {
                    self.hideKeyboard()
                }
                state = value.translation.width // Update live drag offset
            }
            .onEnded { value in
                // Use the original robust snapping logic
                let combinedOffset = currentMenuOffset + value.translation.width
                let predictedEndOffset = currentMenuOffset + value.predictedEndTranslation.width
                let threshold = menuWidth / 3
                let predictiveThreshold = menuWidth / 2
                var newTargetOffset: CGFloat = 0 // Default target to closed

                if (predictedEndOffset > predictiveThreshold && value.translation.width > 0) ||
                   (combinedOffset > threshold && value.translation.width > 0 && currentMenuOffset == 0) {
                    newTargetOffset = menuWidth // Snap open
                } else if (predictedEndOffset < (menuWidth - predictiveThreshold) && value.translation.width < 0 && currentMenuOffset == menuWidth) ||
                          (combinedOffset < (menuWidth - threshold) && value.translation.width < 0 && currentMenuOffset == menuWidth) {
                    newTargetOffset = 0 // Snap closed
                } else if combinedOffset > menuWidth / 2 { // General snap based on current position
                    newTargetOffset = menuWidth
                } else {
                    newTargetOffset = 0
                }

                if newTargetOffset == menuWidth { // If menu snaps open
                    self.hideKeyboard()
                }
                currentMenuOffset = newTargetOffset // Commit the final offset
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(LlmInferenceService())
        .environmentObject(UserData.shared)
        .modelContainer(for: [ConversationSession.self, ChatMessageModel.self], inMemory: true)
}
