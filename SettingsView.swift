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

    @ViewBuilder
    private func customSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom(nasalizationFont, size: 13))
            .foregroundColor(Color.sl_textSecondary)
    }

    var body: some View {
        Form {
            Section(header: customSectionHeader("User Profile")) {
                TextField("Your Name", text: $tempUserName)
                    .font(.custom(nasalizationFont, size: 16))
                    .foregroundColor(Color.sl_textPrimary)

                VStack(alignment: .leading) {
                    Text("About You (Max \(aboutLimit) chars)")
                        .font(.custom(nasalizationFont, size: 13))
                        .foregroundColor(Color.sl_textSecondary)
                    TextEditor(text: $tempUserAbout)
                        .font(.custom(nasalizationFont, size: 16))
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
                        .font(.custom(nasalizationFont, size: 12))
                        .foregroundColor(tempUserAbout.count > aboutLimit ? .red : .sl_textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .listRowBackground(Color.sl_bgSecondary)

            Section(header: customSectionHeader("Lumi's Personality")) {
                Picker(selection: $tempPersonalityType) {
                    ForEach(personalityOptions, id: \.self) { option in
                        Text(option)
                            .font(.custom(nasalizationFont, size: 16))
                            .tag(option)
                    }
                } label: {
                    Text("Select Personality")
                        .font(.custom(nasalizationFont, size: 16))
                        .foregroundColor(Color.sl_textPrimary)
                }
                // Note: The .foregroundColor below might be overridden by .accentColor for the Picker's interactive elements
                // .foregroundColor(Color.sl_textPrimary)

                if tempPersonalityType == "Custom" {
                    VStack(alignment: .leading) {
                        Text("Describe Custom Personality (Max \(customPersonalityLimit) chars)")
                            .font(.custom(nasalizationFont, size: 13))
                            .foregroundColor(Color.sl_textSecondary)
                        TextEditor(text: $tempCustomPersonality)
                            .font(.custom(nasalizationFont, size: 16))
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
                            .font(.custom(nasalizationFont, size: 12))
                            .foregroundColor(tempCustomPersonality.count > customPersonalityLimit ? .red : .sl_textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                }
            }
            .listRowBackground(Color.sl_bgSecondary)
            // --- YOU CAN TRY ADDING THIS ---
            // This *might* influence the Picker's selected value text, but often doesn't reliably.
            // .environment(\.font, .custom(nasalizationFont, size: 16))
            // --- END TRY ---


            Section {
                Button {
                    hideKeyboard()
                    userData.userName = tempUserName; userData.userAbout = tempUserAbout
                    userData.personalityType = tempPersonalityType; userData.customPersonality = tempCustomPersonality
                    withAnimation(.easeInOut(duration: 0.25)) { showSavePulse = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) { showSavePulse = false }
                    }
                } label: {
                    Text("Save Context")
                        .font(.custom(nasalizationFont, size: 17))
                        .foregroundColor(Color.sl_textOnAccent)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.sl_bgAccent))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(showSavePulse ? Color.sl_glowColor.opacity(0.8) : Color.clear, lineWidth: 2))
                        .shadow(color: showSavePulse ? Color.sl_glowColor.opacity(0.7) : Color.clear, radius: showSavePulse ? 10 : 0)
                        .scaleEffect(showSavePulse ? 0.97 : 1.0)
                }
            }
            .listRowBackground(Color.clear)
        }
        .background(Color.sl_bgPrimary.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings") // This title's font is controlled by UINavigationBar.appearance()
        .navigationBarTitleDisplayMode(.inline)
        // .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            tempUserName = userData.userName; tempUserAbout = userData.userAbout
            tempPersonalityType = userData.personalityType.isEmpty ? "Lumi" : userData.personalityType
            tempCustomPersonality = userData.customPersonality
        }
        .environment(\.defaultMinListRowHeight, 44)
        .accentColor(Color.sl_glowColor) // Styles Picker selection indicators, etc.
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(UserData.shared)
            .preferredColorScheme(.dark)
    }
}
