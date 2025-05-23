import SwiftUI

struct ContentView: View {
    @StateObject private var llmService = LlmInferenceService(modelName: "gemma-2b-it-gpu-int8")
    @StateObject private var keyboard = KeyboardResponder()
    
    @State private var promptText: String = ""
    @State private var textEditorHeight: CGFloat = 38
    @FocusState private var isPromptFocused: Bool
    @State private var isResponseAreaGlowing = false
    
    let nasalizationFont = "Nasalization-Regular"
    let messageFontName = "Trebuchet MS"
    let singleLineMinHeight: CGFloat = 38
    private let collapsedMinHeight: CGFloat = 19
    private let editorMaxLines = 4

    
    @State private var keyboardAnimationDuration: TimeInterval = 0.25
    @State private var keyboardAnimationCurve: UIView.AnimationOptions = .curveEaseInOut
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.sl_bgPrimary)
        
        let titleFont = UIFont(name: nasalizationFont, size: 22) ?? UIFont.systemFont(ofSize: 22, weight: .bold)
        let titleUIColor = UIColor(Color.sl_textPrimary)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(Color.sl_glowColor).withAlphaComponent(0.5)
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowBlurRadius = 2
        
        appearance.titleTextAttributes = [
            .foregroundColor: titleUIColor,
            .font: titleFont,
            .shadow: shadow
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: titleUIColor,
            .font: UIFont(name: nasalizationFont, size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold),
            .shadow: shadow
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = titleUIColor
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color.sl_bgPrimary.ignoresSafeArea()
                mainContentVStack
            }
            .navigationTitle("Lumi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationBarToolbarContent }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardNotification(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                handleKeyboardNotification(notification)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Main Content VStack
    private var mainContentVStack: some View {
        VStack(spacing: 0) {
            if let initError = llmService.initErrorMessage, llmService.conversation.isEmpty {
                errorWarningView(message: initError)
            }
            
            conversationListViewContainer
            
            inputAreaView()
                .padding(.horizontal)
                .padding(.top, 8)
              //  .padding(.bottom, keyboard.currentHeight > 0 ? 0 : 8)
        }
        .padding(.bottom, keyboard.currentHeight)
        .animation(Animation.customSpring(duration: keyboardAnimationDuration, bounce: 0.1), value: keyboard.currentHeight)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Conversation List Container
    private var conversationListViewContainer: some View {
        ScrollViewReader { scrollViewProxy in
            buildScrollView(with: scrollViewProxy)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((llmService.isLoading && isResponseAreaGlowing ? Color.sl_glowColor : Color.clear).opacity(0.6),
                                lineWidth: llmService.isLoading && isResponseAreaGlowing ? 2 : 0)
                )
                .shadow(color: (llmService.isLoading && isResponseAreaGlowing ? Color.sl_glowColor : .clear).opacity(0.4),
                        radius: llmService.isLoading && isResponseAreaGlowing ? 8 : 0)
                .onChange(of: llmService.isLoading) { oldValue, newValue in
                    if newValue {
                        isResponseAreaGlowing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                isResponseAreaGlowing = true
                            }
                        }
                    } else {
                        withAnimation(Animation.easeInOut(duration: 0.3)) {
                            isResponseAreaGlowing = false
                        }
                    }
                }
        }
        .background(Color.sl_bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, (llmService.initErrorMessage != nil && llmService.conversation.isEmpty) ? 0 : 10)
    }

    // MARK: - Build ScrollView
    @ViewBuilder
    private func buildScrollView(with scrollViewProxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(llmService.conversation) { message in
                    MessageView(message: message)
                        .id(message.id)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, keyboard.currentHeight > 0 ? 0 : singleLineMinHeight + 24)
        }
        .onChange(of: llmService.conversation) { oldValue, newValue in
            if let lastMessage = newValue.last {
                let animation = Animation.customSpring(duration: self.keyboardAnimationDuration, bounce: 0.1)
                withAnimation(animation) {
                    scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Input Area View
    @ViewBuilder
    private func inputAreaView() -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                GrowingTextEditor(
                    text: $promptText,
                    height: $textEditorHeight,
                    maxHeight: 120,
                    minHeight: singleLineMinHeight
                )
                .font(.custom(nasalizationFont, size: 16))
                .foregroundColor(Color.sl_textPrimary)
                .scrollContentBackground(.hidden)
                .frame(height: textEditorHeight)
                //.fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.sl_bgTertiary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPromptFocused ? Color.sl_glowColor.opacity(0.8)
                                                : Color.sl_borderPrimary,
                                lineWidth: isPromptFocused ? 1.5 : 1)
                )
                .shadow(color: isPromptFocused ? Color.sl_glowColor.opacity(0.6)
                                              : .clear,
                        radius: isPromptFocused ? 6 : 0)
                .focused($isPromptFocused)
                .disabled(llmService.isLoading && !currentPromptCanBeStopped())
                .onSubmit(submitPrompt)
                .animation(.easeInOut(duration: 0.1), value: textEditorHeight)

                if promptText.isEmpty && !isPromptFocused {
                    Text("Hi Matt, what can I do for you?")
                        .font(.custom(nasalizationFont, size: 16))
                        .foregroundColor(Color.sl_textPlaceholder)
                        .padding(.leading, 10 + 4)
                        .padding(.vertical, 4 + 4)
                        .allowsHitTesting(false)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .layoutPriority(1)
            
            Button(action: submitOrStop) {
                HStack(spacing: llmService.isLoading ? 6 : 0) {
                    if llmService.isLoading {
                        if currentPromptCanBeStopped() {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .medium))
                            DotLoadingView(color: Color.sl_textOnAccent, dotSize: 5, spacing: 2, animationDuration: 0.7)
                            
                        } else {
                            DotLoadingView(color: Color.sl_textOnAccent, dotSize: 6, spacing: 3)
                        }
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                
                .padding(.horizontal, llmService.isLoading && currentPromptCanBeStopped() ? 10 : (llmService.isLoading ? 12: 0) )
                .frame(width: llmService.isLoading && currentPromptCanBeStopped() ? 70 : 44, height: 44)
                .foregroundColor(Color.sl_textOnAccent)
                .background(llmService.isLoading && currentPromptCanBeStopped() ? Color.sl_bgDanger : Color.sl_bgAccent)
                .cornerRadius(llmService.isLoading && currentPromptCanBeStopped() ? 12 : 22)
                .shadow(color: (llmService.isLoading && currentPromptCanBeStopped()) ? Color.red.opacity(0.5) : Color.sl_glowColor.opacity(0.6), radius: 5, x: 0, y: 2)
            }
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !llmService.isLoading)
        }
    }
    
    // MARK: - Toolbar Content
    @ToolbarContentBuilder
    private var navigationBarToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                isPromptFocused = false
            }
            .font(.custom(nasalizationFont, size: 16))
            .foregroundColor(Color.sl_textPrimary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                llmService.startNewChat()
                promptText = ""
                isPromptFocused = false
            } label: {
                Image(systemName: "plus.bubble.fill")
                    .foregroundColor(Color.sl_textPrimary)
                    .font(.system(size: 17, weight: .medium))
            }
        }
    }
    
    // MARK: - Helper Views & Functions (Full Implementations)
    private func errorWarningView(message: String) -> some View {
        Text(message)
            .font(.custom(messageFontName, size: 14))
            .foregroundColor(Color.sl_errorText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.sl_errorBg.opacity(0.15))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sl_errorText.opacity(0.5), lineWidth: 1))
            .padding(.horizontal)
            .padding(.top, 5)
    }
    
    private func submitOrStop() {
        if llmService.isLoading {
            if currentPromptCanBeStopped() {
                llmService.stopGeneration()
                if isPromptFocused { isPromptFocused = false }
            }
        } else {
            submitPrompt()
        }
    }
    
    private func submitPrompt() {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }
        
        isPromptFocused = false
        
        let textToSend = promptText
        promptText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (keyboard.currentHeight > 0 ? keyboardAnimationDuration : 0) + 0.05) {
            self.llmService.generateResponseStreaming(prompt: textToSend.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    private func currentPromptCanBeStopped() -> Bool {
        return llmService.isLoading
    }

    private func handleKeyboardNotification(_ notification: Notification) {
        if let anim = KeyboardResponder.keyboardAnimation(from: notification) {
            self.keyboardAnimationDuration = anim.duration
            self.keyboardAnimationCurve = anim.curve
        }
    }
} // End of ContentView struct

// MARK: - Animation Extension
extension Animation {
    static func customSpring(duration: TimeInterval, bounce: CGFloat = 0.0) -> Animation {
        // Using your original preferred timing curve:
        return .timingCurve(0.45, 1.05, 0.35, 1.0, duration: duration)
    }
}
