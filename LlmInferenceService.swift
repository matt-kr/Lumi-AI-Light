import SwiftUI
import Combine

// NOTE: ChatMessage & Sender are NOT included here.

@MainActor
class LlmInferenceService: ObservableObject {
    // ... Properties ...
    private let worker: LlmWorker
    private let modelName: String
    @Published var conversation: [ChatMessage] = []
    @Published var isLoadingResponse = false
    @Published var initErrorMessage: String?
    @Published private(set) var isModelReady = false
    @Published private(set) var isLoadingModel = false
    private var currentStreamingTask: Task<Void, Never>?
    
    // ... init, initializeAndLoadModel, startNewChat ...
    init(modelName: String = "gemma-2b-it-gpu-int8") {
        self.modelName = modelName
        self.worker = LlmWorker()
        print("LlmInferenceService initialized. Call initializeAndLoadModel() to prepare worker.")
    }
    
    func initializeAndLoadModel() {
        guard !isModelReady, !isLoadingModel else { return }
        print("[Service] Starting initial model setup...")
        isLoadingModel = true
        
        Task(priority: .userInitiated) {
            defer { Task { @MainActor in self.isLoadingModel = false } }
            guard let foundPath = Bundle.main.path(forResource: modelName, ofType: "tflite") else {
                let errorMsg = "CRITICAL ERROR: Model file '\(modelName).tflite' not found."
                print(errorMsg); self.initErrorMessage = errorMsg; self.isModelReady = false; return
            }
            await worker.configure(modelPath: foundPath, maxTokens: 2048)
            self.isModelReady = true
            self.initErrorMessage = nil
            print("[Service] Initial model setup (configuration) successful.")
        }
    }
    
    func startNewChat() {
        stopGeneration()
        self.conversation.removeAll()
        self.isLoadingResponse = false
        print("[Service] New chat started.")
    }
    
    // MARK: - Generate response
        func generateResponseStreaming(prompt: String) {
            guard self.isModelReady else { appendError("Lumi not ready.", isCritical: true); return }
            guard self.currentStreamingTask == nil else { print("[Service] Already generating."); return }
            guard !self.isLoadingResponse else { print("[Service] Inconsistent state (isLoading)."); self.isLoadingResponse = false; return }
            
            appendUserMessage(prompt)
            self.isLoadingResponse = true
            let historyPrompt = buildHistoryPrompt(with: prompt)

            // --- ADD LOGGING HERE ---
            print("📜 [Service] History Prompt Length: \(historyPrompt.count) characters")
            // Optional: Log a snippet to see what's being sent, but be mindful of long outputs
            // print("📜 [Service] History Prompt (first 200): \(String(historyPrompt.prefix(200)))...")
            // --- END LOGGING ---
            
            self.currentStreamingTask = Task {
                // ... (rest of the Task remains the same) ...
                print("[Service Task] Requesting stream from worker...")
                defer {
                    Task { @MainActor in
                        print("[Service DEFER] Resetting isLoadingResponse & currentStreamingTask.")
                        self.isLoadingResponse = false
                        self.currentStreamingTask = nil
                    }
                }
                
                var responseReceived = false
                var accumulatedResponseText = ""
                var lastError: Error? = nil

                var lastUiUpdateTime: Date = .distantPast
                let uiUpdateInterval: TimeInterval = 0.03
                var firstChunkProcessedForUi = false
                
                do {
                    let responseStream = await worker.generateResponse(prompt: historyPrompt) // historyPrompt is used here
                    print("[Service Task] Successfully obtained responseStream. Awaiting chunks...")
                    
                    for try await chunk in responseStream {
                        try Task.checkCancellation()
                        // print("✅ [Service Loop] CHUNK RECEIVED: '\(chunk)'")
                        
                        responseReceived = true
                        accumulatedResponseText += chunk
                        // print("🔵 [Service Loop] ACCUMULATED: '\(accumulatedResponseText.prefix(80))...'")

                        let now = Date()
                        if !firstChunkProcessedForUi || now.timeIntervalSince(lastUiUpdateTime) >= uiUpdateInterval {
                            let textToDisplay = accumulatedResponseText
                            // print("✨ [Service Loop] Attempting UI Update with text (length: \(textToDisplay.count))")
                            self.appendOrUpdateLumiText(textToDisplay)
                            lastUiUpdateTime = now
                            firstChunkProcessedForUi = true
                        }
                    }
                    print("[Service Task] Finished iterating responseStream (Worker stream finished or was cancelled).")

                    if responseReceived {
                        let finalTextToDisplay = accumulatedResponseText
                        // print("🏁 [Service Task] Attempting FINAL UI Update with text (length: \(finalTextToDisplay.count))")
                        self.appendOrUpdateLumiText(finalTextToDisplay)
                    }
                    
                } catch is CancellationError {
                    print("[Service Task] Caught CancellationError in stream processing.")
                    lastError = CancellationError()
                } catch let workerError as LlmWorker.WorkerError {
                    print("[Service Task] Caught LlmWorker.WorkerError in stream processing: \(workerError)")
                    if case .cancelled = workerError {
                        lastError = CancellationError()
                    } else {
                        lastError = workerError
                    }
                } catch {
                    print("[Service Task] Caught an unexpected error in stream processing: \(error)")
                    lastError = error
                }
                
                print("[Service Task] Finalizing stream function.")
                self.finalizeStream(lastError, gotData: responseReceived, finalAccumulatedText: accumulatedResponseText)
            }
        }
    // MARK: - Stop generation
    func stopGeneration() {
        print("[Service STOP] Stop generation requested.")
        currentStreamingTask?.cancel() // This will trigger cancellation handling
        // We also explicitly tell the worker, just in case.
        Task {
            await worker.cancelGeneration()
        }
    }
    
