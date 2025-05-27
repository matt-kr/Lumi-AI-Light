import SwiftUI
import Combine // For ObservableObject

@MainActor // Ensure UI updates are on the main thread
class UserData: ObservableObject {
    static let shared = UserData()

    @Published var userName: String { didSet { UserDefaults.standard.set(userName, forKey: "UserName") } }
    @Published var userAbout: String { didSet { UserDefaults.standard.set(userAbout, forKey: "UserAbout") } }
    @Published var personalityType: String { didSet { UserDefaults.standard.set(personalityType, forKey: "UserPersonalityType") } }
    @Published var customPersonality: String { didSet { UserDefaults.standard.set(customPersonality, forKey: "UserCustomPersonality") } }

    // --- NEW PROPERTIES FOR PROFILE IMAGE ---
    @Published var profileImage: Image?
    private let profileImageFilename = "user_profile_image.jpg"
    private let hasCustomProfileImageKey = "hasCustomProfileImage"
    // --- END NEW PROPERTIES ---

    private init() {
        self.userName = UserDefaults.standard.string(forKey: "UserName") ?? ""
        self.userAbout = UserDefaults.standard.string(forKey: "UserAbout") ?? ""
        self.personalityType = UserDefaults.standard.string(forKey: "UserPersonalityType") ?? "Lumi"
        self.customPersonality = UserDefaults.standard.string(forKey: "UserCustomPersonality") ?? ""
        
        // --- LOAD PROFILE IMAGE ON INIT ---
        loadProfileImage()
        // --- END LOAD ---
    }

    // MARK: - Profile Image Management
    private func getProfileImageURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(profileImageFilename)
    }

    func saveProfileImage(imageData: Data) {
        guard let url = getProfileImageURL() else {
            print("Error: Could not get profile image URL.")
            return
        }
        do {
            try imageData.write(to: url, options: .atomic)
            UserDefaults.standard.set(true, forKey: hasCustomProfileImageKey)
            if let uiImage = UIImage(data: imageData) {
                self.profileImage = Image(uiImage: uiImage)
                print("Profile image saved and loaded into UI.")
            } else {
                print("Error: Could not create UIImage from saved data after saving.")
                deleteProfileImage() // Fallback if data is corrupt
            }
        } catch {
            print("Error saving profile image: \(error)")
        }
    }

    func loadProfileImage() {
        if UserDefaults.standard.bool(forKey: hasCustomProfileImageKey) {
            guard let url = getProfileImageURL(),
                  let imageData = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: imageData) else {
                print("Could not load custom profile image from disk, or data was corrupt. Reverting to default.")
                // If loading fails, ensure we reset the flag and use default
                deleteProfileImage() // This will set the default image
                return
            }
            self.profileImage = Image(uiImage: uiImage)
            print("Custom profile image loaded from disk.")
        } else {
            self.profileImage = Image("default_profile_icon") // Your default asset name
            print("Using default profile image.")
        }
    }

    func deleteProfileImage() {
        if let url = getProfileImageURL() {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("Custom profile image file deleted.")
                }
            } catch {
                print("Error deleting profile image file: \(error)")
            }
        }
        UserDefaults.standard.set(false, forKey: hasCustomProfileImageKey)
        self.profileImage = Image("default_profile_icon") // Set back to default
        print("Reverted to default profile image.")
    }

    // Keep your existing loadData function, or adapt if needed
    func loadData() -> (name: String, about: String, personality: String, custom: String) {
        let name = UserDefaults.standard.string(forKey: "UserName") ?? ""
        let about = UserDefaults.standard.string(forKey: "UserAbout") ?? ""
        let personality = UserDefaults.standard.string(forKey: "UserPersonalityType") ?? "Lumi"
        let custom = UserDefaults.standard.string(forKey: "UserCustomPersonality") ?? ""

        if self.userName != name { self.userName = name }
        if self.userAbout != about { self.userAbout = about }
        if self.personalityType != personality { self.personalityType = personality }
        if self.customPersonality != custom { self.customPersonality = custom }
        // Note: profileImage is loaded separately in init/loadProfileImage

        return (name, about, personality, custom)
    }
}
