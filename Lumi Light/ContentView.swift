import SwiftUI
import SwiftData

struct ChatAreaGlobalGlowOverlay: View { // Keep this if you use it, or remove if not
    var glowOpacity: Double
    let horizontalInset: CGFloat = 15
    let topInset: CGFloat = 55
    let bottomInset: CGFloat = 70
    let glowCornerRadius: CGFloat = 12
    let shadowRadiusConfig: CGFloat = 10
    let shadowOpacityFactor: CGFloat = 0.6

    var body: some View {
        GeometryReader { screenProxy in
            RoundedRectangle(cornerRadius: glowCornerRadius)
                .fill(Color.clear)
                .shadow(
                    color: Color.sl_glowColor.opacity(glowOpacity * shadowOpacityFactor),
                    radius: glowOpacity > 0.05 ? shadowRadiusConfig : 0
                )
                .frame(
                    width: screenProxy.size.width - (2 * horizontalInset),
                    height: screenProxy.size.height - topInset - bottomInset
                )
                .position(x: screenProxy.size.width / 2,
                          y: topInset + (screenProxy.size.height - topInset - bottomInset) / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

struct ContentView: View {
    @EnvironmentObject private var llmService: LlmInferenceService
    @EnvironmentObject private var userData: UserData
    @Environment(\.modelContext) private var modelContext

    private let menuWidth: CGFloat = 250
    @State private var currentMenuOffset: CGFloat = 0
    @GestureState private var dragGestureOffset: CGFloat = .zero
    
    @State private var sessionToRename: ConversationSession? = nil

    @State private var sessionToConfirmDelete: ConversationSession? = nil
    @State private var showDeleteConfirmationPrompt = false

    private var actualVisualOffset: CGFloat { currentMenuOffset + dragGestureOffset }
    private var clampedOffset: CGFloat { max(0, min(actualVisualOffset, menuWidth)) }
    private var openPercentage: CGFloat { clampedOffset / menuWidth }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var chatViewLayer: some View {
        ZStack {
            ChatView()
                .id(llmService.activeSwiftDataSession?.id) // KEEP THIS
                .disabled(openPercentage > 0.01 && dragGestureOffset == .zero && sessionToRename == nil && !showDeleteConfirmationPrompt)
            Color.black
                .opacity(openPercentage * 0.4 * (sessionToRename != nil || showDeleteConfirmationPrompt ? 0.3 : 1.0) )
                .allowsHitTesting(openPercentage > 0.01 && sessionToRename == nil && !showDeleteConfirmationPrompt)
                .onTapGesture {
                    if openPercentage > 0.01 && sessionToRename == nil && !showDeleteConfirmationPrompt {
                        withAnimation(.interactiveSpring()) { currentMenuOffset = 0 }
                        hideKeyboard()
                    }
                }
        }
        .offset(x: clampedOffset)
        .blur(radius: (openPercentage * 4.0) + (sessionToRename != nil || showDeleteConfirmationPrompt ? 3.0 : 0.0) )
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
            },
            onRequestDeleteConfirmation: { session in
                self.sessionToConfirmDelete = session
                self.showDeleteConfirmationPrompt = true
            }
        )
        .frame(width: menuWidth)
        .offset(x: clampedOffset - menuWidth)
        .zIndex(0)
    }

    @ViewBuilder
    private var renameModalLayer: some View { /* ... as before ... */
        if sessionToRename != nil {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.sessionToRename = nil
                        hideKeyboard()
                    }
                RenamePromptView(
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
    
    @ViewBuilder
    private var deleteModalLayer: some View {
        if showDeleteConfirmationPrompt, let sessionToDelete = sessionToConfirmDelete {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    self.showDeleteConfirmationPrompt = false
                    self.sessionToConfirmDelete = nil
                }

            DeleteConfirmationPromptView(
                sessionTitle: sessionToDelete.title,
                onConfirmDelete: {
                    let deletedSessionID = sessionToDelete.id
                    modelContext.delete(sessionToDelete)
                    // try? modelContext.save()

                    llmService.handleSessionDeletion(
                        deletedSessionID: deletedSessionID,
                        newChatContext: modelContext
                    )
                    
                    self.showDeleteConfirmationPrompt = false
                    self.sessionToConfirmDelete = nil
                },
                onCancel: {
                    self.showDeleteConfirmationPrompt = false
                    self.sessionToConfirmDelete = nil
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                                      .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.2)),
                removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .center))
                                      .animation(.easeOut(duration: 0.25))
            ))
            .zIndex(3)
        }
    }

    var body: some View {
        ZStack {
            NavigationView {
                ZStack(alignment: .leading) {
                    sideMenuViewLayer
                    chatViewLayer
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
            }
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: currentMenuOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionToRename != nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showDeleteConfirmationPrompt)

            // ChatAreaGlobalGlowOverlay was here in your provided code.
            // If you don't want it, you can keep it removed as in your last version.
            // if llmService.chatAreaGlowOpacity > 0 {
            //     ChatAreaGlobalGlowOverlay(glowOpacity: llmService.chatAreaGlowOpacity)
            //         .zIndex(1.5)
            // }

            renameModalLayer
            deleteModalLayer
        }
        .environment(\.colorScheme, .dark)
    }

    func dragGesture() -> some Gesture { /* ... as before ... */
        DragGesture(minimumDistance: 10)
            .updating($dragGestureOffset) { value, state, transaction in
                if sessionToRename != nil || showDeleteConfirmationPrompt {
                    state = .zero; return
                }
                if currentMenuOffset == 0 && value.startLocation.x > 50 {
                    state = 0; return
                }
                if self.currentMenuOffset < self.menuWidth * 0.25 && value.translation.width > 15 {
                    self.hideKeyboard()
                }
                state = value.translation.width
            }
            .onEnded { value in
                if sessionToRename != nil || showDeleteConfirmationPrompt { return }

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

                if newTargetOffset == menuWidth { self.hideKeyboard() }
                currentMenuOffset = newTargetOffset
            }
    }
}

#Preview { /* ... as before ... */
    ContentView()
        .environmentObject(LlmInferenceService())
        .environmentObject(UserData.shared)
        .modelContainer(try! ModelContainer(for: ConversationSession.self, ChatMessageModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
