import SwiftUI

struct BubbleView: View {
    var expand: () -> Void

    @State private var isHovered = false
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.orange.opacity(0.22))
                .scaleEffect(pulse)
                .animation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: pulse
                )

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 1, green: 0.5, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.45), radius: 8, y: 3)
                .padding(6)

            // Icon
            Image(systemName: isHovered ? "arrow.up.left.and.arrow.down.right" : "note.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isHovered)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { expand() }
        .onHover { isHovered = $0 }
        .onAppear {
            pulse = 1.15
        }
    }
}
