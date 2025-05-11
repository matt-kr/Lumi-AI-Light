//// ThemeColors.swift
//
//import SwiftUI
//
//// Sleepy Lumi Theme Colors
//// Based on your CSS variables for html[data-theme="sleepy-lumi"]
//extension Color {
//    static let sl_bgPrimary = Color(hex: "#0a0c10")
////    static let sl_bgSecondary = Color(hex: "#141921")
//    static let sl_bgTertiary = Color(hex: "#1f242e")
//    // static let sl_bgLumiMessage = Color(hex: "#2a303b") // For chat bubbles later
//    // static let sl_bgUserMessage = Color(hex: "#1e222b") // For chat bubbles later
//
//    static let sl_textPrimary = Color(hex: "#b0bac4")
//    static let sl_textSecondary = Color(hex: "#7d8590")
//    static let sl_textPlaceholder = Color(hex: "#9ab") // Matching --text-placeholder-sleepy-lumi
//
//    static let sl_bgAccent = Color(hex: "#3b4f71")
//    static let sl_bgAccentHover = Color(hex: "#4a618a") // For hover states if needed
//    static let sl_textOnAccent = Color(hex: "#d0d8e0")
//
//    static let sl_borderPrimary = Color(hex: "#30363d")
//    static let sl_borderSecondary = Color(hex: "#21262d")
//    // static let sl_borderAccent = Color(hex: "#58a6ff") // For active elements later
//
//    static let sl_errorText = Color(hex: "#f8d7da")
//    // static let sl_errorBg = Color(hex: "#4d2226") // For error message background if desired
//
//    // Glow color from --glow-color-rgb-sleepy-lumi: 190, 210, 245
//    static let sl_glowColor = Color(red: 190/255, green: 210/255, blue: 245/255)
//}
//
//// Helper to initialize Color from HEX strings
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (255, 0, 0, 0) // Default to black if invalid
//        }
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue: Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}//
////  ThemeColors.swift
////  Lumi Light
////
////  Created by Matt Krussow on 5/10/25.
////
//
//import Foundation
