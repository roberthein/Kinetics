import SwiftUI
import Combine
import Kinetics

@MainActor
final class DampingRatioSettingsItem: SettingsItem, ObservableObject {
    let id: UUID = .init()

    var icon: some View {
        Image(systemName: "scribble.variable")
            .foregroundStyle(AppStyling.greenGradient)
    }

    let title = "Custom Spring Damping"

    var options: SettingsOptionConfiguration<DampingRatioOption> {
        .ruler(
            RulerConfiguration(
                currentValue: selectedOption?.value ?? KineticsSpring.playful.dampingRatio,
                alignment: .bottom,
                range: 0.1 ... 1,
                stepSize: 0.05,
                subStepCount: 4,
                tickSpacing: 40
            )
        )
    }

    @Published var selectedOption: DampingRatioOption? = .dampingRatio(KineticsSpring.playful.dampingRatio)

    func updateFromSliderValue(_ value: Double) {
        selectedOption = .dampingRatio(value)
    }
}


enum DampingRatioOption: SettingsOption, CaseIterable {
    case dampingRatio(Double)

    static var allCases: [DampingRatioOption] {
        [.dampingRatio(0)]
    }

    var id: String {
        switch self {
        case let .dampingRatio(value): "\(value)"
        }
    }

    var displayName: String {
        switch self {
        case let .dampingRatio(value): String(format: "%.2f", abs(max(0, value)))
        }
    }

    var value: Double {
        switch self {
        case let .dampingRatio(value): value
        }
    }
}
