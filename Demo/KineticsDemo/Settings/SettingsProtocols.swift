import SwiftUI

@MainActor
protocol SettingsItem: Identifiable {
    associatedtype Icon: View
    associatedtype OptionType: SettingsOption

    var id: UUID { get }
    var icon: Icon { get }
    var title: String { get }
    var options: SettingsOptionConfiguration<OptionType> { get }
    var selectedOption: OptionType? { get set }
}

protocol SettingsOption: Identifiable, Equatable, CaseIterable {
    var id: String { get }
    var displayName: String { get }
}

@MainActor
protocol SettingsMenuViewModel: ObservableObject {
    var items: [AnySettingsItem] { get }
    var background: AnyShapeStyle { get }
    var itemBackground: AnyShapeStyle { get }
}
