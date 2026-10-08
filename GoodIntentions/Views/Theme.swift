// Paper, ink and sealing wax. Every colour has a light and a dark value.

import SwiftUI
import UIKit

enum Theme {
    /// The surface everything sits on.
    static let desk = dynamic(light: (0.93, 0.90, 0.84), dark: (0.09, 0.085, 0.075))
    /// What tiles and list rows are made of.
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let paper = dynamic(light: (0.98, 0.96, 0.91), dark: (0.17, 0.16, 0.14))
    static let ink = dynamic(light: (0.14, 0.13, 0.17), dark: (0.93, 0.90, 0.84))
    static let seal = dynamic(light: (0.66, 0.13, 0.15), dark: (0.93, 0.42, 0.38))
    static let laurel = dynamic(light: (0.18, 0.42, 0.27), dark: (0.52, 0.78, 0.58))

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}

extension View {
    /// Puts a scrolling screen on the desk instead of the system's grey.
    func onDesk() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.desk.ignoresSafeArea())
    }
}
