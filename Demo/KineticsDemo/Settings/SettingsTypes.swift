import SwiftUI
import Combine

enum SettingsOptionConfiguration<Option: SettingsOption> {
    case list([Option])
    case ruler(RulerConfiguration)
}

struct RulerConfiguration {
    let currentValue: Double
    let alignment: RulerView.Alignment
    let range: ClosedRange<Double>
    let stepSize: Double
    let subStepCount: Int
    let tickSpacing: Double
}

@MainActor
final class AnySettingsItem: ObservableObject, Identifiable {
    let id: UUID
    let title: String
    let iconView: AnyView
    let optionsView: (Binding<Bool>) -> AnyView
    let displayValue: () -> String?

    init<Item: SettingsItem & ObservableObject>(item: Item, onOptionSelected: @escaping (Item.OptionType) -> Void, onSliderChanged: ((Double) -> Void)? = nil) where Item.ObjectWillChangePublisher == ObservableObjectPublisher {
        self.id = item.id
        self.title = item.title
        self.iconView = AnyView(item.icon)

        self.displayValue = { [weak item] in
            item?.selectedOption?.displayName
        }

        self.optionsView = { [weak item] isExpanded in
            guard let item = item else { return AnyView(EmptyView()) }

            return AnyView(
                Group {
                    switch item.options {
                    case .list(let options):
                        OptionsListView(
                            options: options,
                            selectedOption: item.selectedOption
                        ) { option in
                            onOptionSelected(option)
                        }
                    case .ruler(let config):
                        RulerView(
                            currentValue: config.currentValue,
                            alignment: config.alignment,
                            range: config.range,
                            stepSize: config.stepSize,
                            subStepCount: config.subStepCount,
                            tickSpacing: config.tickSpacing
                        ) {  newValue in
                            onSliderChanged?(newValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }
                }
            )
        }

        item.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}
