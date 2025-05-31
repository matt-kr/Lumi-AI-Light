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

    @Published var activeSwiftDataSession: ConversationSession?
    @Published var isForceResettingChatState: Bool = false // KEEP THIS - It's a functional fix

    init(modelName: String = "gemma-2b-it-gpu-int8") {
        self.modelName = modelName
        self.worker = LlmWorker()
    }

    func initializeAndLoadModel() {
        guard !isModelReady, !isLoadingModel else { return }
        isLoadingModel = true
        
        Task(priority: .userInitiated) {
            defer { Task { @MainActor in self.isLoadingModel = false } }
            guard let foundPath = Bundle.main.path(forResource: modelName, ofType: "tflite") else {
                let errorMsg = "CRITICAL ERROR: Model file '\(modelName).tflite' not found."
                Task { @MainActor in self.initErrorMessage = errorMsg; self.isModelReady = false; } ; return
            }
            await worker.configure(modelPath: foundPath, maxTokens: 2048)
            Task { @MainActor in
                self.isModelReady = true
                self.initErrorMessage = nil
            }
        }
    }

    func startNewChat(context: ModelContext) {
        self.isForceResettingChatState = true
        
        stopGeneration()

        if let _ = self.activeSwiftDataSession {
            // Optional: log if an active session is being closed
        }
        
        self.activeSwiftDataSession = nil
        self.conversation.removeAll()
        self.isLoadingResponse = false
        
        DispatchQueue.main.async {
            self.isForceResettingChatState = false
        }
    }

    @MainActor
    func loadConversation(sessionToLoad: ConversationSession) {
        self.isForceResettingChatState = true

        stopGeneration()
        
        self.conversation.removeAll()

        let messageModels = sessionToLoad.messages
        self.conversation = messageModels.compactMap { model -> ChatMessage? in
            return ChatMessage(id: model.id, sender: model.sender, text: model.text, timestamp: model.timestamp)
        }
        
        self.activeSwiftDataSession = sessionToLoad
        self.isLoadingResponse = false
        self.initErrorMessage = nil

        DispatchQueue.main.async {
            self.isForceResettingChatState = false
        }
    }

    func generateResponseStreaming(prompt: String, context: ModelContext) {
        guard self.isModelReady else {
            appendError("Lumi not ready.", isCritical: true, context: context)
            return
        }
        guard self.currentStreamingTask == nil else { return }
        
        appendUserMessage(prompt, context: context)
        self.isLoadingResponse = true
        
        let historyPrompt = buildHistoryPrompt(with: prompt)
        
        self.currentStreamingTask = Task {
            var responseReceived = false; var accumulatedResponseText = ""; var lastError: Error? = nil
            var lastUiUpdateTime: Date = .distantPast; let uiUpdateInterval: TimeInterval = 0.03; var firstChunkProcessedForUi = false
            
            let taskWasCancelledWhenStarted = Task.isCancelled
            if taskWasCancelledWhenStarted {
                lastError = CancellationError()
            } else {
                do {
                    let responseStream = await worker.generateResponse(prompt: historyPrompt)
                    for try await chunk in responseStream {
                        if Task.isCancelled { throw CancellationError() }
                        responseReceived = true; accumulatedResponseText += chunk
                        let now = Date()
                        if !firstChunkProcessedForUi || now.timeIntervalSince(lastUiUpdateTime) >= uiUpdateInterval {
                            if Task.isCancelled { throw CancellationError() }
                            Task { @MainActor in self.appendOrUpdateLumiText(accumulatedResponseText, isPartial: true) }
                            lastUiUpdateTime = now; firstChunkProcessedForUi = true
                        }
                    }
                    if responseReceived && !Task.isCancelled {
                        Task { @MainActor in self.appendOrUpdateLumiText(accumulatedResponseText, isPartial: false) }
                    }
                } catch is CancellationError {
                    lastError = CancellationError()
                } catch let workerError as LlmWorker.WorkerError {
                    lastError = workerError
                } catch {
                    lastError = error
                }
            }
            
            Task { @MainActor in
                 self.finalizeStream(lastError, gotData: responseReceived, finalAccumulatedText: accumulatedResponseText, context: context)
                 self.isLoadingResponse = false
                 self.currentStreamingTask = nil
            }
        }
    }

    func stopGeneration() {
        currentStreamingTask?.cancel()
        Task { await worker.cancelGeneration() }
        if isLoadingResponse {
            self.isLoadingResponse = false
        }
    }

    public func handleSessionDeletion(deletedSessionID: UUID, newChatContext: ModelContext) {
        if activeSwiftDataSession?.id == deletedSessionID {
            self.startNewChat(context: newChatContext)
        }
    }

    private func buildHistoryPrompt(with userPrompt: String) -> String {
        let maxTurns = 10; let maxHistoryCharacters = 4200
        let currentConversation = self.conversation
        let initialHistorySlice = currentConversation.suffix(min(currentConversation.count, maxTurns * 2)); var actualHistoryMessages: [ChatMessage] = []; var currentCharacterCount = 0
        for message in initialHistorySlice.reversed() {
            let senderPrefix: String; let senderSuffix: String
            switch message.sender {
            case .user: senderPrefix = "<start_of_turn>user\n"; senderSuffix = "<end_of_turn>\n";
            case .lumi: senderPrefix = "<start_of_turn>model\n"; senderSuffix = "<end_of_turn>\n";
            default: continue
            }
            let messagePartLength = senderPrefix.count + message.text.count + senderSuffix.count
            if currentCharacterCount + messagePartLength <= maxHistoryCharacters { actualHistoryMessages.insert(message, at: 0); currentCharacterCount += messagePartLength } else { break }
        }
        let history = actualHistoryMessages.map { msg -> String in
            switch msg.sender {
            case .user: return "<start_of_turn>user\n\(msg.text)<end_of_turn>\n"
            case .lumi: return "<start_of_turn>model\n\(msg.text)<end_of_turn>\n"
            default: return ""
            }
        }.joined()
        
        let (userName, userAbout, personalityType, customPersonality) = UserData.shared.loadData()
        var sysPromptText = "";
        switch personalityType {
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
    
    @MainActor
    private func addMessageToActiveSession(_ message: ChatMessage, context: ModelContext) {
        guard let activeSession = self.activeSwiftDataSession else { return }
        if let existingModel = activeSession.messages.first(where: { $0.id == message.id }) {
            existingModel.text = message.text;
        } else {
            let newModel = ChatMessageModel(from: message);
            newModel.conversation = activeSession
            activeSession.messages.append(newModel)
        }
        activeSession.lastModifiedTime = Date()
    }

    @MainActor
    private func appendUserMessage(_ text: String, context: ModelContext) {
        let userMessage = ChatMessage(sender: .user, text: text)
        self.conversation.append(userMessage)
        self.conversation.append(ChatMessage(sender: .lumi, text: ""))
        
        if activeSwiftDataSession != nil {
            addMessageToActiveSession(userMessage, context: context)
        }
    }

    @MainActor
    private func appendOrUpdateLumiText(_ text: String, isPartial: Bool) {
        let lumiSenderPredicate: (ChatMessage) -> Bool = { $0.sender == .lumi }
        if isPartial {
            if let idx = conversation.lastIndex(where: lumiSenderPredicate) {
                conversation[idx].text = text
            } else {
                conversation.append(ChatMessage(sender: .lumi, text: text))
            }
        } else {
            if let idx = conversation.lastIndex(where: lumiSenderPredicate) {
                let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if finalText.isEmpty {
                    conversation[idx].text = "(Lumi provided no response)"
                    conversation[idx].sender = .info
                } else {
                    conversation[idx].text = finalText
                }
            } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if conversation.last?.sender == .error() || conversation.last?.sender == .info { conversation.removeLast() }
                conversation.append(ChatMessage(sender: .lumi, text: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else {
                conversation.append(ChatMessage(sender: .info, text: "(Lumi provided no response)"))
            }
        }
    }
    
    @MainActor
    private func appendError(_ text: String, isCritical: Bool, context: ModelContext) {
        if conversation.last?.sender == .lumi && conversation.last?.text.isEmpty == true {
            conversation.removeLast()
        }
        let errorMessage = ChatMessage(sender: .error(isCritical: isCritical), text: text)
        conversation.append(errorMessage)
        
        if activeSwiftDataSession != nil {
            addMessageToActiveSession(errorMessage, context: context)
        }
    }

    @MainActor
    private func finalizeStream(_ error: Error?, gotData: Bool, finalAccumulatedText: String, context: ModelContext) {
        guard !isForceResettingChatState else {
            if self.isLoadingResponse { self.isLoadingResponse = false }
            return
        }

        var finalMessageForSwiftData: ChatMessage?

        if let err = error {
            let errorText = "Error: \(err.localizedDescription)"
            if err is CancellationError {
                 // If the last message was an empty Lumi placeholder, update it or remove
                if let lastIdx = conversation.lastIndex(where: {$0.sender == .lumi && $0.text.isEmpty}) {
                    // conversation[lastIdx].text = "(Generation stopped)"
                    // conversation[lastIdx].sender = .info
                    // finalMessageForSwiftData = conversation[lastIdx]
                    // Or simply remove it if you don't want to save "stopped" messages
                     conversation.remove(at: lastIdx)
                }
            } else {
                if let lastIdx = conversation.lastIndex(where: {$0.sender == .lumi && ($0.text.isEmpty || $0.text != finalAccumulatedText )}) {
                    conversation[lastIdx].text = errorText; conversation[lastIdx].sender = .error(isCritical: true); finalMessageForSwiftData = conversation[lastIdx]
                } else if (conversation.last?.sender != .error(isCritical: false) && conversation.last?.sender != .error(isCritical: true)) || conversation.last?.text != errorText {
                    let msg = ChatMessage(sender: .error(isCritical: true), text: errorText);
                    if conversation.last?.sender == .lumi && conversation.last?.text.isEmpty == true { conversation[conversation.count - 1] = msg }
                    else { conversation.append(msg) };
                    finalMessageForSwiftData = conversation.last
                } else { finalMessageForSwiftData = conversation.last }
            }
        } else if !gotData {
            if let lastIdx = conversation.lastIndex(where: {$0.sender == .lumi && $0.text.isEmpty}) {
                conversation[lastIdx].text = "(Lumi provided no response)"; conversation[lastIdx].sender = .info; finalMessageForSwiftData = conversation[lastIdx]
            }
        } else {
            finalMessageForSwiftData = conversation.last(where: {$0.sender == .lumi || ($0.sender == .info && $0.text == "(Lumi provided no response)")})
            if finalMessageForSwiftData == nil && conversation.last?.sender == .lumi { finalMessageForSwiftData = conversation.last }
        }

        let shouldCreateNewSession = self.activeSwiftDataSession == nil &&
                                     error == nil &&
                                     gotData &&
                                     self.conversation.contains(where: { $0.sender == .user })

        if shouldCreateNewSession {
            let newSession = ConversationSession(startTime: Date(), lastModifiedTime: Date(), isPinned: false, customTitle: nil)
            context.insert(newSession)
            self.activeSwiftDataSession = newSession
            let messagesToAdd = self.conversation
            for msgInMemory in messagesToAdd {
                addMessageToActiveSession(msgInMemory, context: context)
            }
        } else if let session = self.activeSwiftDataSession, let messageToSave = finalMessageForSwiftData {
            addMessageToActiveSession(messageToSave, context: context)
        }
        
        if self.isLoadingResponse { // Should be set by the calling Task block in generateResponseStreaming
            self.isLoadingResponse = false
        }
    }
}
