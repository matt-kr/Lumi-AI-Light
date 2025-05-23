import SwiftUI
import Combine

// NOTE: ChatMessage & Sender are NOT included here.

@MainActor
class LlmInferenceService: ObservableObject {
    // MARK: - Stored Properties
    private let worker: LlmWorker // Holds the reference to our background actor
    private let modelName: String

    @Published var conversation: [ChatMessage] = []
    @Published var isLoadingResponse = false
    @Published var initErrorMessage: String?

    @Published private(set) var isModelReady = false
    @Published private(set) var isLoadingModel = false

    private var currentStreamingTask: Task<Void, Never>?

    // MARK: - Init
    init(modelName: String = "gemma-2b-it-gpu-int8") {
        self.modelName = modelName
        self.worker = LlmWorker() // Create the actor instance
        print("LlmInferenceService initialized. Call initializeAndLoadModel() to prepare worker.")
    }

    // MARK: - Model Setup (Now configures the Worker)
    func initializeAndLoadModel() {
        guard !isModelReady, !isLoadingModel else { return }
        print("[Service] Starting initial model setup...")
        isLoadingModel = true
        
        Task {
            defer { Task { @MainActor in self.isLoadingModel = false } }
            
            guard let foundPath = Bundle.main.path(forResource: modelName, ofType: "tflite") else {
                let errorMsg = "CRITICAL ERROR: Model file '\(modelName).tflite' not found."
                print(errorMsg); self.initErrorMessage = errorMsg; self.isModelReady = false; return
            }
            
            // Tell the worker about the model path.
            // We assume configuration itself is fast. The *loading* happens later.
            await worker.configure(modelPath: foundPath, maxTokens: 2048)
            
            // For now, we'll assume "ready" means configured.
            // A more robust way might have the worker signal back after first load.
            self.isModelReady = true
            self.initErrorMessage = nil
            print("[Service] Initial model setup (configuration) successful.")
        }
    }

    // MARK: - New chat
    func startNewChat() {
        stopGeneration()
        self.conversation.removeAll()
        self.isLoadingResponse = false
        print("[Service] New chat started.")
    }

    // MARK: - Generate response (Delegates to Worker)
    func generateResponseStreaming(prompt: String) {
        guard self.isModelReady else { appendError("Lumi not ready.", isCritical: true); return }
        guard self.currentStreamingTask == nil else { print("[Service] Already generating."); return }
        guard !self.isLoadingResponse else { print("[Service] Inconsistent state (isLoading)."); self.isLoadingResponse = false; return }

        // --- IMMEDIATE UI UPDATES ---
        appendUserMessage(prompt)
        self.isLoadingResponse = true
        // --- END IMMEDIATE UI UPDATES ---

        let historyPrompt = buildHistoryPrompt(with: prompt)

        // Create the task that will *listen* to the worker.
        self.currentStreamingTask = Task {
            print("[Service Task] Requesting stream from worker...")
            
            // This defer runs when THIS task finishes (success, error, or cancel)
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

            do {
                // Get the stream *from* the worker. This is fast.
                let responseStream = await worker.generateResponse(prompt: historyPrompt)
                
                print("[Service Task] Awaiting chunks from worker stream...")
                // Iterate over the stream. This *suspends* until chunks arrive.
                for try await chunk in responseStream {
                    // Check for cancellation *between* chunks.
                    if Task.isCancelled {
                         print("[Service Task] Task was cancelled by stopGeneration().")
                         lastError = CancellationError()
                         break // Exit the loop
                    }
                    responseReceived = true
                    accumulatedResponseText += chunk
                    // Since we are @MainActor, this is safe.
                    self.appendOrUpdateLumiText(accumulatedResponseText)
                }
                print("[Service Task] Worker stream finished (or was cancelled).")

            } catch {
                print("[Service Task] Caught error from worker stream: \(error)")
                lastError = error
            }
            
            // Finalize on MainActor (we are already here, but good practice)
            print("[Service Task] Finalizing stream.")
            self.finalizeStream(lastError, gotData: responseReceived, finalAccumulatedText: accumulatedResponseText)
        }
    }

    // MARK: - Stop generation
    func stopGeneration() {
        print("[Service STOP] Stop generation requested.")
        currentStreamingTask?.cancel() // Cancel our *listening* task.
        // This cancellation should propagate to the stream continuation
        // allowing the worker's task to potentially stop early too.
    }

    // MARK: - Helper Methods (Same as before)
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

    private func finalizeStream(_ error: Error?, gotData: Bool, finalAccumulatedText: String) {
        guard let idx = conversation.lastIndex(where: { $0.sender == .lumi }) else {
            if let err = error, !(err is CancellationError) { appendError("Lumi error (context lost): \(err.localizedDescription)", isCritical: false) }
            return
        }
        let lumiMessage = conversation[idx]
        if let err = error {
             // Handle our own WorkerError or MediaPipe's via WorkerError.engineError
            let displayError: Error
            if case LlmWorker.WorkerError.engineError(let underlyingError) = err {
                displayError = underlyingError
            } else {
                displayError = err
            }

            if displayError is CancellationError {
                if lumiMessage.text.isEmpty { conversation.remove(at: idx) }
                else if !lumiMessage.text.contains("(Stopped") { conversation[idx].text += "\n(Stopped by user)"; conversation[idx].sender = .info }
            } else {
                let errorText = "\n\nError: \(displayError.localizedDescription)"
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
