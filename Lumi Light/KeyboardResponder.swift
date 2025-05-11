import SwiftUI
import Combine
import UIKit

class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    private var cancellableSet: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) // Handles keyboard changes like undocking, split on iPad
            .compactMap { notification -> CGRect? in
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            }
            .map { keyboardFrame -> CGFloat in
                // Calculate the intersection of the keyboard frame with the screen's bounds
                // This is important for cases like split keyboard on iPad or when keyboard is undocked
                let screenBounds = UIScreen.main.bounds
                let intersection = keyboardFrame.intersection(screenBounds)
                return intersection.isNull ? 0 : intersection.height
            }
            .subscribe(on: RunLoop.main) // Ensure updates are on the main thread
            .assign(to: \.currentHeight, on: self)
            .store(in: &cancellableSet)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
            .subscribe(on: RunLoop.main) // Ensure updates are on the main thread
            .assign(to: \.currentHeight, on: self)
            .store(in: &cancellableSet)
    }

    // It's also useful to get the animation curve and duration from the notification
    // to match the system keyboard animation precisely.
    static func keyboardAnimation(from notification: Notification) -> (duration: TimeInterval, curve: UIView.AnimationOptions)? {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return nil
        }
        return (duration, UIView.AnimationOptions(rawValue: curveValue << 16)) // Shift to match UIView.AnimationOptions
    }
}//
//  KeyboardResponder.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/11/25.
//

import Foundation
