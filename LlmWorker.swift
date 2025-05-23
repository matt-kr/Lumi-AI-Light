import Foundation
@preconcurrency import MediaPipeTasksGenAI

actor LlmWorker {
    private var llmInference: LlmInference?
    private var modelPath: String?
    private var maxTokens: Int = 2048 // Default

    enum WorkerError: Error {
        case notConfigured
        case instanceCreationFailed
        case engineError(Error)
    }

    func configure(modelPath: String, maxTokens: Int) {
        self.modelPath = modelPath
        self.maxTokens = maxTokens
        print("[Worker] Configured with model path.")
    }

    // Creates a new instance - designed to be called internally or before generate.
    // It's vital this happens *within* the actor's protection.
    private func createInstance() -> Bool {
        guard let path = self.modelPath else {
            print("[Worker ERROR] Cannot create instance: Model path is nil.")
            return false
        }
        print("[Worker] Creating new LlmInference instance...")
        self.llmInference = nil // Deallocate old
        do {
            let opts = LlmInference.Options(modelPath: path)
            opts.maxTokens = maxTokens
            self.llmInference = try LlmInference(options: opts)
            print("[Worker] LlmInference instance created successfully.")
            return true
        } catch {
            print("[Worker ERROR] Failed to create LlmInference instance: \(error.localizedDescription)")
            self.llmInference = nil
            return false
        }
    }

    // Main generation function - returns a stream safely across actor boundary.
    func generateResponse(prompt: String) -> AsyncThrowingStream<String, Error> {
        print("[Worker] Received generation request.")
        
        // Return a new stream using its continuation (builder)
        return AsyncThrowingStream { continuation in
            // Start a new Task *within* the actor's context
            // to handle the generation and bridging.
            Task {
                // Ensure we have a model path before starting.
                guard self.modelPath != nil else {
                    continuation.finish(throwing: WorkerError.notConfigured)
                    return
                }

                // Create a *fresh* instance for this request (our known stable strategy).
                guard createInstance(), let currentEngine = self.llmInference else {
                    continuation.finish(throwing: WorkerError.instanceCreationFailed)
                    return
                }

                print("[Worker Task] Starting MediaPipe's generateResponseAsync...")
                let mediaPipeStream = currentEngine.generateResponseAsync(inputText: prompt)

                // Set up termination handler to forward cancellation.
                continuation.onTermination = { @Sendable reason in
                    print("[Worker Stream] Termination detected: \(reason)")
                    // We can't directly 'cancel' the MediaPipe stream AFAIK,
                    // but this signals our Task should stop processing.
                    // If needed, we might need a more complex cancellation flag.
                }

                do {
                    // Iterate over MediaPipe's stream.
                    for try await chunk in mediaPipeStream {
                        // Forward each chunk to our outgoing stream.
                        continuation.yield(chunk)
                    }
                    // If MediaPipe stream finishes without error, finish ours.
                    print("[Worker Task] MediaPipe stream finished.")
                    continuation.finish()
                } catch {
                    // If MediaPipe stream errors, finish ours with the error.
                    print("[Worker Task] MediaPipe stream caught error: \(error.localizedDescription)")
                    continuation.finish(throwing: WorkerError.engineError(error))
                }
            }
        }
    }
}//
//  LlmWorker.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/23/25.
//

import Foundation
