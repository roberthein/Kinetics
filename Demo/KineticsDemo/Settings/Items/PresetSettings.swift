import SwiftUI
import Combine
import Kinetics

@MainActor
final class PresetSettingsItem: SettingsItem, ObservableObject {
    let id: UUID = .init()

    var icon: some View {
        Image(systemName: "sparkles.rectangle.stack.fill")
            .foregroundStyle(AppStyling.greenGradient)
    }

    let title = "Spring Presets"

    var options: SettingsOptionConfiguration<PresetOption> {
        .list(Array(PresetOption.allCases))
    }
    
    @Published var selectedOption: PresetOption? = .playful

    func matchingPreset(for spring: KineticsSpring) -> PresetOption? {
        switch (spring.response, spring.dampingRatio) {
        case (KineticsSpring.playful.response, KineticsSpring.playful.dampingRatio): .playful
        case (KineticsSpring.elastic.response, KineticsSpring.elastic.dampingRatio): .elastic
        case (KineticsSpring.bouncy.response, KineticsSpring.bouncy.dampingRatio): .bouncy
        case (KineticsSpring.snappy.response, KineticsSpring.snappy.dampingRatio): .snappy
        case (KineticsSpring.ultraSnappy.response, KineticsSpring.ultraSnappy.dampingRatio): .ultraSnappy
        case (KineticsSpring.rigid.response, KineticsSpring.rigid.dampingRatio): .rigid
        case (KineticsSpring.gentle.response, KineticsSpring.gentle.dampingRatio): .gentle
        default: nil
        }
    }
}

enum PresetOption: String, SettingsOption, CaseIterable {
    case playful
    case elastic
    case bouncy
    case snappy
    case ultraSnappy
    case rigid
    case gentle

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var spring: KineticsSpring {
        switch self {
        case .playful: KineticsSpring.playful
        case .elastic: KineticsSpring.elastic
        case .bouncy: KineticsSpring.bouncy
        case .snappy: KineticsSpring.snappy
        case .ultraSnappy: KineticsSpring.ultraSnappy
        case .rigid: KineticsSpring.rigid
        case .gentle: KineticsSpring.gentle
        }
    }
}