    // ... (Keep helper methods) ...
    private func buildHistoryPrompt(with userPrompt: String) -> String {
        let maxTurns = 10 // Max number of recent turns to consider initially
        // NEW: Maximum characters for the history part of the prompt
        let maxHistoryCharacters = 4200 // Tune this value as needed

        // 1. Get messages based on turn limit (no more +20)
        let messagesForTurnLimit = min(conversation.count, maxTurns * 2)
        // Suffix gives us the most recent messages
        let initialHistorySlice = conversation.suffix(messagesForTurnLimit)

        var actualHistoryMessages: [ChatMessage] = []
        var currentCharacterCount = 0

        // 2. Iterate from newest messages in the slice backward, adding them if they fit the character limit
        for message in initialHistorySlice.reversed() { // Newest to oldest
            let _: String
            var senderPrefix = ""
            var senderSuffix = ""

            switch message.sender {
            case .user:
                senderPrefix = "<start_of_turn>user\n"
                senderSuffix = "<end_of_turn>\n"
            case .lumi:
                senderPrefix = "<start_of_turn>model\n"
                senderSuffix = "<end_of_turn>\n"
            default:
                continue // Skip unknown sender types
            }
            
            // Calculate length of the fully formatted message part
            let messagePartLength = senderPrefix.count + message.text.count + senderSuffix.count

            if currentCharacterCount + messagePartLength <= maxHistoryCharacters {
                actualHistoryMessages.insert(message, at: 0) // Insert at beginning to maintain chronological order
                currentCharacterCount += messagePartLength
            } else {
                // Adding this message would exceed the character limit, so stop.
                // Since we are iterating from newest to oldest, we've included the newest ones possible.
                break
            }
        }

        // 3. Build the history string from the messages that fit
        let history = actualHistoryMessages.map { msg -> String in
            switch msg.sender {
            case .user: return "<start_of_turn>user\n\(msg.text)<end_of_turn>\n"
            case .lumi: return "<start_of_turn>model\n\(msg.text)<end_of_turn>\n"
            default:   return "" // Should not happen if filtered above
            }
        }.joined()
        
        
        // 4. Construct your system prompt
        let (userName, userAbout, personalityType, customPersonality) = UserData.shared.loadData()
        var sysPromptText = ""
        switch personalityType {
        case "Lumi":
            sysPromptText = "You are Lumi, a friendly and concise human like assistant."
            
        case "Executive Coach":
            sysPromptText = "You are a calm, professional assistant with the tone of an executive coach. You speak with clarity, avoid repetition, and focus on providing insight over small talk. Your responses are direct, thoughtful, and geared toward helping the user think critically."

        case "Helpful & Enthusiastic":
            sysPromptText = "You are Lumi, an incredibly helpful and enthusiastic assistant! You love using exclamation points and encouraging words, always maintaining a positive and supportive tone."
            
        case "Witty & Sarcastic":
            sysPromptText = "You are Lumi. You're helpful, but with a dry, witty, and slightly sarcastic sense of humor. Don't be afraid to be a little cheeky, but remain ultimately helpful and don't be rude."
            
        case "Custom":
            sysPromptText = customPersonality.isEmpty
                ? "You are Lumi, a friendly and concise human like assistant." // Fallback for empty custom
                : customPersonality
        default:
            sysPromptText = "You are Lumi, a friendly and concise human like assistant."
        }

        if !userName.isEmpty { sysPromptText += " Your primary user is \(userName)." }
        if !userAbout.isEmpty { sysPromptText += " Here's a bit about them: \(userAbout)." }
        sysPromptText += " If you don't know an answer do not make one up. Do not repeat back a query when answering. Pay close attention to the conversation history."

        // MARK: - DATE/TIME & INSTRUCTIONS HERE ---
        let now = Date()
                let formattedDateTime = now.formatted(date: .long, time: .shortened)
                // Use a more "data-like" prefix and a stronger instruction:
                sysPromptText += " [System Clock: \(formattedDateTime)]"
                // MARK: --- END ADD ---
        
        // 5. Assemble the final prompt
        let finalPrompt = "\(sysPromptText)\n\(history)<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
        
        // Optional: Log final lengths for tuning
        // print("📜 History Prompt: \(history.count) chars, System: \(sysPromptText.count) chars, User: \(userPrompt.count) chars, Total: \(finalPrompt.count) chars")

        return finalPrompt
    }
    
