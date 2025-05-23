import SwiftUI
import Combine
@preconcurrency import MediaPipeTasksGenAI

// NOTE: ChatMessage & Sender are NOT included here.
// Ensure they are defined elsewhere in your project.

@MainActor
class LlmInferenceService: ObservableObject {
    // MARK: - Stored Properties
    private var llmInference: LlmInference?
    private let modelName: String
    private let modelExtension = "tflite"
    private let maxTokensConfig = 2048
    private var modelPath: String?

    @Published var conversation: [ChatMessage] = []
    @Published var isLoadingResponse = false
    @Published var initErrorMessage: String?

    @Published private(set) var isModelReady = false
    @Published private(set) var isLoadingModel = false

    private var currentStreamingTask: Task<Void, Never>?
    // Define both delay durations
    private let firstPromptDelayNanos: UInt64 = 200_000_000 // 200 milliseconds
    private let subsequentPromptDelayNanos: UInt64 = 50_000_000 // 50 milliseconds
    
    private var isFirstPromptAfterInit = true // Flag for the delay

    // MARK: - Init
    init(modelName: String = "gemma-2b-it-gpu-int8") {
        self.modelName = modelName
        print("LlmInferenceService initialized. Call initializeAndLoadModel() to prepare.")
    }

    // MARK: - Model Setup
    func initializeAndLoadModel() {
        guard !isModelReady, !isLoadingModel else { return }
        print("Starting initial model setup...")
        isLoadingModel = true
        
        Task(priority: .userInitiated) {
            defer { Task { @MainActor in self.isLoadingModel = false } }
            guard let foundPath = Bundle.main.path(forResource: modelName, ofType: modelExtension) else {
                let errorMsg = "CRITICAL ERROR: Model file '\(modelName).\(modelExtension)' not found."
                print(errorMsg); await MainActor.run { self.initErrorMessage = errorMsg; self.isModelReady = false; self.modelPath = nil }; return
            }
            self.modelPath = foundPath
            let success = await createLlmInstance()
            await MainActor.run {
                self.isModelReady = success
                self.initErrorMessage = success ? nil : (self.initErrorMessage ?? "Setup failed.")
                self.isFirstPromptAfterInit = true // Reset on init
                print(success ? "Initial model setup successful." : "Initial model setup failed.")
            }
        }
    }

    // MARK: - Engine Creation
    private func createLlmInstance() async -> Bool {
        guard let path = self.modelPath else {
            print("Engine creation failed: Model path not found."); await MainActor.run { self.initErrorMessage = "Model path not available." }; return false
        }
        print("[BEGIN] Creating LlmInference instance...")
        self.llmInference = nil
        do {
            let opts = LlmInference.Options(modelPath: path)
            opts.maxTokens = maxTokensConfig
            let engine = try LlmInference(options: opts)
            self.llmInference = engine
            print("[END] LlmInference instance created successfully.")
            return true
        } catch {
            let errorMsg = "Failed to create LlmInference instance: \(error.localizedDescription)"
            print("[END] LlmInference instance creation FAILED: \(errorMsg)")
            self.initErrorMessage = errorMsg; self.llmInference = nil; return false
        }
    }

    // MARK: - New chat
    func startNewChat() {
        stopGeneration()
        self.conversation.removeAll()
        self.isLoadingResponse = false
        self.isFirstPromptAfterInit = true // Reset for new chat
        print("New chat started.")
    }

    // MARK: - Generate response
    func generateResponseStreaming(prompt: String) {
        guard self.modelPath != nil else { appendError(self.initErrorMessage ?? "Model not ready.", isCritical: true); return }
        guard self.currentStreamingTask == nil else { print("Already generating."); return }
        guard !self.isLoadingResponse else { print("Inconsistent state (isLoading)."); self.isLoadingResponse = false; return }

        appendUserMessage(prompt)
        self.isLoadingResponse = true

        // Determine which delay to use and update the flag
        let delayNanos: UInt64
        if self.isFirstPromptAfterInit {
            delayNanos = firstPromptDelayNanos
            self.isFirstPromptAfterInit = false // Set to false *after* first use
        } else {
            delayNanos = subsequentPromptDelayNanos
        }

        Task {
            // Apply the determined delay
            print("[UI] Applying delay (\(delayNanos / 1_000_000)ms) to allow UI update...")
            try? await Task.sleep(nanoseconds: delayNanos)
            print("[UI] Delay finished.")

            print("[LlmService] Preparing engine...")
            let instanceCreated = await createLlmInstance()

            guard instanceCreated, let llmEngineToUse = self.llmInference else {
                print("[LlmService] Failed to create engine instance.")
                await MainActor.run {
                    appendError(self.initErrorMessage ?? "Failed to prepare engine.", isCritical: true)
                    self.isLoadingResponse = false
                }
                return
            }
            
            let historyPrompt = buildHistoryPrompt(with: prompt)
            
            self.currentStreamingTask = Task {
                defer {
                    Task { @MainActor in
                        print("[LlmService DEFER] Resetting state.")
                        self.isLoadingResponse = false
                        self.currentStreamingTask = nil
                    }
                }

                var taskError: Error? = nil; var responseReceived = false; var accumulatedResponseText = ""

                do {
                    print("[LlmService TASK] Starting stream...")
                    let responseStream = llmEngineToUse.generateResponseAsync(inputText: historyPrompt)
                    for try await chunk in responseStream {
                        if Task.isCancelled { throw CancellationError() }
                        responseReceived = true; accumulatedResponseText += chunk
                        await MainActor.run { self.appendOrUpdateLumiText(accumulatedResponseText) }
                    }
                    print("[LlmService TASK] Stream finished.")
                } catch {
                    taskError = error; print("[LlmService TASK] Caught error: \(error.localizedDescription)")
                }

                await MainActor.run {
                    print("[LlmService TASK] Finalizing stream.")
                    self.finalizeStream(taskError, gotData: responseReceived, finalAccumulatedText: accumulatedResponseText)
                }
            }
        }
    }

    // MARK: - Stop generation
    func stopGeneration() {
        print("[LlmService STOP] Stop generation requested.")
        currentStreamingTask?.cancel()
    }

    // MARK: - Helper Methods
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
            if err is CancellationError {
                if lumiMessage.text.isEmpty { conversation.remove(at: idx) }
                else if !lumiMessage.text.contains("(Stopped") { conversation[idx].text += "\n(Stopped by user)"; conversation[idx].sender = .info }
            } else {
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
