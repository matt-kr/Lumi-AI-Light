import SwiftUI

struct SettingsView: View {
    @StateObject private var userData = UserData.shared // Assuming UserData and .shared are correctly defined
    @State private var tempUserName: String = ""
    @State private var tempUserAbout: String = ""
    @State private var tempPersonalityType: String = ""
    @State private var tempCustomPersonality: String = ""
    @State private var showSavePulse: Bool = false

    private let aboutLimit = 150
    private let customPersonalityLimit = 300
    private let personalityOptions = ["Lumi", "Executive Coach", "Helpful & Enthusiastic", "Witty & Sarcastic", "Custom"]
    let nasalizationFont = "Nasalization-Regular" // Ensure this font is in your project
    
    // Your original hideKeyboard function
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder
    private func customSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SwiftUI.Font.custom(nasalizationFont, size: 13)) // Explicit SwiftUI.Font
            .foregroundColor(Color.sl_textSecondary) // Ensure this color is defined
    }
    
    var body: some View {
        ZStack {
            Color.sl_bgPrimary // Ensure this color is defined
                .ignoresSafeArea()
                .contentShape(Rectangle()) // Make the entire area tappable
                .gesture( // MODIFIED: Using DragGesture to act as a tap
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onEnded { _ in // The value isn't used, we just care that the "tap" ended
                            print("SettingsView: Background DragGesture (acting as tap) ended, dismissing keyboard.")
                            hideKeyboard()
                        }
                )

            Form {
                Section(header: customSectionHeader("User Profile")) {
                    TextField("Your Name", text: $tempUserName)
                        .font(SwiftUI.Font.custom(nasalizationFont, size: 16)) // Explicit SwiftUI.Font
                        .foregroundColor(Color.sl_textPrimary) // Ensure this color is defined

                    VStack(alignment: .leading) {
                        Text("About You (Max \(aboutLimit) chars)")
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 13))
                            .foregroundColor(Color.sl_textSecondary)
                        TextEditor(text: $tempUserAbout)
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                            .frame(height: 100)
                            .onChange(of: tempUserAbout) { _, newValue in
                                if newValue.count > aboutLimit {
                                    tempUserAbout = String(newValue.prefix(aboutLimit))
                                }
                            }
                            .foregroundColor(Color.sl_textPrimary)
                            .background(Color.sl_bgSecondary) // Ensure this color is defined
                            .cornerRadius(5)

                        Text("\(tempUserAbout.count) / \(aboutLimit)")
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                            .foregroundColor(tempUserAbout.count > aboutLimit ? .red : Color.sl_textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .listRowBackground(Color.sl_bgSecondary)
            
                Section(header: customSectionHeader("Lumi's Personality")) {
                    Picker(selection: $tempPersonalityType) {
                        ForEach(personalityOptions, id: \.self) { option in
                            Text(option)
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                                .tag(option)
                        }
                    } label: {
                        Text("Select Personality")
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                            .foregroundColor(Color.sl_textPrimary)
                    }
                    .onChange(of: tempPersonalityType) { _, _ in
                        print("Personality changed, dismissing keyboard.")
                        hideKeyboard() // Call your original hideKeyboard
                    }

                    if tempPersonalityType == "Custom" {
                        VStack(alignment: .leading) {
                            Text("Describe Custom Personality (Max \(customPersonalityLimit) chars)")
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 13))
                                .foregroundColor(Color.sl_textSecondary)
                            TextEditor(text: $tempCustomPersonality)
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                                .frame(height: 80)
                                .onChange(of: tempCustomPersonality) { _, newValue in
                                    if newValue.count > customPersonalityLimit {
                                        tempCustomPersonality = String(newValue.prefix(customPersonalityLimit))
                                    }
                                }
                                .foregroundColor(Color.sl_textPrimary)
                                .background(Color.sl_bgSecondary)
                                .cornerRadius(5)

                            Text("\(tempCustomPersonality.count) / \(customPersonalityLimit)")
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                                .foregroundColor(tempCustomPersonality.count > customPersonalityLimit ? .red : Color.sl_textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .listRowBackground(Color.sl_bgSecondary)
            
                Section {
                    Button {
                        hideKeyboard() // Call your original hideKeyboard
                        userData.userName = tempUserName; userData.userAbout = tempUserAbout
                        userData.personalityType = tempPersonalityType; userData.customPersonality = tempCustomPersonality
                        withAnimation(.easeInOut(duration: 0.25)) { showSavePulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.5)) { showSavePulse = false }
                        }
                    } label: {
                        Text("Save Context")
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 17))
                            .foregroundColor(Color.sl_textOnAccent) // Ensure this color is defined
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.sl_bgAccent)) // Ensure this color is defined
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(showSavePulse ? Color.sl_glowColor.opacity(0.8) : Color.clear, lineWidth: 2)) // Ensure this color is defined
                            .shadow(color: showSavePulse ? Color.sl_glowColor.opacity(0.7) : Color.clear, radius: showSavePulse ? 10 : 0)
                            .scaleEffect(showSavePulse ? 0.97 : 1.0)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tempUserName = userData.userName
            tempUserAbout = userData.userAbout
            tempPersonalityType = userData.personalityType.isEmpty ? "Lumi" : userData.personalityType
            tempCustomPersonality = userData.customPersonality
        }
        .environment(\.defaultMinListRowHeight, 44)
        .accentColor(Color.sl_glowColor) // Ensure this color is defined
    }
}

// Preview and placeholder UserData/Color definitions would go here
// Ensure your actual UserData and Color definitions are unique and correct in your project.

#Preview {
    struct SettingsPreviewContainer: View {
        var body: some View {
            NavigationView {
                SettingsView()
                    .environmentObject(UserData.shared) // Assumes UserData.shared is accessible
                    .preferredColorScheme(.dark)
            }
        }
    }
    return SettingsPreviewContainer()
}
