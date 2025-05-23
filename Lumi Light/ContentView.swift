import SwiftUI

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var llmService = LlmInferenceService(modelName: "gemma-2b-it-gpu-int8")
    @StateObject private var keyboard = KeyboardResponder()
    
    @State private var promptText: String = ""
    @State private var textEditorHeight: CGFloat = 38 // For GrowingTextEditor
    @FocusState private var isPromptFocused: Bool
    @State private var isResponseAreaGlowing = false
    
    let nasalizationFont = "Nasalization-Regular"
    let messageFontName = "Trebuchet MS"
    let singleLineMinHeight: CGFloat = 38
    private let collapsedMinHeight: CGFloat = 38 // Consistent min height

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
        
        appearance.titleTextAttributes = [.foregroundColor: titleUIColor, .font: titleFont, .shadow: shadow]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleUIColor, .font: UIFont(name: nasalizationFont, size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold), .shadow: shadow]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = titleUIColor
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color.sl_bgPrimary.ignoresSafeArea()

                if llmService.isLoadingModel {
                    loadingIndicatorView
                } else if let initError = llmService.initErrorMessage, !llmService.isModelReady {
                    errorStateView(message: initError)
                } else if llmService.isModelReady {
                    mainContentVStack
                } else {
                    // Fallback or initial state before .onAppear triggers loading
                    VStack {
                        Spacer()
                        Text("Preparing Lumi...")
                            .font(.custom(nasalizationFont, size: 18))
                            .foregroundColor(Color.sl_textSecondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Lumi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationBarToolbarContent } // Uses the extracted toolbar
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardNotification(notification) // Uses the extracted handler
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                handleKeyboardNotification(notification) // Uses the extracted handler
            }
            .onAppear {
                if !llmService.isModelReady && !llmService.isLoadingModel {
                    llmService.initializeAndLoadModel()                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Subviews & View Components
    private var loadingIndicatorView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.sl_textPrimary))
                .scaleEffect(1.5)
            Text("Initializing Lumi...")
                .font(.custom(nasalizationFont, size: 18))
                .foregroundColor(Color.sl_textSecondary)
                .padding(.top, 10)
        }
    }
    
    private func errorStateView(message: String) -> some View {
        VStack {
            Spacer()
            errorWarningView(message: message) // Uses the extracted error view
            Button("Retry Initialization") {
                llmService.initializeAndLoadModel()            }
            .font(.custom(nasalizationFont, size: 16))
            .padding()
            .foregroundColor(Color.sl_textOnAccent)
            .background(Color.sl_bgAccent)
            .cornerRadius(8)
            Spacer()
        }
        .padding()
    }

    private var mainContentVStack: some View {
        VStack(spacing: 0) {
            // Display non-critical errors or info messages within the chat view if needed
            // This is distinct from the full-screen initError state
            if let nonCriticalError = llmService.initErrorMessage, llmService.isModelReady { // Show error even if model ready, if it's a runtime issue
                 errorWarningView(message: nonCriticalError)
            } else if llmService.isLoadingModel && !llmService.isModelReady { // Subtle loading if main UI shown
                 Text("Lumi is initializing...")
                     .font(.custom(messageFontName, size: 13))
                     .foregroundColor(Color.sl_textSecondary)
                     .padding(.vertical, 4)
                     .frame(maxWidth: .infinity)
                     .background(Color.sl_bgSecondary.opacity(0.5))
                     .transition(.opacity.combined(with: .move(edge: .top)))
            }


            conversationListViewContainer // Uses the extracted container
                .frame(maxHeight: .infinity)

            inputAreaView() // Uses the extracted input area
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, keyboard.currentHeight > 0 ? 0 : 8)
        }
        .padding(.bottom, keyboard.currentHeight)
        .animation(Animation.customSpring(duration: keyboardAnimationDuration, bounce: 0.1), value: keyboard.currentHeight)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var conversationListViewContainer: some View {
        ScrollViewReader { scrollViewProxy in
            buildScrollView(with: scrollViewProxy) // Uses the extracted scroll view builder
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((llmService.isLoadingResponse && isResponseAreaGlowing ? Color.sl_glowColor : Color.clear).opacity(0.6),
                                lineWidth: llmService.isLoadingResponse && isResponseAreaGlowing ? 2 : 0)
                )
                .shadow(color: (llmService.isLoadingResponse && isResponseAreaGlowing ? Color.sl_glowColor : .clear).opacity(0.4),
                        radius: llmService.isLoadingResponse && isResponseAreaGlowing ? 8 : 0)
                .onChange(of: llmService.isLoadingResponse) { oldValue, newValue in // Changed from llmService.isLoading
                    handleGlowAnimation(isLoading: newValue)
                }
        }
        .background(Color.sl_bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, (llmService.initErrorMessage != nil && llmService.conversation.isEmpty && !llmService.isModelReady) ? 0 : 10) // Adjust top padding based on error display
    }

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
            scrollToBottom(proxy: scrollViewProxy, newConversation: newValue)
        }
    }
    
    @ViewBuilder
    private func inputAreaView() -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .leading) {
                GrowingTextEditor(
                    text: $promptText,
                    height: $textEditorHeight,
                    maxHeight: 120,
                    minHeight: collapsedMinHeight
                )
                .frame(height: textEditorHeight)
                .disabled(llmService.isLoadingResponse && !currentPromptCanBeStopped())
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
                .onSubmit(submitPrompt)
                // Removed .animation(nil, value: promptText) - height animation is on HStack

                if promptText.isEmpty && !isPromptFocused {
                    Text(placeholderText)
                        .font(.custom(nasalizationFont, size: 16))
                        .foregroundColor(Color.sl_textPlaceholder)
                        .padding(.leading, 5 + 4)
                        .padding(.vertical, 8 + 4)
                        .allowsHitTesting(false)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .layoutPriority(1)
            
            Button(action: submitOrStop) { // Uses the extracted action
                submitButtonContent // Uses the extracted content
            }
            .disabled(
                !llmService.isModelReady ||
                llmService.isLoadingResponse ||
                promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .animation(.easeInOut(duration: 0.15), value: textEditorHeight)
    }
    
    private var placeholderText: String {
        if llmService.isLoadingModel {
            return "Lumi is waking up..."
        } else if !llmService.isModelReady && llmService.initErrorMessage == nil {
             // This state might be brief if .onAppear triggers loading immediately
            return "Preparing Lumi..."
        } else if !llmService.isModelReady && llmService.initErrorMessage != nil {
            return "Lumi has an issue. See above."
        } else { // Model is ready
            return "Hi Matt, what can I help you with?"
        }
    }
    
    @ViewBuilder
    private var submitButtonContent: some View {
        HStack(spacing: llmService.isLoadingResponse ? 6 : 0) { // Changed from llmService.isLoading
            if llmService.isLoadingResponse { // Changed from llmService.isLoading
                if currentPromptCanBeStopped() { // Uses the extracted function
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
        .padding(.horizontal, llmService.isLoadingResponse && currentPromptCanBeStopped() ? 10 : (llmService.isLoadingResponse ? 12: 0) ) // Changed
        .frame(width: llmService.isLoadingResponse && currentPromptCanBeStopped() ? 70 : 44, height: 44) // Changed
        .foregroundColor(Color.sl_textOnAccent)
        .background(llmService.isLoadingResponse && currentPromptCanBeStopped() ? Color.sl_bgDanger : Color.sl_bgAccent) // Changed
        .cornerRadius(llmService.isLoadingResponse && currentPromptCanBeStopped() ? 12 : 22) // Changed
        .shadow(color: (llmService.isLoadingResponse && currentPromptCanBeStopped()) ? Color.red.opacity(0.5) : Color.sl_glowColor.opacity(0.6), radius: 5, x: 0, y: 2) // Changed
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
    
    // MARK: - Helper Views & Functions
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
            .padding(.top, 5) // Ensure this doesn't add too much when initError also shown above
    }
    
    private func submitOrStop() {
        if llmService.isLoadingResponse { // Changed from llmService.isLoading
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
        
        // Consider a slight delay *only if needed* for keyboard to start dismissing
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + (keyboard.currentHeight > 0 ? keyboardAnimationDuration * 0.5 : 0) + 0.05) { // Try to time after keyboard starts moving
            self.llmService.generateResponseStreaming(prompt: textToSend.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    private func currentPromptCanBeStopped() -> Bool {
        // This depends on your LlmInferenceService logic
        return llmService.isLoadingResponse // Assuming you can stop if it's loading a response
    }

    private func handleKeyboardNotification(_ notification: Notification) {
        if let anim = KeyboardResponder.keyboardAnimation(from: notification) {
            self.keyboardAnimationDuration = anim.duration
            self.keyboardAnimationCurve = anim.curve
        }
    }

    private func handleGlowAnimation(isLoading: Bool) {
        if isLoading {
            isResponseAreaGlowing = false // Reset before starting new animation
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

    private func scrollToBottom(proxy: ScrollViewProxy, newConversation: [ChatMessage]) {
        if let lastMessage = newConversation.last {
            let animation = Animation.customSpring(duration: self.keyboardAnimationDuration, bounce: 0.1)
            withAnimation(animation) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
} // End of ContentView struct

// MARK: - Animation Extension (MUST BE PRESENT)
extension Animation {
    static func customSpring(duration: TimeInterval, bounce: CGFloat = 0.0) -> Animation {
        // Using your preferred timing curve
        return .timingCurve(0.45, 1.05, 0.35, 1.0, duration: duration)
    }
}

// MARK: - Dummy/Placeholder Implementations (Ensure you have your actual ones)
// These are just to make ContentView compile standalone. Replace with your definitions.
/*
class LlmInferenceService: ObservableObject { /* ... see previous response ... */ }
class KeyboardResponder: ObservableObject { /* ... see previous response ... */ }
struct MessageView: View { var message: ChatMessage; var body: some View { Text(message.content) } }
struct ChatMessage: Identifiable { var id = UUID(); var sender: Sender; var text: String }
enum Sender { case user, lumi, error(isCritical: Bool = false), info }
struct DotLoadingView: View { var color: Color; var dotSize: CGFloat; var spacing: CGFloat; var animationDuration: TimeInterval? = nil; var body: some View { Text("...") } }
*/
