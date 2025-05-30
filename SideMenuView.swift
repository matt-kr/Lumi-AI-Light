import SwiftUI
import PhotosUI
import SwiftData

struct SideMenuView: View {
    var openPercentage: CGFloat
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var llmService: LlmInferenceService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ConversationSession.lastModifiedTime, order: .reverse) private var fetchedSessionsByTime: [ConversationSession]

    private var conversationHistory: [ConversationSession] {
        fetchedSessionsByTime.sorted { s1, s2 in
            if s1.isPinned && !s2.isPinned { return true }
            if !s1.isPinned && s2.isPinned { return false }
            return false
        }
    }
    
    var closeMenuAction: (() -> Void)?
    var onRequestRename: (ConversationSession) -> Void // <<<< ADDED: Callback to ContentView

    let glowColor = Color.sl_glowColor
    let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?

    // REMOVED: @State private var chatToRename: ConversationSession? = nil

    init(openPercentage: CGFloat,
         closeMenuAction: (() -> Void)? = nil,
         onRequestRename: @escaping (ConversationSession) -> Void) { // <<<< MODIFIED
        self.openPercentage = openPercentage
        self.closeMenuAction = closeMenuAction
        self.onRequestRename = onRequestRename
    }

    private func togglePinStatus(for session: ConversationSession) {
        session.isPinned.toggle()
        session.lastModifiedTime = Date()
    }

    private func deleteAction(for session: ConversationSession) {
        modelContext.delete(session)
    }
    
    // MARK: - Body
    var body: some View {
        // The ZStack for modal presentation is REMOVED from here.
        // The .sheet() modifier is REMOVED from here.
        // The nested RenamePromptView struct is REMOVED from here (it's now a separate file).
        VStack(alignment: .leading, spacing: 0) {
            profileHeaderView
            navigationLinksView
            Divider().background(glowColor.opacity(0.5)).padding(.horizontal).padding(.vertical, 10)
            newChatButton()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversationHistory) { session in
                        Button {
                            llmService.loadConversation(sessionToLoad: session)
                            closeMenuAction?()
                        } label: {
                            historyRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { togglePinStatus(for: session) } label: {
                                Label(session.isPinned ? "Unpin" : "Pin", systemImage: session.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            Button {
                                onRequestRename(session) // <<<< MODIFIED: Call the callback
                            } label: {
                                Label("Rename Chat", systemImage: "pencil")
                            }
                            Button(role: .destructive) { deleteAction(for: session) } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
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
            Task { /* ... photo processing logic ... */
                processingImage = true; imageError = nil
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
                    } catch { imageError = "An error occurred: \(error.localizedDescription)" }
                }
                processingImage = false
            }
        }
    }

    // MARK: - Nested View Builders (profileHeader, links, footer, menuRow, historyRow, newChatButton)
    // (Your existing implementations for these go here)
    @ViewBuilder private var profileHeaderView: some View { /* ... as before ... */
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
    @ViewBuilder private var navigationLinksView: some View { /* ... as before ... */
        NavigationLink { SettingsView() } label: { menuRow(icon: "gearshape.fill", text: "Settings") }
    }
    @ViewBuilder private var footerView: some View { /* ... as before ... */
        Text("Lumi v1.0")
            .font(.custom(nasalizationFont, size: 12)).foregroundColor(Color.sl_textSecondary).padding()
    }
    @ViewBuilder private func menuRow(icon: String, text: String) -> some View { /* ... as before ... */
        HStack {
            Image(systemName: icon).foregroundColor(Color.sl_textPrimary).frame(width: 25)
            Text(text).foregroundColor(Color.sl_textPrimary).font(.custom(nasalizationFont, size: 17))
            Spacer()
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
        .background(Color.clear)
    }
    @ViewBuilder private func historyRow(session: ConversationSession) -> some View { /* ... as before ... */
        HStack {
            HStack {
                if session.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                }
            }
            .frame(width: 20, alignment: .leading)

            Text(session.title)
                .foregroundColor(Color.sl_textPrimary)
                .font(.custom(nasalizationFont, size: 16))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {}.frame(width: 20)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.sl_bgPrimary.opacity(0.8))
        )
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    @ViewBuilder private func newChatButton() -> some View { /* ... as before ... */
        Button {
            llmService.startNewChat(context: modelContext)
            closeMenuAction?()
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

// Preview might need adjustment if onRequestRename is now required by init
#Preview {
    let llmServicePreview = LlmInferenceService()
    let userDataPreview = UserData.shared
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ConversationSession.self, ChatMessageModel.self, configurations: config)
    // ... (add sample data to container) ...
    
    return SideMenuView(
        openPercentage: 1.0,
        closeMenuAction: { print("Preview: closeMenuAction called!") },
        onRequestRename: { session in print("Preview: Rename requested for \(session.title)") } // Provide dummy closure for preview
    )
        .modelContainer(container)
        .environmentObject(llmServicePreview)
        .environmentObject(userDataPreview)
        .preferredColorScheme(.dark)
}
