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
        
        self.currentStreamingTask = Task {
            print("[Service Task] Requesting stream from worker...")
            defer {
                Task { @MainActor in
                    print("[Service DEFER] Resetting isLoadingResponse & currentStreamingTask.")
                    self.isLoadingResponse = false
                    self.currentStreamingTask = nil
                }
            }
            
            var responseReceived = false; var accumulatedResponseText = ""; var lastError: Error? = nil
            
            do {
                let responseStream = await worker.generateResponse(prompt: historyPrompt)
                print("[Service Task] Awaiting chunks from worker stream...")
                for try await chunk in responseStream {
                    try Task.checkCancellation()
                    responseReceived = true
                    accumulatedResponseText += chunk
                    self.appendOrUpdateLumiText(accumulatedResponseText)
                }
                print("[Service Task] Worker stream finished (or was cancelled).")
                
                // --- FIXED: More specific catch block ---
            } catch is CancellationError {
                print("[Service Task] Caught CancellationError.")
                lastError = CancellationError()
            } catch let workerError as LlmWorker.WorkerError {
                print("[Service Task] Caught LlmWorker.WorkerError: \(workerError)")
                if case .cancelled = workerError {
                    lastError = CancellationError() // Treat as cancellation
                } else {
                    lastError = workerError // Keep other worker errors
                }
            } catch {
                print("[Service Task] Caught an unexpected error: \(error)")
                lastError = error
            }
            // --- END FIXED CATCH ---
            
            print("[Service Task] Finalizing stream.")
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
        let maxTurns = 10
        let messagesToConsider = min(conversation.count, maxTurns * 2 + 20)
        let startIdx = max(0, conversation.count - messagesToConsider)
        let historySlice = conversation[startIdx...]
        let history = historySlice.map { msg -> String in
            switch msg.sender {
            case .user: return "<start_of_turn>user\n\(msg.text)<end_of_turn>\n"
            case .lumi: return "<start_of_turn>model\n\(msg.text)<end_of_turn>\n"
            default:    return ""
            }
        }.joined()
        let sys = "You are Lumi, a friendly and concise human like assistant. Your primary user is Matt. If you don't know an answer do not make one up. Do not repeat back a query when answering. Pay close attention to the conversation history."
        return "\(sys)\n\(history)<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
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
