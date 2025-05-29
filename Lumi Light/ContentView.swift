import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var llmService: LlmInferenceService
    @EnvironmentObject private var userData: UserData
    private let menuWidth: CGFloat = 250
    @State private var currentMenuOffset: CGFloat = 0
    @GestureState private var dragGestureOffset: CGFloat = .zero

    private var actualVisualOffset: CGFloat { currentMenuOffset + dragGestureOffset }
    private var clampedOffset: CGFloat { max(0, min(actualVisualOffset, menuWidth)) }
    private var openPercentage: CGFloat { clampedOffset / menuWidth }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) {
                SideMenuView(openPercentage: openPercentage) // NO closeMenuAction yet
                .frame(width: menuWidth)
                .offset(x: clampedOffset - menuWidth)
                .zIndex(0)

                ZStack {
                    ChatView()
                    Color.black
                        .opacity(openPercentage * 0.4)
                        .allowsHitTesting(openPercentage > 0.01)
                        .onTapGesture {
                            withAnimation(.interactiveSpring()) {
                                currentMenuOffset = 0
                            }
                        }
                }
                .offset(x: clampedOffset)
                .blur(radius: openPercentage * 4.0)
                .disabled(openPercentage > 0.01 && dragGestureOffset == .zero)
                .zIndex(1)
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
        }
        .environment(\.colorScheme, .dark)
    }

    func dragGesture() -> some Gesture { /* ... Your existing correct logic ... */
        DragGesture(minimumDistance: 10)
            .updating($dragGestureOffset) { value, state, transaction in
                if self.currentMenuOffset < self.menuWidth * 0.25 && value.translation.width > 15 { self.hideKeyboard() }
                state = value.translation.width
            }
            .onEnded { value in
                let combinedOffset = currentMenuOffset + value.translation.width; let predictedEndOffset = currentMenuOffset + value.predictedEndTranslation.width
                let threshold = menuWidth / 3; let predictiveThreshold = menuWidth / 2
                var newTargetOffset: CGFloat = 0
                if (predictedEndOffset > predictiveThreshold && value.translation.width > 0) || (combinedOffset > threshold && value.translation.width > 0 && currentMenuOffset == 0) { newTargetOffset = menuWidth }
                else if (predictedEndOffset < predictiveThreshold && value.translation.width < 0) || (combinedOffset < menuWidth - threshold && value.translation.width < 0 && currentMenuOffset == menuWidth) { newTargetOffset = 0 }
                else if combinedOffset > menuWidth / 2 { newTargetOffset = menuWidth }
                else { newTargetOffset = 0 }
                if newTargetOffset == menuWidth { self.hideKeyboard() }
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
