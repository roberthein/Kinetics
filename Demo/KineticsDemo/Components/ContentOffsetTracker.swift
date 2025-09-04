import Foundation
import SwiftUI

// MARK: - Namespace Constants
/// Namespace identifier for the scroll view coordinate space
private enum ScrollViewNamespace {
    static let identifier = "scrollView"
}

// MARK: - Preference Key
/// Preference key for tracking content offset changes in scroll views
private struct ContentOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        // No reduction needed - we only care about the latest value
    }
}

// MARK: - View Extension
extension View {
    /// Attaches content offset tracking to a view
    /// - Parameter onOffsetChange: Closure called when the content offset changes
    /// - Returns: A view with content offset tracking enabled
    func trackContentOffset(onOffsetChange: @escaping (_ offset: CGPoint) -> Void) -> some View {
        self.coordinateSpace(name: ScrollViewNamespace.identifier)
            .onPreferenceChange(ContentOffsetPreferenceKey.self, perform: onOffsetChange)
    }
}

// MARK: - Content Offset Tracker
/// A view that tracks content offset changes in scroll views
/// This component is designed to be placed inside a scroll view to monitor scrolling position
struct ContentOffsetTracker: View {

    // MARK: - Initialization
    init() {}

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            makeOffsetTrackingView(geometry: geometry)
        }
        .frame(height: 0) // Zero height to avoid affecting layout
    }

    // MARK: - Private View Builders

    /// Creates the view that tracks content offset
    /// - Parameter geometry: The geometry reader proxy
    /// - Returns: A view that reports its position as a preference
    @ViewBuilder
    private func makeOffsetTrackingView(geometry: GeometryProxy) -> some View {
        Color.clear
            .preference(
                key: ContentOffsetPreferenceKey.self,
                value: geometry.frame(in: .named(ScrollViewNamespace.identifier)).origin
            )
    }
}

// MARK: - Preview
#Preview {
    ContentOffsetPreviewView()
}

// MARK: - Preview Helper View
struct ContentOffsetPreviewView: View {
    @State private var contentOffset: CGPoint = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Display current offset values
            offsetDisplayView

            ScrollView {
                VStack(spacing: 20) {
                    // Add the content offset tracker
                    ContentOffsetTracker()

                    // Sample content to demonstrate scrolling
                    ForEach(0..<20, id: \.self) { index in
                        Text("Item \(index)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
            .trackContentOffset { offset in
                contentOffset = offset
            }
        }
    }

    @ViewBuilder
    private var offsetDisplayView: some View {
        VStack(spacing: 8) {
            Text("Content Offset Tracking")
                .font(.headline)
                .padding(.top)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X Offset:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", contentOffset.x))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Y Offset:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", contentOffset.y))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
            }

            // Visual indicator
            Rectangle()
                .fill(Color.green.opacity(0.3))
                .frame(height: 2)
                .frame(width: max(0, min(50, abs(contentOffset.y) / 10)))
                .animation(.easeInOut(duration: 0.1), value: contentOffset.y)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}
