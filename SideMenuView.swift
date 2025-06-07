import SwiftUI
import PhotosUI
import SwiftData

struct SideMenuView: View {
    var isPad: Bool
    var onRequestShowSettings: () -> Void
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

    init(
        openPercentage: CGFloat,
        isPad: Bool,
        closeMenuAction: (() -> Void)? = nil,
        onRequestRename: @escaping (ConversationSession) -> Void,
        onRequestDeleteConfirmation: @escaping (ConversationSession) -> Void,
        onRequestShowSettings: @escaping () -> Void
    ) {
        self.openPercentage = openPercentage
        self.isPad = isPad
        self.closeMenuAction = closeMenuAction
        self.onRequestRename = onRequestRename
        self.onRequestDeleteConfirmation = onRequestDeleteConfirmation
        self.onRequestShowSettings = onRequestShowSettings
    }

    private func togglePinStatus(for session: ConversationSession) {
        session.isPinned.toggle()
        session.lastModifiedTime = Date()
    }
    
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
                    .padding(.top, 15)
            }
        
            Group {
                if isPad {
                    Button(action: onRequestShowSettings) {
                        Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                            .font(.custom(nasalizationFont, size: 22))
                            .foregroundColor(Color.sl_textPrimary)
                            .padding(.top, 10)
                    }
                } else {
                    NavigationLink(destination: SettingsView()) {
                        Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                            .font(.custom(nasalizationFont, size: 22))
                            .foregroundColor(Color.sl_textPrimary)
                            .padding(.top, 10)
                    }
                }
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
    private var settingsButtonView: some View {
        HStack {
            Spacer()
            Group {
                if isPad {
                    Button(action: onRequestShowSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color.sl_textSecondary)
                    }
                } else {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color.sl_textSecondary)
                    }
                }
            }
            .padding(15)
            Spacer()
        }
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
                            onRequestDeleteConfirmation(session)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    var body: some View {
        if isPad {
            // MARK: - iPad-Only Layout
            ZStack {
                Color.sl_bgSecondary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    profileHeaderView
                    Divider().background(Color.sl_glowColor.opacity(0.5)).padding(.horizontal).padding(.vertical, 10)
                    newChatButton()
                    chatHistorySection
                    settingsButtonView
                    footerView
                }
            }
            .overlay(
                Rectangle().fill(Color.sl_glowColor).frame(width: 1.5).shadow(color: Color.sl_glowColor.opacity(0.8), radius: 5, x: 2, y: 0),
                alignment: .trailing
            )
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    // Your photo processing logic here
                }
            }
        } else {
            // MARK: - iPhone-Only Layout
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
}

#Preview {
    // ... Preview code is unchanged ...
}
