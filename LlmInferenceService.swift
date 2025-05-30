import SwiftUI
import Combine
import SwiftData

@MainActor
class LlmInferenceService: ObservableObject {
    // MARK: - Properties
    private let worker: LlmWorker
    private let modelName: String
    @Published var conversation: [ChatMessage] = []
    @Published var isLoadingResponse = false
    @Published var initErrorMessage: String?
    @Published private(set) var isModelReady = false
    @Published private(set) var isLoadingModel = false
    private var currentStreamingTask: Task<Void, Never>?

    // MODIFIED: Made this @Published and not private so SideMenuView can observe it
    @Published var activeSwiftDataSession: ConversationSession?

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

    func startNewChat(context: ModelContext) {
        stopGeneration()
        if let activeSession = self.activeSwiftDataSession {
            print("ℹ️ Closing active SwiftData session: \(activeSession.id). It should be saved turn-by-turn.")
        }
        // This correctly sets the active session to nil for a new chat
        self.activeSwiftDataSession = nil
        self.conversation.removeAll()
        self.isLoadingResponse = false
        print("[Service] New chat started. In-memory conversation cleared.")
    }

    @MainActor
    func loadConversation(sessionToLoad: ConversationSession) {
        print("🔄 Loading conversation: \(sessionToLoad.id) - \(sessionToLoad.title)")
        stopGeneration()
        self.conversation.removeAll()

        let messageModels = sessionToLoad.messages
        self.conversation = messageModels.compactMap { model -> ChatMessage? in
            return ChatMessage(id: model.id, sender: model.sender, text: model.text, timestamp: model.timestamp)
        }
        
        if messageModels.isEmpty { print("ℹ️ Loaded session has no messages.") }
        else { print("✅ Loaded \(self.conversation.count) messages.") }

        // This correctly updates the active session
        self.activeSwiftDataSession = sessionToLoad
        self.isLoadingResponse = false
        self.initErrorMessage = nil
    }

    func generateResponseStreaming(prompt: String, context: ModelContext) {
        guard self.isModelReady else { appendError("Lumi not ready.", isCritical: true, context: context); return }
        guard self.currentStreamingTask == nil else { print("[Service] Already generating."); return }
        guard !self.isLoadingResponse else { print("[Service] Inconsistent state (isLoading)."); self.isLoadingResponse = false; return }
        
        appendUserMessage(prompt, context: context)
        self.isLoadingResponse = true
        let historyPrompt = buildHistoryPrompt(with: prompt)
        print("📜 [Service] History Prompt Length: \(historyPrompt.count) characters")
        
        self.currentStreamingTask = Task {
            var responseReceived = false; var accumulatedResponseText = ""; var lastError: Error? = nil
            var lastUiUpdateTime: Date = .distantPast; let uiUpdateInterval: TimeInterval = 0.03; var firstChunkProcessedForUi = false
            defer { Task { @MainActor in self.isLoadingResponse = false; self.currentStreamingTask = nil } }
            
            do {
                let responseStream = await worker.generateResponse(prompt: historyPrompt)
                for try await chunk in responseStream {
                    try Task.checkCancellation()
                    responseReceived = true; accumulatedResponseText += chunk
                    let now = Date()
                    if !firstChunkProcessedForUi || now.timeIntervalSince(lastUiUpdateTime) >= uiUpdateInterval {
                        self.appendOrUpdateLumiText(accumulatedResponseText, isPartial: true)
                        lastUiUpdateTime = now; firstChunkProcessedForUi = true
                    }
                }
                if responseReceived { self.appendOrUpdateLumiText(accumulatedResponseText, isPartial: false) }
            } catch is CancellationError { lastError = CancellationError(); print("[Service Task] Streaming cancelled.")
            } catch let workerError as LlmWorker.WorkerError { lastError = workerError; print("[Service Task] LlmWorker.Error: \(workerError)")
            } catch { lastError = error; print("[Service Task] Streaming error: \(error)") }
            
            self.finalizeStream(lastError, gotData: responseReceived, finalAccumulatedText: accumulatedResponseText, context: context)
        }
    }

