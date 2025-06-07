import SwiftUI

struct SettingsView: View {
    var onDismiss: () -> Void = {} // Default empty closure for previews/iPhone
    var isPad: Bool = false
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
            .font(SwiftUI.Font.custom(nasalizationFont, size: 13))
            .foregroundColor(Color.sl_textSecondary)
    }
    
    var body: some View {
        if isPad {
            // MARK: - iPad-Only Layout (Correct and Unchanged)
            ZStack {
                // Main Content Area
                ZStack {
                    Color.sl_bgSecondary.ignoresSafeArea()

                    Form {
                        Section(header: customSectionHeader("User Profile")) {
                            TextField("Your Name", text: $tempUserName)
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                                .foregroundColor(Color.sl_textPrimary)

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
                                    .background(Color.sl_bgPrimary)
                                    .cornerRadius(5)

                                Text("\(tempUserAbout.count) / \(aboutLimit)")
                                    .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                                    .foregroundColor(tempUserAbout.count > aboutLimit ? .red : Color.sl_textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .listRowBackground(Color.sl_bgPrimary)
                
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
                                hideKeyboard()
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
                                        .background(Color.sl_bgPrimary)
                                        .cornerRadius(5)

                                    Text("\(tempCustomPersonality.count) / \(customPersonalityLimit)")
                                        .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                                        .foregroundColor(tempCustomPersonality.count > customPersonalityLimit ? .red : Color.sl_textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .listRowBackground(Color.sl_bgPrimary)
                
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
                                    .font(SwiftUI.Font.custom(nasalizationFont, size: 17))
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
                    .scrollContentBackground(.hidden)
                    .padding(.top, 69)
                }
                
                // Top Bar Content
                VStack {
                    ZStack {
                        // Centered Title
                        Text("Settings")
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 22))
                            .foregroundColor(Color.sl_textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Back Button
                        HStack {
                            Button {
                                onDismiss()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.backward")
                                    Text("Lumi")
                                }
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 17))
                                .foregroundColor(Color.sl_textPrimary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    Spacer()
                }
            }
            .overlay(
                Rectangle().fill(Color.sl_glowColor).frame(width: 1.5).shadow(color: Color.sl_glowColor.opacity(0.8), radius: 5, x: 2, y: 0),
                alignment: .trailing
            )
            .onAppear {
                tempUserName = userData.userName
                tempUserAbout = userData.userAbout
                tempPersonalityType = userData.personalityType.isEmpty ? "Lumi" : userData.personalityType
                tempCustomPersonality = userData.customPersonality
            }
            .environment(\.defaultMinListRowHeight, 44)
            .accentColor(Color.sl_glowColor)
            
        } else {
            // MARK: - iPhone-Only Layout (FIXED)
            ZStack {
                Color.sl_bgPrimary
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onEnded { _ in
                                hideKeyboard()
                            }
                    )
                Form {
                    Section(header: customSectionHeader("User Profile")) {
                        TextField("Your Name", text: $tempUserName)
                            .font(SwiftUI.Font.custom(nasalizationFont, size: 16))
                            .foregroundColor(Color.sl_textPrimary)

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
                                .background(Color.sl_bgPrimary)
                                .cornerRadius(5)

                            Text("\(tempUserAbout.count) / \(aboutLimit)")
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                                .foregroundColor(tempUserAbout.count > aboutLimit ? .red : Color.sl_textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .listRowBackground(Color.sl_bgPrimary)
            
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
                            hideKeyboard()
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
                                    .background(Color.sl_bgPrimary)
                                    .cornerRadius(5)

                                Text("\(tempCustomPersonality.count) / \(customPersonalityLimit)")
                                    .font(SwiftUI.Font.custom(nasalizationFont, size: 12))
                                    .foregroundColor(tempCustomPersonality.count > customPersonalityLimit ? .red : Color.sl_textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .listRowBackground(Color.sl_bgPrimary) // <-- TYPO CORRECTED HERE
            
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
                                .font(SwiftUI.Font.custom(nasalizationFont, size: 17))
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
            .accentColor(Color.sl_glowColor)
        }
    }
}
