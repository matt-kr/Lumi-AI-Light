import SwiftUI
import PhotosUI // For PhotosPickerItem

struct SideMenuView: View {
    // @Binding var isMenuOpen: Bool // REMOVED if not used
    var openPercentage: CGFloat
    @StateObject private var userData = UserData.shared // Observe UserData for profileImage

    let glowColor = Color.sl_glowColor
    let nasalizationFont = "Nasalization-Regular"

    // --- NEW STATE FOR PHOTO PICKER ---
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var processingImage = false
    @State private var imageError: String?
    // --- END NEW STATE ---

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header or Profile Area
            VStack(alignment: .leading) {
                // --- UPDATED IMAGE DISPLAY ---
                (userData.profileImage ?? Image("default_profile_icon")) // Display loaded image or default
                    .resizable()
                    .scaledToFill() // Use scaledToFill for better circle appearance
                    .frame(width: 80, height: 80) // Made it a bit larger
                    .clipShape(Circle())
                    //.overlay(Circle().stroke(Color.sl_textPrimary.opacity(0.5), lineWidth: 1)) // Optional border
                    .onTapGesture {
                        showingPhotoPicker = true // Show picker on tap
                    }
                    .contextMenu { // Context menu for more options
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("Change Photo", systemImage: "photo.on.rectangle")
                        }
                        if UserDefaults.standard.bool(forKey: "hasCustomProfileImage") { // Only show if custom image exists
                            Button(role: .destructive) {
                                userData.deleteProfileImage()
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                            }
                        }
                    }
                    .padding(.top, 60)
                // --- END UPDATED IMAGE DISPLAY ---

                Text(userData.userName.isEmpty ? "Welcome" : userData.userName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color.sl_textPrimary)
                    .padding(.top, 8)
                
                if processingImage {
                    ProgressView().padding(.top, 5)
                }
                if let errorMsg = imageError {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)

            // ... (Rest of your NavigationLinks, Spacer, Footer Text) ...
            NavigationLink { SettingsView() } label: { menuRow(icon: "gearshape.fill", text: "Settings") }
            NavigationLink { Text("Past Conversations (Coming Soon!)").navigationTitle("History") } label: { menuRow(icon: "clock.fill", text: "History") }
            Spacer()
            Text("Lumi v1.0").font(.caption).foregroundColor(Color.sl_textSecondary).padding()

        }
        .overlay( /* ... Your existing glow overlay ... */
            Rectangle()
                .fill(glowColor)
                .frame(width: 1.5)
                .shadow(color: glowColor.opacity(0.8), radius: 5, x: 2, y: 0)
                .opacity(openPercentage)
            , alignment: .trailing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sl_bgSecondary.ignoresSafeArea(.container, edges: .top))
        .edgesIgnoringSafeArea(.bottom)
        // --- PHOTOS PICKER MODIFIER ---
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images, // Only pick images
            photoLibrary: .shared() // Use the shared photo library
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                processingImage = true
                imageError = nil
                if let item = newItem {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            print("Failed to load image data from PhotosPickerItem.")
                            imageError = "Could not load image."
                            processingImage = false
                            return
                        }
                        print("Original selected image data size: \(data.count)")
                        
                        // Process the image (resize/compress)
                        let processedData = try await ImageHelper.processImage(data: data)
                        userData.saveProfileImage(imageData: processedData)
                        print("Successfully processed and saved image.")

                    } catch let error as ImageProcessError {
                        print("Image processing error: \(error)")
                        switch error {
                            case .loadFailed: imageError = "Failed to load."
                            case .resizeFailed: imageError = "Failed to resize."
                            case .compressionFailed: imageError = "Failed to compress."
                            case .tooLargeAfterProcessing: imageError = "Image too large."
                        }
                    } catch {
                        print("An unexpected error occurred: \(error)")
                        imageError = "An error occurred."
                    }
                }
                processingImage = false
            }
        }
    }

    @ViewBuilder
    private func menuRow(icon: String, text: String) -> some View {
        // ... (Your menuRow code)
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.sl_textPrimary)
                .frame(width: 25)
            Text(text)
                .foregroundColor(Color.sl_textPrimary)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 15)
        .padding(.horizontal)
        .background(Color.clear)
    }
}

#Preview {
    SideMenuView(openPercentage: 1.0) // Pass a dummy value for preview
        .environmentObject(UserData.shared) // UserData is needed for profileImage
        .preferredColorScheme(.dark)
}