    private func appendUserMessage(_ text: String) {
        conversation.append(ChatMessage(sender: .user, text: text))
        conversation.append(ChatMessage(sender: .lumi, text: ""))
    }
    
    private func appendError(_ text: String, isCritical: Bool) {
        if conversation.last?.text != text || conversation.last?.sender != .error(isCritical: isCritical) {
            conversation.append(ChatMessage(sender: .error(isCritical: isCritical), text: text))
        }
    }
    
    private func appendOrUpdateLumiText(_ newFullAccumulatedText: String) {
        if let idx = conversation.lastIndex(where: { $0.sender == .lumi }) {
            conversation[idx].text = newFullAccumulatedText
        }
    }
    
    // FIXED: finalizeStream check
    private func finalizeStream(_ error: Error?, gotData: Bool, finalAccumulatedText: String) {
        guard let idx = conversation.lastIndex(where: { $0.sender == .lumi }) else {
            if let err = error, !(err is CancellationError) { appendError("Lumi error (context lost): \(err.localizedDescription)", isCritical: false) }
            return
        }
        let lumiMessage = conversation[idx]
        
        var displayError: Error? = error
        if let workerError = error as? LlmWorker.WorkerError {
            // If it is, *then* check if it's the .engineError case
            if case .engineError(let underlyingError) = workerError {
                displayError = underlyingError
            }
            
            if let err = displayError {
                var isCancel = false
                if err is CancellationError { isCancel = true }
                if let workerErr = err as? LlmWorker.WorkerError, case .cancelled = workerErr { isCancel = true }
                
                if isCancel {
                    print("[Service Finalize] Handling Cancellation.")
                    if lumiMessage.text.isEmpty { conversation.remove(at: idx) }
                    else if !lumiMessage.text.contains("(Stopped") { conversation[idx].text += "\n(Stopped by user)"; conversation[idx].sender = .info }
                } else {
                    print("[Service Finalize] Handling Error: \(err.localizedDescription)")
                    let errorText = "\n\nError: \(err.localizedDescription)"
                    conversation[idx].text = (lumiMessage.text.isEmpty ? "" : lumiMessage.text) + errorText
                    conversation[idx].sender = .error()
                }
            } else if !gotData && lumiMessage.text.isEmpty {
                conversation[idx].text = "(Lumi provided no response)"; conversation[idx].sender = .info
            } else if gotData && error == nil {
                conversation[idx].text = finalAccumulatedText
            }
        }
    }
}
