import SwiftUI
import PhotosUI // For PhotosPickerItem
import SwiftData // <<<< ADD SwiftData import

struct SideMenuView: View {
    var openPercentage: CGFloat
    // MARK: - Environment Objects & Context
    @EnvironmentObject private var userData: UserData // <<<< CHANGED to EnvironmentObject
    @EnvironmentObject private var llmService: LlmInferenceService // <<<< ADDED
    @Environment(\.modelContext) private var modelContext // <<<< ADDED

    // MARK: - SwiftData Query for Conversation History
    // Fetches all ConversationSession objects, sorted by startTime, newest first.
    @Query(sort: \ConversationSession.startTime, order: .reverse) private var conversationHistory: [ConversationSession]
    
    var closeMenuAction: (() -> Void)? // <<<< This property is needed


    let glowColor = Color.sl_glowColor
    let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?

    // MARK: - REMOVED PLACEHOLDER STRUCTS & DATA

    // MARK: - Extracted Subviews
    @ViewBuilder
    private var profileHeaderView: some View {
        VStack(alignment: .leading) {
            Menu {
                Button { showingPhotoPicker = true } label: { Label("Change Photo", systemImage: "photo.on.rectangle") }
                if userData.hasCustomImage {
                    Button(role: .destructive) { userData.deleteProfileImage() } label: { Label("Remove Photo", systemImage: "trash") }
                }
            } label: {
                (userData.profileImage ?? Image("default_profile_icon"))
                    .resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
            }
            .contextMenu {
                Button { showingPhotoPicker = true } label: { Label("Change Photo", systemImage: "photo.on.rectangle") }
                if userData.hasCustomImage {
                    Button(role: .destructive) { userData.deleteProfileImage() } label: { Label("Remove Photo", systemImage: "trash") }
                }
            }
            .padding(.top, 60)

            Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                .font(.custom(nasalizationFont, size: 22)).foregroundColor(Color.sl_textPrimary).padding(.top, 8)

            if processingImage { ProgressView().padding(.top, 5) }
            if let errorMsg = imageError {
                Text(errorMsg).font(.custom(nasalizationFont, size: 10)).foregroundColor(.red).padding(.top, 5)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private var navigationLinksView: some View {
        NavigationLink { SettingsView() } label: { menuRow(icon: "gearshape.fill", text: "Settings") }
        // MARK: - REMOVED "History" NavigationLink
        // NavigationLink { Text("Past Conversations (Coming Soon!)")... } label: { menuRow(icon: "clock.fill", text: "History") }
    }

    @ViewBuilder
    private var footerView: some View {
        Text("Lumi v1.0") // You can update this to reflect app version if needed
            .font(.custom(nasalizationFont, size: 12)).foregroundColor(Color.sl_textSecondary).padding()
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileHeaderView
            
            navigationLinksView

            Divider()
                .background(glowColor.opacity(0.5))
                .padding(.horizontal)
                .padding(.vertical, 10)

            // Text("Chats") // This was removed as per your request

            newChatButton() // "New Chat" button calls llmService.startNewChat(context: modelContext)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversationHistory) { session in
                        Button {
                            // MARK: - LOAD CONVERSATION ACTION
                            print("Tapping to load chat: \(session.title)")
                            llmService.loadConversation(sessionToLoad: session)
                            
                            // TODO LATER: Close the Side Menu
                            // This part usually involves telling ContentView to hide the menu.
                            // We can implement this by:
                            // 1. Adding a binding or callback to SideMenuView (e.g., `var closeMenu: () -> Void`)
                            // 2. ContentView would provide this action.
                            // 3. Call `closeMenu()` here.
                            // For now, ChatView will update with the loaded content.
                            
                        } label: {
                             historyRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            Spacer()
            
            footerView
        }
        .overlay(
            Rectangle().fill(glowColor).frame(width: 1.5).shadow(color: glowColor.opacity(0.8), radius: 5, x: 2, y: 0).opacity(openPercentage),
            alignment: .trailing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sl_bgSecondary.ignoresSafeArea(.container, edges: .top))
        .edgesIgnoringSafeArea(.bottom)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                processingImage = true
                imageError = nil
                if let item = newItem {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            imageError = "Could not load image."; processingImage = false; return
                        }
                        let processedData = try await ImageHelper.processImage(data: data)
                        userData.saveProfileImage(imageData: processedData)
                    } catch let anError as ImageProcessError {
                        switch anError {
                        case .loadFailed: imageError = "Failed to load."
                        case .resizeFailed: imageError = "Failed to resize."
                        case .compressionFailed: imageError = "Failed to compress."
                        case .tooLargeAfterProcessing: imageError = "Image too large."
                        }
                    } catch { imageError = "An error occurred: \(error.localizedDescription)" } // Added more error detail
                }
                processingImage = false
            }
        }
    }

    @ViewBuilder
    private func menuRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(Color.sl_textPrimary).frame(width: 25)
            Text(text).foregroundColor(Color.sl_textPrimary).font(.custom(nasalizationFont, size: 17))
            Spacer()
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
        .background(Color.clear)
    }

    // MARK: - Updated History Row & Button Views
    @ViewBuilder
    private func historyRow(session: ConversationSession) -> some View {
        HStack {
            Text(session.title) // Using Date/Time as requested ("MMM d, HH:mm")
                .foregroundColor(Color.sl_textPrimary)
                .font(.custom(nasalizationFont, size: 16))
                .lineLimit(1)
                .padding(.vertical, 10)

            Spacer()

            Button {
                // MARK: - Implement Delete Action
                print("Attempting to delete chat \(session.id) - \(session.title)")
                modelContext.delete(session)
                // SwiftData typically auto-saves, but an explicit save can be good practice
                // especially if you want to immediately ensure it's written.
                // However, frequent explicit saves can sometimes be less performant.
                // For delete, an explicit save is often fine.
                // For now, let's rely on SwiftData's context management or add explicit save if issues persist.
                // try? modelContext.save() // Uncomment if needed
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.red)
                    .font(.system(size: 12, weight: .bold))
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading)
        .padding(.trailing, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sl_bgPrimary.opacity(0.8))
        )
        .padding(.horizontal)
        .padding(.bottom, 5)
    }

    @ViewBuilder
    private func newChatButton() -> some View {
        Button {
            // MARK: - Implement New Chat Action
            print("Starting New Chat via Side Menu")
            llmService.startNewChat(context: modelContext)
            // Optionally, add logic here to close the side menu if it's open
        } label: {
            HStack {
                Spacer()
                Text("New Chat")
                    .font(.custom(nasalizationFont, size: 17))
                Spacer()
            }
            .padding(.vertical, 12)
            .foregroundColor(Color.sl_textOnAccent)
            .background(Color.sl_bgAccent)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 15)
    }
}

