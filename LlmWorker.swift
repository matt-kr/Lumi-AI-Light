import Foundation
@preconcurrency import MediaPipeTasksGenAI

actor LlmWorker {
    private var llmInference: LlmInference?
    private var modelPath: String?
    private var maxTokens: Int = 2048
    
    private var currentGenerationTask: Task<Void, Never>?

    enum WorkerError: Error {
        case notConfigured
        case instanceCreationFailed
        case engineError(Error)
        case cancelled
    }

    func configure(modelPath: String, maxTokens: Int) {
        self.modelPath = modelPath
        self.maxTokens = maxTokens
        print("[Worker] Configured with model path.")
    }

    // FIXED: Added 'async'
    private func createInstance() async -> Bool {
        guard let path = self.modelPath else { print("[Worker ERROR] Model path is nil."); return false }
        print("[Worker] Creating new LlmInference instance...")
        self.llmInference = nil
        await Task.yield() // Keep the yield
        do {
            let opts = LlmInference.Options(modelPath: path)
            opts.maxTokens = maxTokens
            self.llmInference = try LlmInference(options: opts)
            print("[Worker] Instance created successfully.")
            return true
        } catch {
            print("[Worker ERROR] Failed to create instance: \(error.localizedDescription)")
            self.llmInference = nil
            return false
        }
    }
    
    func cancelGeneration() {
        print("[Worker] Received cancellation request. Cancelling task.")
        currentGenerationTask?.cancel()
        currentGenerationTask = nil // Clear reference
    }

    func generateResponse(prompt: String) -> AsyncThrowingStream<String, Error> {
        print("[Worker] Received generation request.")
        
        return AsyncThrowingStream { continuation in
            // Capture self for async tasks if needed, carefully
            let worker = self
            
            self.currentGenerationTask = Task {
                defer {
                    Task { await worker.clearTaskReference() } // Clear ref safely
                }

                guard await worker.getModelPath() != nil else { continuation.finish(throwing: WorkerError.notConfigured); return }
                
                // FIXED: Added 'await'
                guard await worker.createInstance(), let currentEngine = await worker.getEngine() else {
                    continuation.finish(throwing: WorkerError.instanceCreationFailed); return
                }

                print("[Worker Task] Starting MediaPipe generateResponseAsync...")
                let mediaPipeStream = currentEngine.generateResponseAsync(inputText: prompt)

                continuation.onTermination = { @Sendable reason in
                    print("[Worker Stream] Termination detected: \(reason). Signalling worker task cancellation.")
                    Task { await worker.cancelGeneration() } // Call actor method
                }

                do {
                    for try await chunk in mediaPipeStream {
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    print("[Worker Task] MediaPipe stream finished.")
                    continuation.finish()
                } catch is CancellationError {
                     print("[Worker Task] Caught CancellationError. Finishing stream as cancelled.")
                     continuation.finish(throwing: WorkerError.cancelled)
                } catch {
                    print("[Worker Task] MediaPipe stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: WorkerError.engineError(error))
                }
            }
        }
    }
    
    // Helper methods to access properties within the actor safely from the task
    private func getModelPath() -> String? { self.modelPath }
    private func getEngine() -> LlmInference? { self.llmInference }
    private func clearTaskReference() { self.currentGenerationTask = nil }
}
