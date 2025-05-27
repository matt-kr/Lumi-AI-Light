import SwiftUI

struct SettingsView: View {
    @StateObject private var userData = UserData.shared
    @State private var tempUserName: String = ""
    @State private var tempUserAbout: String = ""
    @State private var tempPersonalityType: String = ""
    @State private var tempCustomPersonality: String = ""
    @State private var showSavePulse: Bool = false

    private let aboutLimit = 150
    private let customPersonalityLimit = 300
    private let personalityOptions = ["Lumi", "Executive Coach", "Helpful & Enthusiastic", "Witty & Sarcastic", "Custom"]
    let nasalizationFont = "Nasalization-Regular"
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        Form {
            Section("User Profile") {
                TextField("Your Name", text: $tempUserName)
                    .foregroundColor(Color.sl_textPrimary)

                VStack(alignment: .leading) {
                    Text("About You (Max \(aboutLimit) chars)")
                        .font(.caption)
                        .foregroundColor(Color.sl_textSecondary)
                    TextEditor(text: $tempUserAbout)
                        .frame(height: 100)
                        .onChange(of: tempUserAbout) { _, newValue in
                            if newValue.count > aboutLimit {
                                tempUserAbout = String(newValue.prefix(aboutLimit))
                            }
                        }
                        .foregroundColor(Color.sl_textPrimary)
                        .background(Color.sl_bgSecondary)
                        .cornerRadius(5)

                    Text("\(tempUserAbout.count) / \(aboutLimit)")
                        .font(.caption)
                        .foregroundColor(tempUserAbout.count > aboutLimit ? .red : .sl_textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .listRowBackground(Color.sl_bgSecondary)

            Section("Lumi's Personality") {
                Picker("Select Personality", selection: $tempPersonalityType) {
                    ForEach(personalityOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .foregroundColor(Color.sl_textPrimary)

                if tempPersonalityType == "Custom" {
                    VStack(alignment: .leading) {
                        Text("Describe Custom Personality (Max \(customPersonalityLimit) chars)")
                            .font(.caption)
                            .foregroundColor(Color.sl_textSecondary)
                        TextEditor(text: $tempCustomPersonality)
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
                            .font(.caption)
                            .foregroundColor(tempCustomPersonality.count > customPersonalityLimit ? .red : .sl_textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                }
            }
            .listRowBackground(Color.sl_bgSecondary)

            // --- MODIFIED BUTTON SECTION ---
            Section {
                Button {
                    hideKeyboard()
                    userData.userName = tempUserName
                    userData.userAbout = tempUserAbout
                    userData.personalityType = tempPersonalityType
                    userData.customPersonality = tempCustomPersonality

                    withAnimation(.easeInOut(duration: 0.25)) { // Slower: Glow starts
                        showSavePulse = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Slower: Hold glow (increased from 0.4)
                        withAnimation(.easeInOut(duration: 0.5)) { // Slower: Glow fades out (increased from 0.4)
                            showSavePulse = false
                        }
                    }
                } label: {
                    Text("Save Context")
                        .font(.headline) // Make text a bit bolder/bigger
                        .foregroundColor(Color.sl_textOnAccent)
                        .padding() // Add padding around text
                        .frame(maxWidth: .infinity) // Make label take full width
                        .background( // This RoundedRectangle IS the button's visible background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.sl_bgAccent) // The button's actual color
                        )
                        // Apply glow effects to the label, which now has its own background
                        .overlay( // Glowing border
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(showSavePulse ? Color.sl_glowColor.opacity(0.8) : Color.clear, lineWidth: 2)
                        )
                        .shadow( // Outer glow
                            color: showSavePulse ? Color.sl_glowColor.opacity(0.7) : Color.clear,
                            radius: showSavePulse ? 10 : 0
                        )
                        .scaleEffect(showSavePulse ? 0.97 : 1.0) // Scale the whole label
                }
                // Remove .frame, .scaleEffect, .shadow from Button directly
            }
            // Make the list row itself clear, so our button's custom background and glow are fully visible
            .listRowBackground(Color.clear)
            // --- END MODIFIED BUTTON SECTION ---
        }
        .background(Color.sl_bgPrimary.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            tempUserName = userData.userName
            tempUserAbout = userData.userAbout
            tempPersonalityType = userData.personalityType.isEmpty ? "Lumi" : userData.personalityType
            tempCustomPersonality = userData.customPersonality
        }
        .environment(\.defaultMinListRowHeight, 44)
        .accentColor(Color.sl_glowColor)
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(UserData.shared)
            .preferredColorScheme(.dark)
    }
}