// MARK: - Preview
#Preview {
    // Create a dummy LlmInferenceService for preview
    let llmServicePreview = LlmInferenceService()
    // Create dummy UserData for preview
    // Assuming UserData.shared is suitable for previews or you have a specific preview instance
    let userDataPreview = UserData.shared

    SideMenuView(openPercentage: 1.0)
        .modelContainer(for: [ConversationSession.self, ChatMessageModel.self], inMemory: true) // Sets up in-memory SwiftData
        .environmentObject(llmServicePreview)
        .environmentObject(userDataPreview)
        .preferredColorScheme(.dark)
        // The .onAppear block that caused the error has been removed.
        // If you want sample data in the preview, you would typically:
        // 1. Create a ModelContainer specifically for the preview.
        // 2. Get its mainContext.
        // 3. Insert your sample ConversationSession and ChatMessageModel objects there.
        //    For example, you can do this in a helper function or directly when setting up the container.
        //
        // Example (conceptual, actual implementation would depend on your preview setup needs):
        // .modelContainer {
        //     let container = try ModelContainer(for: ConversationSession.self, ChatMessageModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        //     let context = container.mainContext
        //     let sampleSession1 = ConversationSession(startTime: Date().addingTimeInterval(-36000), messages: [])
        //     let sampleSession2 = ConversationSession(startTime: Date(), messages: [])
        //     context.insert(sampleSession1)
        //     context.insert(sampleSession2)
        //     // Add sample ChatMessageModels to sessions if needed
        //     return container
        // }
}
                // Sample messages could be added here too
