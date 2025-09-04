import SwiftUI

struct OptionsListView<Option: SettingsOption>: View {
    let options: [Option]
    let selectedOption: Option?
    let onOptionSelected: (Option) -> Void

    var body: some View {
        FlowLayout(spacing: 6, rowAlignment: .leading) {
            ForEach(options) { option in
                optionButton(for: option)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func optionButton(for option: Option) -> some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            onOptionSelected(option)
        }) {
            Text(option.displayName)
                .font(AppStyling.valueFont)
                .foregroundColor(selectedOption?.id == option.id ? AppStyling.backgroundColor : AppStyling.textColor.opacity(0.7))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selectedOption?.id == option.id ? AnyShapeStyle(AppStyling.greenGradient) : AnyShapeStyle(AppStyling.secondaryBackgroundColor))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
