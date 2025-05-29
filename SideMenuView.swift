import SwiftUI
import PhotosUI // For PhotosPickerItem

struct SideMenuView: View {
    var openPercentage: CGFloat
    @StateObject private var userData = UserData.shared

    let glowColor = Color.sl_glowColor
    let nasalizationFont = "Nasalization-Regular"

    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?

    // MARK: - Extracted Subviews
    @ViewBuilder
    private var profileHeaderView: some View {
        VStack(alignment: .leading) {
            // --- MODIFIED IMAGE INTERACTION ---
            Menu {
                // This content appears when the label (the image) is tapped
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Change Photo", systemImage: "photo.on.rectangle")
                }

                if userData.hasCustomImage { // Assumes hasCustomImage is @Published in UserData
                    Button(role: .destructive) {
                        userData.deleteProfileImage()
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            } label: {
                // This is the view that, when tapped, shows the Menu
                (userData.profileImage ?? Image("default_profile_icon"))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }
            // The .onTapGesture directly on the image is removed.
            // The .contextMenu can remain if you want long-press to also show these options,
            // or you can remove it if the tap-activated Menu is sufficient.
            .contextMenu {
                Button { showingPhotoPicker = true } label: { Label("Change Photo", systemImage: "photo.on.rectangle") }
                if userData.hasCustomImage {
                    Button(role: .destructive) { userData.deleteProfileImage() } label: { Label("Remove Photo", systemImage: "trash") }
                }
            }
            .padding(.top, 60)
            // --- END MODIFIED IMAGE INTERACTION ---

            Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                .font(.custom(nasalizationFont, size: 22))
                .foregroundColor(Color.sl_textPrimary)
                .padding(.top, 8)

            if processingImage {
                ProgressView().padding(.top, 5)
            }
            if let errorMsg = imageError {
                Text(errorMsg)
                    .font(.custom(nasalizationFont, size: 10))
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private var navigationLinksView: some View {
        NavigationLink { SettingsView() } label: { menuRow(icon: "gearshape.fill", text: "Settings") }
        NavigationLink { Text("Past Conversations (Coming Soon!)")
                .font(.custom(nasalizationFont, size: 18)) // Choose your desired size
                                .foregroundColor(Color.sl_textPrimary)
            .navigationTitle("History") } label: { menuRow(icon: "clock.fill", text: "History") }
    }

    @ViewBuilder
    private var footerView: some View {
        Text("Lumi v1.0")
            .font(.custom(nasalizationFont, size: 12))
            .foregroundColor(Color.sl_textSecondary)
            .padding()
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileHeaderView
            navigationLinksView
            Spacer()
            footerView
        }
        .overlay(
            Rectangle()
                .fill(glowColor)
                .frame(width: 1.5)
                .shadow(color: glowColor.opacity(0.8), radius: 5, x: 2, y: 0)
                .opacity(openPercentage),
            alignment: .trailing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sl_bgSecondary.ignoresSafeArea(.container, edges: .top))
        .edgesIgnoringSafeArea(.bottom)
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
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
                    } catch { imageError = "An error occurred." }
                }
                processingImage = false
            }
        }
    }

    @ViewBuilder
    private func menuRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.sl_textPrimary)
                .frame(width: 25)
            Text(text)
                .foregroundColor(Color.sl_textPrimary)
                .font(.custom(nasalizationFont, size: 17))
            Spacer()
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
        .background(Color.clear)
    }
}

#Preview {
    SideMenuView(openPercentage: 1.0)
        .environmentObject(UserData.shared)
        .preferredColorScheme(.dark)
}