    func stopGeneration() {
        print("[Service STOP] Stop generation requested."); currentStreamingTask?.cancel()
        Task { await worker.cancelGeneration() }
    }

    // buildHistoryPrompt, addMessageToActiveSession, appendUserMessage,
    // appendOrUpdateLumiText, appendError, and finalizeStream remain unchanged
    // as their logic for setting activeSwiftDataSession (in finalizeStream) is already correct.

    private func buildHistoryPrompt(with userPrompt: String) -> String {
        let maxTurns = 10; let maxHistoryCharacters = 4200
        let initialHistorySlice = conversation.suffix(min(conversation.count, maxTurns * 2)); var actualHistoryMessages: [ChatMessage] = []; var currentCharacterCount = 0
        for message in initialHistorySlice.reversed() {
            let senderPrefix: String; let senderSuffix: String
            switch message.sender { case .user: senderPrefix = "<start_of_turn>user\n"; senderSuffix = "<end_of_turn>\n"; default: continue }
            let messagePartLength = senderPrefix.count + message.text.count + senderSuffix.count
            if currentCharacterCount + messagePartLength <= maxHistoryCharacters { actualHistoryMessages.insert(message, at: 0); currentCharacterCount += messagePartLength } else { break }
        }
        let history = actualHistoryMessages.map { msg -> String in switch msg.sender { case .user: return "<start_of_turn>user\n\(msg.text)<end_of_turn>\n"; case .lumi: return "<start_of_turn>model\n\(msg.text)<end_of_turn>\n"; default: return "" } }.joined()
        let (userName, userAbout, personalityType, customPersonality) = UserData.shared.loadData()
        var sysPromptText = ""; switch personalityType {
            case "Lumi": sysPromptText = "You are Lumi, a friendly and concise human like assistant."
            case "Executive Coach": sysPromptText = "You are a calm, professional assistant..."
            case "Helpful & Enthusiastic": sysPromptText = "You are Lumi, an incredibly helpful and enthusiastic assistant!..."
            case "Witty & Sarcastic": sysPromptText = "You are Lumi. You're helpful, but with a dry, witty, and slightly sarcastic sense of humor..."
            case "Custom": sysPromptText = customPersonality.isEmpty ? "You are Lumi, a friendly and concise human like assistant." : customPersonality
            default: sysPromptText = "You are Lumi, a friendly and concise human like assistant."
        }
        if !userName.isEmpty { sysPromptText += " Your primary user is \(userName)." }
        if !userAbout.isEmpty { sysPromptText += " Here's a bit about them: \(userAbout)." }
        sysPromptText += " If you don't know an answer do not make one up. Do not repeat back a query when answering. Pay close attention to the conversation history."
        let now = Date(); let formattedDateTime = now.formatted(date: .long, time: .shortened); sysPromptText += " [System Clock: \(formattedDateTime)]"
        return "\(sysPromptText)\n\(history)<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
    }
    
    private func addMessageToActiveSession(_ message: ChatMessage, context: ModelContext) {
        guard let activeSession = self.activeSwiftDataSession else { return }
        if let existingModel = activeSession.messages.first(where: { $0.id == message.id }) {
            existingModel.text = message.text; existingModel.sender = message.sender
        } else {
            let newModel = ChatMessageModel(from: message); newModel.conversation = activeSession
            activeSession.messages.append(newModel)
        }
        activeSession.lastModifiedTime = Date()
        
        do { try context.save() } catch { print("❌ Error saving context: \(error)") }
    }

    private func appendUserMessage(_ text: String, context: ModelContext) {
        let userMessage = ChatMessage(sender: .user, text: text)
        self.conversation.append(userMessage)
        self.conversation.append(ChatMessage(sender: .lumi, text: "")) // Placeholder
        if activeSwiftDataSession != nil { addMessageToActiveSession(userMessage, context: context) }
    }

