import SwiftUI

// Ensure SideMenuNavigationTarget enum is defined and accessible
// (e.g., from SideMenuView.swift or a shared file)
// enum SideMenuNavigationTarget: Hashable { case settings }

struct ContentView: View {
    @EnvironmentObject private var llmService: LlmInferenceService
    @EnvironmentObject private var userData: UserData
    // @Environment(\.modelContext) private var modelContext

    private let menuWidth: CGFloat = 250
    @State private var currentMenuOffset: CGFloat = 0
    @GestureState private var dragGestureOffset: CGFloat = .zero

    @State private var sessionToRename: ConversationSession? = nil

    private var actualVisualOffset: CGFloat { currentMenuOffset + dragGestureOffset }
    private var clampedOffset: CGFloat { max(0, min(actualVisualOffset, menuWidth)) }
    private var openPercentage: CGFloat { clampedOffset / menuWidth }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Extracted View Layers
    private var chatViewLayer: some View {
        ZStack { // ChatView Container
            ChatView()
                .disabled(openPercentage > 0.01 && dragGestureOffset == .zero && sessionToRename == nil)

            Color.black // Dimming overlay for side menu
                .opacity(openPercentage * 0.4 * (sessionToRename != nil ? 0.3 : 1.0) )
                .allowsHitTesting(openPercentage > 0.01 && sessionToRename == nil)
                .onTapGesture {
                    withAnimation(.interactiveSpring()) {
                        currentMenuOffset = 0
                    }
                    hideKeyboard()
                }
        }
        .offset(x: clampedOffset)
        .blur(radius: (openPercentage * 4.0) + (sessionToRename != nil ? 3.0 : 0.0) )
        .zIndex(1)
    }

    private var sideMenuViewLayer: some View {
        SideMenuView(
            openPercentage: openPercentage,
            closeMenuAction: {
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                    currentMenuOffset = 0
                }
                hideKeyboard()
            },
            onRequestRename: { session in
                self.sessionToRename = session
            }
            // No activeNavigationTarget argument
        )
        .frame(width: menuWidth)
        .offset(x: clampedOffset - menuWidth)
        .zIndex(0)
    }

    @ViewBuilder // Use @ViewBuilder for conditional content
    private var renameModalLayer: some View {
        if sessionToRename != nil {
            ZStack { // Inner ZStack for centering modal
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.sessionToRename = nil
                        hideKeyboard()
                    }

                RenamePromptView( // Assuming RenamePromptView.swift exists
                    sessionToRename: sessionToRename!,
                    onSave: {
                        self.sessionToRename = nil
                        hideKeyboard()
                    },
                    onCancel: {
                        self.sessionToRename = nil
                        hideKeyboard()
                    }
                )
            }
            .zIndex(2)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                               .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.2)),
                removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                               .animation(.easeOut(duration: 0.25))
            ))
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) {
                chatViewLayer    // Using extracted layer
                sideMenuViewLayer  // Using extracted layer
                renameModalLayer // Using extracted layer
            }
            .gesture(dragGesture())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        hideKeyboard()
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                            currentMenuOffset = (currentMenuOffset == 0) ? menuWidth : 0
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(Color.sl_textPrimary)
                    }
                }
            }
            .navigationTitle("Lumi")
            .navigationBarTitleDisplayMode(.inline)
          
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: currentMenuOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionToRename != nil)
        }
        .environment(\.colorScheme, .dark)
    }

    func dragGesture() -> some Gesture {
        // ... (Your existing dragGesture function) ...
        DragGesture(minimumDistance: 10)
            .updating($dragGestureOffset) { value, state, transaction in
                if currentMenuOffset == 0 && value.startLocation.x > 50 {
                     state = 0
                     return
                }
                if self.currentMenuOffset < self.menuWidth * 0.25 && value.translation.width > 15 {
                    self.hideKeyboard()
                }
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
                    newTargetOffset = menuWidth
                } else if (predictedEndOffset < (menuWidth - predictiveThreshold) && value.translation.width < 0 && currentMenuOffset == menuWidth) ||
                          (combinedOffset < (menuWidth - threshold) && value.translation.width < 0 && currentMenuOffset == menuWidth) {
                    newTargetOffset = 0
                } else if combinedOffset > menuWidth / 2 {
                    newTargetOffset = menuWidth
                } else {
                    newTargetOffset = 0
                }

                if newTargetOffset == menuWidth {
                    self.hideKeyboard()
                }
                currentMenuOffset = newTargetOffset
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(LlmInferenceService())
        .environmentObject(UserData.shared)
        .modelContainer(for: [ConversationSession.self, ChatMessageModel.self], inMemory: true)
}
