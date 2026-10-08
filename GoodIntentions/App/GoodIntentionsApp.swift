import SwiftUI
import UIKit

@main
struct GoodIntentionsApp: App {
    init() {
        // Screen titles in a serif, to match the letters.
        let bar = UINavigationBar.appearance()
        if let large = Self.serif(.largeTitle) {
            bar.largeTitleTextAttributes = [.font: large]
        }
        if let inline = Self.serif(.headline) {
            bar.titleTextAttributes = [.font: inline]
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private static func serif(_ style: UIFont.TextStyle) -> UIFont? {
        let base = UIFont.preferredFont(forTextStyle: style).fontDescriptor
        guard let descriptor = base.withDesign(.serif)?.withSymbolicTraits(.traitBold) else { return nil }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