    private func appendOrUpdateLumiText(_ text: String, isPartial: Bool) {
        let lumiSenderPredicate: (ChatMessage) -> Bool = { $0.sender == .lumi }
        if isPartial { if let idx = conversation.lastIndex(where: lumiSenderPredicate) { conversation[idx].text = text } else { conversation.append(ChatMessage(sender: .lumi, text: text)) }
        } else {
            if let idx = conversation.lastIndex(where: lumiSenderPredicate) {
                conversation[idx].text = text.isEmpty ? "(Lumi provided no response)" : text
                if text.isEmpty && conversation[idx].sender == .lumi { conversation[idx].sender = .info }
            } else if !text.isEmpty {
                if conversation.last?.sender == .error() || conversation.last?.sender == .info { conversation.removeLast() }
                conversation.append(ChatMessage(sender: .lumi, text: text))
            } else if text.isEmpty && conversation.last?.sender != .info && conversation.last?.sender != .error() {
                conversation.append(ChatMessage(sender: .info, text: "(Lumi provided no response)"))
            }
        }
    }
    
    private func appendError(_ text: String, isCritical: Bool, context: ModelContext) {
        if conversation.last?.sender == .lumi && conversation.last?.text.isEmpty == true { conversation.removeLast() }
        let errorMessage = ChatMessage(sender: .error(isCritical: isCritical), text: text)
        conversation.append(errorMessage)
        if activeSwiftDataSession != nil { addMessageToActiveSession(errorMessage, context: context) }
    }

    private func finalizeStream(_ error: Error?, gotData: Bool, finalAccumulatedText: String, context: ModelContext) {
        var finalMessageForSwiftData: ChatMessage?
        if let err = error {
            let errorText = "Error: \(err.localizedDescription)"; if let lastIdx = conversation.lastIndex(where: {$0.sender == .lumi && ($0.text.isEmpty || $0.text != finalAccumulatedText )}) { conversation[lastIdx].text = errorText; conversation[lastIdx].sender = .error(isCritical: !(err is CancellationError)); finalMessageForSwiftData = conversation[lastIdx] } else if (conversation.last?.sender != .error(isCritical: false) && conversation.last?.sender != .error(isCritical: true)) || conversation.last?.text != errorText { let msg = ChatMessage(sender: .error(isCritical: !(err is CancellationError)), text: errorText); if conversation.last?.sender == .lumi && conversation.last?.text.isEmpty == true { conversation[conversation.count - 1] = msg } else { conversation.append(msg) }; finalMessageForSwiftData = conversation.last } else { finalMessageForSwiftData = conversation.last }
        } else if !gotData && (conversation.last?.sender == .lumi && conversation.last?.text.isEmpty == true) { let idx = conversation.count-1; conversation[idx].text = "(Lumi provided no response)"; conversation[idx].sender = .info; finalMessageForSwiftData = conversation[idx]
        } else if gotData { finalMessageForSwiftData = conversation.last(where: {$0.sender == .lumi || ($0.sender == .info && $0.text == "(Lumi provided no response)")}); if finalMessageForSwiftData == nil && conversation.last?.sender == .lumi { finalMessageForSwiftData = conversation.last } }

        guard let finalMessageToPersist = finalMessageForSwiftData else { return }

        // This correctly updates activeSwiftDataSession when a new session is created
        if self.activeSwiftDataSession == nil && error == nil && gotData && self.conversation.filter({ $0.sender == .user }).count > 0 {
            let newSession = ConversationSession(); context.insert(newSession); self.activeSwiftDataSession = newSession
            for msgInMemory in self.conversation { addMessageToActiveSession(msgInMemory, context: context) } // This should now use the newly set activeSwiftDataSession
        } else if self.activeSwiftDataSession != nil { // If a session was already active, just add the final message
            addMessageToActiveSession(finalMessageToPersist, context: context)
        }
    }
}

// Assuming ChatMessage and ChatMessageModel are defined elsewhere and compatible.
// Also assuming LlmWorker, UserData, and SenderType (with its .user, .lumi, .info, .error cases) are defined.
