import SwiftUI
import PhotosUI // For PhotosPickerItem
import SwiftData

struct SideMenuView: View {
    var openPercentage: CGFloat
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var llmService: LlmInferenceService
    @Environment(\.modelContext) private var modelContext

    // Sorting by startTime as per this stable version
    @Query(sort: \ConversationSession.startTime, order: .reverse) private var conversationHistory: [ConversationSession]
    
    var closeMenuAction: (() -> Void)? // This should be here

    // ... (other properties: glowColor, nasalizationFont, @State vars - KEEP AS IS) ...
    let glowColor = Color.sl_glowColor
    let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?


    // MARK: - Extracted Subviews (profileHeaderView, navigationLinksView, footerView, menuRow, historyRow - KEEP AS IS)
    // These are based on your provided code.
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
    }

    @ViewBuilder
    private var footerView: some View {
        Text("Lumi v1.0")
            .font(.custom(nasalizationFont, size: 12)).foregroundColor(Color.sl_textSecondary).padding()
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

    @ViewBuilder
    private func historyRow(session: ConversationSession) -> some View {
        HStack {
            Text(session.title)
                .foregroundColor(Color.sl_textPrimary)
                .font(.custom(nasalizationFont, size: 16))
                .lineLimit(1)
                .padding(.vertical, 10)

            Spacer()

            Button {
                print("Attempting to delete chat \(session.id) - \(session.title)")
                modelContext.delete(session)
                // try? modelContext.save() // Optional
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
            print("Starting New Chat via Side Menu")
            llmService.startNewChat(context: modelContext)
            closeMenuAction?() // <<<< ADD THIS CALL to close the menu
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


    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileHeaderView
            navigationLinksView

            Divider()
                .background(glowColor.opacity(0.5))
                .padding(.horizontal)
                .padding(.vertical, 10)

            newChatButton()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversationHistory) { session in
                        Button {
                            print("Tapping to load chat: \(session.title)")
                            llmService.loadConversation(sessionToLoad: session)
                            closeMenuAction?() // <<<< ADD THIS CALL to close the menu
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
        .overlay( /* ... your existing overlay ... */
            Rectangle().fill(glowColor).frame(width: 1.5).shadow(color: glowColor.opacity(0.8), radius: 5, x: 2, y: 0).opacity(openPercentage),
            alignment: .trailing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sl_bgSecondary.ignoresSafeArea(.container, edges: .top))
        .edgesIgnoringSafeArea(.bottom)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { /* ... your existing image processing logic ... */
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
}

// MARK: - Preview
#Preview {
    let llmServicePreview = LlmInferenceService()
    let userDataPreview = UserData.shared

    SideMenuView(
        openPercentage: 1.0,
        closeMenuAction: { print("Preview: closeMenuAction called!") } // Dummy action for preview
    )
        .modelContainer(for: [ConversationSession.self, ChatMessageModel.self], inMemory: true)
        .environmentObject(llmServicePreview)
        .environmentObject(userDataPreview)
        .preferredColorScheme(.dark)
}
