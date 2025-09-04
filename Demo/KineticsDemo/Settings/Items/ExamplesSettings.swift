import SwiftUI
import Combine

@MainActor
final class ExamplesSettingsItem: SettingsItem, ObservableObject {
    let id: UUID = .init()

    var icon: some View {
        Image(systemName: "hand.draw.fill")
            .foregroundStyle(AppStyling.greenGradient)
    }

    let title = "Demo"

    var options: SettingsOptionConfiguration<ExamplesOption> {
        .list(Array(ExamplesOption.allCases))
    }

    @Published var selectedOption: ExamplesOption? = .retargeting
}

enum ExamplesOption: String, SettingsOption, CaseIterable {
    case retargeting = "retargeting"
    case rubberBanding = "rubber-banding"
    case bounceBoundary = "bounce boundary"
    case snapTargets = "snap targets"
    case pullToRelease = "pull to release"
    case rotationProjection = "rotation projection"

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}
