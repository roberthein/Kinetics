import SwiftUI
import Combine
import Kinetics

@main
struct KineticsDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(KineticsSpringCenter.shared)
                .statusBarHidden()
        }
    }
}

struct ContentView: View {
    @StateObject private var settings = SettingsViewModel(center: KineticsSpringCenter.shared)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @State private var settingsHeight: CGFloat = 0
    @State private var settingsMaxWidth: CGFloat = 400

    var isLandscape: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            if let selectedOption = settings.examplesItem.selectedOption {
                Group {
                    switch selectedOption {
                    case .retargeting: RetargetingDemo()
                    case .rubberBanding: RubberBandingDemo()
                    case .pullToRelease: PullToReleaseDemo()
                    case .bounceBoundary: BounceBoundaryDemo()
                    case .snapTargets: SnapTargetsDemo()
                    case .rotationProjection: RotationProjectionDemo()
                    }
                }
                .padding(.bottom, isLandscape ? .zero : settingsHeight)
                .padding(.trailing, isLandscape ? settingsMaxWidth : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppStyling.backgroundColor)
        .overlay(alignment: isLandscape ? .bottomTrailing : .bottom) {
            SettingsMenuView(viewModel: settings, height: $settingsHeight)
                .frame(maxWidth: isLandscape ? settingsMaxWidth : nil)
                .padding(.horizontal, isLandscape ? 0 : Padding.outer)
        }
    }
}

extension Animation {
    static let softSpring = KineticsSpring.gentle.animation.speed(2)
}

struct Padding {
    static let inner: CGFloat = 8
    static let outer: CGFloat = 16
}

struct AppStyling {
    static let limeGreen: Color = .kLimeGreen
    static let springGreen: Color = .kSpringGreen
    static let strokeColor: Color = .kStroke
    static let backgroundColor: Color = .kBackground
    static let secondaryBackgroundColor: Color = .kSecondaryBackground
    static let textColor: Color = .kPrimaryText
    static let secondaryTextColor: Color = .kSecondaryText
    static func strokeStyle(for scale: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: 2 / scale)
    }

    static let cornerRadius: CGFloat = 20
    static let cornerRadiusLarge: CGFloat = 40
    static let ballDiameter: CGFloat = 60

    static let titleFont: Font = .system(size: 18, weight: .bold, design: .rounded)
    static let valueFont: Font = .system(size: 16, weight: .medium, design: .rounded)

    static let greenGradient = LinearGradient(
        colors: [
            limeGreen,
            springGreen
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let glassGradient = LinearGradient(
        colors: [.kGlass1, .kGlass2, .kGlass3],
        startPoint: .bottom,
        endPoint: .top
    )

    static let rulerGlassGradient = LinearGradient(
        colors: [.kGlass3, .kGlass4, .kGlass3],
        startPoint: .leading,
        endPoint: .trailing
    )
}

public struct AnimationIndicator: View {
    @Binding var state: KineticsAnimationState

    public var body: some View {
        Circle()
            .fill(AppStyling.strokeColor)
            .frame(width: 10, height: 10)
            .padding(.leading, Padding.outer)
            .padding(.bottom, Padding.outer)
            .opacity(state.isAnimating ? 1 : 0)
    }
}


#Preview {
    ContentView()
}
