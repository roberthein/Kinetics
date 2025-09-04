import SwiftUI
import Combine
import Kinetics

@MainActor
final class ResponseSettingsItem: SettingsItem, ObservableObject {
    let id: UUID = .init()

    var icon: some View {
        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath")
            .foregroundStyle(AppStyling.greenGradient)
    }

    let title = "Custom Spring Response"

    var options: SettingsOptionConfiguration<ResponseOption> {
        .ruler(
            RulerConfiguration(
                currentValue: selectedOption?.value ?? KineticsSpring.playful.response,
                alignment: .bottom,
                range: 0.1 ... 1,
                stepSize: 0.05,
                subStepCount: 4,
                tickSpacing: 40
            )
        )
    }

    @Published var selectedOption: ResponseOption? = .response(KineticsSpring.playful.response)

    func updateFromSliderValue(_ value: Double) {
        selectedOption = .response(value)
    }
}


enum ResponseOption: SettingsOption, CaseIterable {
    case response(Double)

    static var allCases: [ResponseOption] {
        [.response(0)]
    }

    var id: String {
        switch self {
        case let .response(value): "\(value)"
        }
    }

    var displayName: String {
        switch self {
        case let .response(value): String(format: "%.2f", abs(max(0, value)))
        }
    }

    var value: Double {
        switch self {
        case let .response(value): value
        }
    }
}
