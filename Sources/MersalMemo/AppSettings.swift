import SwiftUI

enum BubblePosition: String, CaseIterable {
    case topLeft     = "Top Left"
    case topRight    = "Top Right"
    case bottomLeft  = "Bottom Left"
    case bottomRight = "Bottom Right"
}

class AppSettings: ObservableObject {
    @Published var bubblePosition: BubblePosition {
        didSet { UserDefaults.standard.set(bubblePosition.rawValue, forKey: "bubblePosition") }
    }
    @Published var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "bubblePosition") ?? ""
        bubblePosition = BubblePosition(rawValue: raw) ?? .topRight
        let op = UserDefaults.standard.double(forKey: "windowOpacity")
        windowOpacity = op > 0 ? op : 1.0
    }
}
