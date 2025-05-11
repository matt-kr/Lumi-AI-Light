import SwiftUI

struct ContentView: View {
    @StateObject private var llmService = LlmInferenceService(modelName: "gemma-2b-it-gpu-int8")
    @StateObject private var keyboard = KeyboardResponder() // << --- ADDED

    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    @State private var isResponseAreaGlowing = false

    let nasalizationFont = "Nasalization-Regular"
    let messageFontName = "Trebuchet MS"
    let singleLineMinHeight: CGFloat = 38

    // Store current keyboard animation properties
    @State private var keyboardAnimationDuration: TimeInterval = 0.25
    @State private var keyboardAnimationCurve: UIView.AnimationOptions = .curveEaseInOut


    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.sl_bgPrimary)

        let titleFont = UIFont(name: nasalizationFont, size: 22) ?? UIFont.systemFont(ofSize: 22, weight: .bold)
        // ... (rest of your init remains the same) ...
        let titleColor = UIColor(Color.sl_textPrimary)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(Color.sl_glowColor.opacity(0.5))
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowBlurRadius = 2

        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: titleFont,
            .shadow: shadow
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont(name: nasalizationFont, size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold),
            .shadow: shadow
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.sl_textPrimary)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.sl_bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    if let initError = llmService.initErrorMessage, llmService.conversation.isEmpty {
                        errorWarningView(message: initError)
                    }

                    ScrollViewReader { scrollViewProxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(llmService.conversation) { message in
                                    MessageView(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            // Add a bottom padding to the content of the ScrollView
                            // to ensure the last message can scroll above the input area + keyboard
                            .padding(.bottom, keyboard.currentHeight > 0 ? 0 : singleLineMinHeight + 24) // Adjust as needed
                        }
                        .onChange(of: llmService.conversation) { oldValue, newValue in
                            if let lastMessage = newValue.last {
                                // Use the keyboard animation duration for scrolling if keyboard is involved
                                let animation = Animation.spring(response: keyboardAnimationDuration, dampingFraction: 0.8)
                                withAnimation(animation) {
                                    scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(llmService.isLoading && isResponseAreaGlowing ? Color.sl_glowColor.opacity(0.6) : Color.clear,
                                        lineWidth: llmService.isLoading && isResponseAreaGlowing ? 2 : 0)
                        )
                        .shadow(color: llmService.isLoading && isResponseAreaGlowing ? Color.sl_glowColor.opacity(0.4) : .clear,
                                radius: llmService.isLoading && isResponseAreaGlowing ? 8 : 0)
                        .onChange(of: llmService.isLoading) { oldValue, newValue in
                            // ... (glowing animation logic remains the same) ...
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
                    // The ScrollView itself should not ignore the keyboard safe area,
                    // as its content needs to scroll above it.

                    inputAreaView()
                        .padding(.horizontal)
                        .padding(.top, 8)
                        // This padding will be animated by the .animation modifier on the VStack
                        .padding(.bottom, keyboard.currentHeight > 0 ? 0 : 8) // Adjust bottom padding when keyboard is hidden
                }
                // This VStack is what moves with the keyboard
                .padding(.bottom, keyboard.currentHeight) // << --- KEY CHANGE
                .animation(Animation.customSpring(duration: keyboardAnimationDuration, bounce: 0.1), value: keyboard.currentHeight) // << --- KEY CHANGE for keyboard height
                .ignoresSafeArea(.keyboard, edges: .bottom) // << --- KEY CHANGE
            }
            .navigationTitle("Lumi Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        // The keyboard dismissal itself will trigger the animation via keyboard.currentHeight
                        isPromptFocused = false
                    }
                    .font(.custom(nasalizationFont, size: 16))
                    .foregroundColor(Color.sl_textPrimary)
                }
                // ... (rest of your toolbar) ...
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let anim = KeyboardResponder.keyboardAnimation(from: notification) {
                    self.keyboardAnimationDuration = anim.duration
                    self.keyboardAnimationCurve = anim.curve
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                if let anim = KeyboardResponder.keyboardAnimation(from: notification) {
                    self.keyboardAnimationDuration = anim.duration
                    self.keyboardAnimationCurve = anim.curve
                }
            }
            // .onAppear { isPromptFocused = false } // Your original onAppear
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func inputAreaView() -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                TextEditor(text: $promptText)
                    // ... (TextEditor setup remains mostly the same) ...
                    .font(.custom(nasalizationFont, size: 16))
                    .foregroundColor(Color.sl_textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: singleLineMinHeight, maxHeight: 120)
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    .padding(.vertical, 8) // Internal padding of TextEditor
                    .background(Color.sl_bgTertiary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isPromptFocused ? Color.sl_glowColor.opacity(0.8) : Color.sl_borderPrimary, lineWidth: isPromptFocused ? 1.5 : 1)
                    )
                    .shadow(color: isPromptFocused ? Color.sl_glowColor.opacity(0.6) : .clear, radius: isPromptFocused ? 6 : 0)
                    .focused($isPromptFocused)
                    .disabled(llmService.isLoading && !currentPromptCanBeStopped())
                    .onSubmit(submitPrompt)
                    // The .animation for promptText (TextEditor height change) should be fine here
                    .animation(.easeInOut(duration: 0.2), value: promptText)


                if promptText.isEmpty && !isPromptFocused {
                    Text("Hi Matt, what can I help you with?")
                        // ... (Placeholder setup remains the same) ...
                        .font(.custom(nasalizationFont, size: 16))
                        .foregroundColor(Color.sl_textPlaceholder)
                        .padding(.leading, 15)
                        .padding(.vertical, (singleLineMinHeight - (UIFont(name: nasalizationFont, size: 16)?.lineHeight ?? 16)) / 2 )
                        .allowsHitTesting(false)
                        // Animate the placeholder appearance/disappearance smoothly
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            // ... (Button setup remains the same) ...
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
        // NO .animation(.easeInOut(duration: 0.25), value: isPromptFocused) HERE ANYMORE
        // The parent VStack handles animation based on keyboard.currentHeight
    }

    private func errorWarningView(message: String) -> some View {
        // ... (remains the same) ...
        Text(message)
            .font(.custom(messageFontName, size: 14))
            .foregroundColor(Color.sl_errorText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.sl_errorBg.opacity(0.8))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.sl_errorText.opacity(0.5), lineWidth: 1))
            .padding(.horizontal)
            .padding(.top, 5)
    }

    private func submitOrStop() {
        if llmService.isLoading {
            if currentPromptCanBeStopped() {
                llmService.stopGeneration()
                // Keyboard will be dismissed if focused, triggering animation
                if isPromptFocused { isPromptFocused = false }
            }
        } else {
            submitPrompt()
        }
    }

    private func submitPrompt() {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        // Keyboard dismissal will trigger the main animation
        isPromptFocused = false

        // Clear text after a very short delay to allow keyboard animation to start
        // and prevent placeholder from flickering if text clears too fast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if !self.isPromptFocused { // ensure focus actually changed
                 self.promptText = ""
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + keyboardAnimationDuration + 0.05) { // Wait for keyboard to mostly hide
            self.llmService.generateResponseStreaming(prompt: trimmedPrompt)
        }
    }

    private func currentPromptCanBeStopped() -> Bool {
        return llmService.isLoading
    }
}

// Helper for custom spring animation to match keyboard feel
extension Animation {
    static func customSpring(duration: TimeInterval, bounce: CGFloat = 0.0) -> Animation {
        return .timingCurve(0.45, 1.05, 0.35, 1.0, duration: duration) // Example curve, find one that matches keyboard
        // A true spring that matches UIKit's keyboard is tricky.
        // .interpolatingSpring(mass: 1, stiffness: 100, damping: 15, initialVelocity: 0) might be another option to try.
        // Or simply: .spring(response: duration, dampingFraction: 0.85) // Adjust damping
    }
}
