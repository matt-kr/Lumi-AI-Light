import SwiftUI
import PhotosUI
import SwiftData

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
    var onRequestDeleteConfirmation: (ConversationSession) -> Void

    private let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?

    // Initializer
    init(openPercentage: CGFloat,
         closeMenuAction: (() -> Void)? = nil,
         onRequestRename: @escaping (ConversationSession) -> Void,
         onRequestDeleteConfirmation: @escaping (ConversationSession) -> Void) {
        self.openPercentage = openPercentage
        self.closeMenuAction = closeMenuAction
        self.onRequestRename = onRequestRename
        // ---- CORRECTED ASSIGNMENT ----
        self.onRequestDeleteConfirmation = onRequestDeleteConfirmation
        // ---- END OF CORRECTION ----
    }

    private func togglePinStatus(for session: ConversationSession) {
        session.isPinned.toggle()
        session.lastModifiedTime = Date()
    }
    
    // MARK: - View Builders (These should be fine as you posted them)
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
        
            NavigationLink(destination: SettingsView()) {
                Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                    .font(.custom(nasalizationFont, size: 22))
                    .foregroundColor(Color.sl_textPrimary)
                    .padding(.top, 10)
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
    private var footerView: some View {
        Text("Lumi v1.0")
            .font(.custom(nasalizationFont, size: 12))
            .foregroundColor(Color.sl_textSecondary)
            .padding(.bottom, 20)
            .padding(.top, 5)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func historyRow(session: ConversationSession, isActive: Bool) -> some View {
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
    private func newChatButton() -> some View {
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
    private var settingsButtonView: some View {
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

    private var chatHistorySection: some View {
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
                        Button(role: .destructive) {
                            onRequestDeleteConfirmation(session) // This calls the stored closure
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Body (This should be fine as you posted it)
    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = geometry.size.width
            let backgroundExtensionAmount = drawerWidth

            let menuVStack = VStack(alignment: .leading, spacing: 0) {
                profileHeaderView
                Divider().background(Color.sl_glowColor.opacity(0.5)).padding(.horizontal).padding(.vertical, 10)
                newChatButton()
                chatHistorySection
                settingsButtonView
                footerView
            }
            .frame(width: drawerWidth, alignment: .leading)
            .overlay(
                Rectangle().fill(Color.sl_glowColor).frame(width: 1.5).shadow(color: Color.sl_glowColor.opacity(0.8), radius: 5, x: 2, y: 0).opacity(openPercentage),
                alignment: .trailing
            )

            menuVStack
                .padding(.leading, backgroundExtensionAmount)
                .background(
                    Color.sl_bgSecondary
                        .ignoresSafeArea(.container, edges: .top)
                )
                .offset(x: -backgroundExtensionAmount)
        }
        .edgesIgnoringSafeArea(.bottom)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                // Your photo processing logic here
            }
        }
    }
}

// MARK: - Preview (This should also be fine as you posted it, as it correctly calls the init)
#Preview {
    struct SideMenuViewPreviewContainer: View {
        @StateObject private var llmServiceForPreview = LlmInferenceService()
        @StateObject private var userDataForPreview = UserData.shared
        @State private var sessionToDeleteInPreview: ConversationSession? = nil
        @State private var showDeletePromptInPreview = false
        @Environment(\.modelContext) private var modelContext

        let modelContainer: ModelContainer

        init() {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                let container = try ModelContainer(for: ConversationSession.self, ChatMessageModel.self, configurations: config)
                Task { @MainActor in
                    let context = container.mainContext
                    let now = Date()
                    let sampleData = [
                        ConversationSession(startTime: now.addingTimeInterval(-17200), lastModifiedTime: now.addingTimeInterval(-1300), isPinned: true, customTitle: "Important Chat Preview"),
                        ConversationSession(startTime: now.addingTimeInterval(-7200), lastModifiedTime: now.addingTimeInterval(-300), isPinned: false, customTitle: "My Pinned Chat Preview"),
                    ]
                    sampleData.forEach { context.insert($0) }
                }
                self.modelContainer = container
            } catch {
                fatalError("Failed to create model container for preview: \(error)")
            }
        }

        var body: some View {
            ZStack {
                NavigationView {
                    SideMenuView(
                        openPercentage: 1.0,
                        closeMenuAction: { print("Preview: closeMenuAction called!") },
                        onRequestRename: { session in print("Preview: Rename requested for \(session.title)") },
                        onRequestDeleteConfirmation: { session in
                            print("Preview: Delete confirmation requested for \(session.title)")
                            self.sessionToDeleteInPreview = session
                            self.showDeletePromptInPreview = true
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8)
                }

                if showDeletePromptInPreview, let session = sessionToDeleteInPreview {
                    Color.black.opacity(0.45)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .onTapGesture {
                            showDeletePromptInPreview = false
                            sessionToDeleteInPreview = nil
                        }
                    
                    DeleteConfirmationPromptView(
                        sessionTitle: session.title,
                        onConfirmDelete: {
                            print("Preview: Confirmed delete for \(session.title)")
                            // modelContext.delete(session) // Example
                            showDeletePromptInPreview = false
                            sessionToDeleteInPreview = nil
                        },
                        onCancel: {
                            print("Preview: Cancelled delete for \(session.title)")
                            showDeletePromptInPreview = false
                            sessionToDeleteInPreview = nil
                        }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity.combined(with: .scale(scale: 0.85))))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showDeletePromptInPreview)
            .modelContainer(modelContainer)
            .environmentObject(llmServiceForPreview)
            .environmentObject(userDataForPreview)
            .preferredColorScheme(.dark)
        }
    }
    return SideMenuViewPreviewContainer()
}
