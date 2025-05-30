import SwiftUI
import PhotosUI
import SwiftData

// Define the Hashable type for our navigation targets
enum SideMenuNavigationTarget: Hashable {
    case settings
}

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
    var onRequestRename: (ConversationSession) -> Void

    private let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?

    init(openPercentage: CGFloat,
         closeMenuAction: (() -> Void)? = nil,
         onRequestRename: @escaping (ConversationSession) -> Void) {
        self.openPercentage = openPercentage
        self.closeMenuAction = closeMenuAction
        self.onRequestRename = onRequestRename
    }

    // MARK: - Helper Methods (togglePinStatus, deleteAction as before)
    private func togglePinStatus(for session: ConversationSession) {
        session.isPinned.toggle()
        session.lastModifiedTime = Date()
    }
    private func deleteAction(for session: ConversationSession) {
        modelContext.delete(session)
    }
    
    // MARK: - View Builders (profileHeaderView, footerView, etc. as before)
    @ViewBuilder
    private var profileHeaderView: some View {
        VStack(alignment: .center) {
            Menu {
                Button { showingPhotoPicker = true } label: { Label("Change Photo", systemImage: "photo.on.rectangle") }
                if userData.hasCustomImage {
                    Button(role: .destructive) { userData.deleteProfileImage() } label: { Label("Remove Photo", systemImage: "trash") }
                }
            } label: {
                (userData.profileImage ?? Image("default_profile_icon"))
                    .resizable().scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            }
        
            NavigationLink(destination: SettingsView()) { // Direct navigation
                Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                    .font(.custom(nasalizationFont, size: 22))
                    .foregroundColor(Color.sl_textPrimary)
                    .padding(.top, 10) // Apply padding to the Text for consistent look
                    // Add .padding(.horizontal, 10) here too if desired for the link's content appearance
            }
            .buttonStyle(.plain)
            if processingImage { ProgressView().padding(.top, 5) }
            if let errorMsg = imageError {
                Text(errorMsg).font(.custom(nasalizationFont, size: 10)).foregroundColor(.red).padding(.top, 5).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 25)
        .padding(.horizontal)
        .padding(.bottom, 15)
    }

    @ViewBuilder
    private var footerView: some View { /* ... as before ... */
        Text("Lumi v1.0")
            .font(.custom(nasalizationFont, size: 12))
            .foregroundColor(Color.sl_textSecondary)
            .padding(.bottom, 20)
            .padding(.top, 5)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    @ViewBuilder
    private func menuRow(icon: String, text: String) -> some View { /* ... as before ... */
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
    private func historyRow(session: ConversationSession, isActive: Bool) -> some View { /* ... as before ... */
        HStack {
            HStack {
                if session.isPinned {
                    Image(systemName: "star.fill").foregroundColor(.orange).font(.system(size: 14))
                }
            }.frame(width: 20, alignment: .leading)
            Text(session.title).foregroundColor(Color.sl_textPrimary).font(.custom(nasalizationFont, size: 16)).lineLimit(1).frame(maxWidth: .infinity, alignment: .center)
            HStack {}.frame(width: 20)
        }
        .padding(.vertical, 10).padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? Color.sl_bgAccent.opacity(0.35) : Color.sl_bgPrimary.opacity(0.8)))
        .padding(.horizontal).padding(.bottom, 5)
    }
    @ViewBuilder
    private func newChatButton() -> some View { /* ... as before ... */
        Button {
            llmService.startNewChat(context: modelContext)
            closeMenuAction?()
        } label: {
            HStack {
                Spacer()
                Text("New Chat").font(.custom(nasalizationFont, size: 17))
                Spacer()
            }
            .padding(.vertical, 12).foregroundColor(Color.sl_textOnAccent).background(Color.sl_bgAccent).cornerRadius(10)
        }
        .padding(.horizontal).padding(.bottom, 15)
    }
    @ViewBuilder
    private var settingsButtonView: some View { /* ... as before ... */
        HStack {
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color.sl_textSecondary)
            }
            .padding(15)
            Spacer()
        }
    }

    private var chatHistorySection: some View { /* ... as before ... */
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(conversationHistory) { session in
                    let isActive = session.id == llmService.activeSwiftDataSession?.id
                    Button {
                        llmService.loadConversation(sessionToLoad: session)
                        closeMenuAction?()
                    } label: {
                        historyRow(session: session, isActive: isActive)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { togglePinStatus(for: session) } label: {
                            Label(session.isPinned ? "Unstar" : "Star",
                                  systemImage: session.isPinned ? "star.slash.fill" : "star.fill")
                        }
                        Button { onRequestRename(session) } label: {
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
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileHeaderView
            Divider().background(Color.sl_glowColor.opacity(0.5)).padding(.horizontal).padding(.vertical, 10)
            newChatButton()
            chatHistorySection
            settingsButtonView
            footerView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sl_bgSecondary.ignoresSafeArea(.container, edges: .top))
        .overlay(
            Rectangle().fill(Color.sl_glowColor).frame(width: 1.5).shadow(color: Color.sl_glowColor.opacity(0.8), radius: 5, x: 2, y: 0).opacity(openPercentage),
            alignment: .trailing
        )
        .edgesIgnoringSafeArea(.bottom)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { /* ... photo processing logic ... */ }
        }
    }
}

// MARK: - Preview
#Preview {
    // Helper struct to encapsulate preview setup logic
    struct SideMenuViewPreviewContainer: View {
        @State private var previewNavTarget: SideMenuNavigationTarget? = nil
        // Create fresh instances for preview if LlmInferenceService/UserData are ObservableObjects
        @StateObject private var llmServiceForPreview = LlmInferenceService()
        @StateObject private var userDataForPreview = UserData.shared // Assuming .shared gives a valid instance

        let modelContainer: ModelContainer

        init() {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(for: ConversationSession.self, ChatMessageModel.self, configurations: config)
                // Add sample data to the context
                Task { @MainActor in // Ensure context operations are on main actor if needed
                    let context = container.mainContext
                    let now = Date()
                    let sampleSession1 = ConversationSession(startTime: now.addingTimeInterval(-7200),
                                                             lastModifiedTime: now.addingTimeInterval(-300),
                                                             isPinned: true,
                                                             customTitle: "My Pinned Chat")
                    context.insert(sampleSession1)
                    // You can insert more sample data here
                    // try? context.save() // Usually not needed with autosave unless specific timing required
                }
                self.modelContainer = container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }

        var body: some View {
            NavigationView { // Important for NavigationLink and .navigationDestination
                SideMenuView(
                    openPercentage: 1.0,
                    closeMenuAction: { print("Preview: closeMenuAction called!") },
                    onRequestRename: { session in print("Preview: Rename requested for \(session.title)") }
                    // No activeNavigationTarget argument
                )
            }
            .modelContainer(modelContainer) // Apply the container to the view
            .environmentObject(llmServiceForPreview)
            .environmentObject(userDataForPreview)
            .preferredColorScheme(.dark)
        }
    }

    // Return an instance of the container struct
    return SideMenuViewPreviewContainer()
}

// REMINDER: Ensure your actual custom colors (Color.sl_...), SettingsView, ImageHelper,
// ImageProcessError, LlmInferenceService, UserData, ConversationSession, ChatMessageModel
// are correctly defined in your project.
// The SideMenuNavigationTarget enum is at the top of THIS SideMenuView.swift file.
