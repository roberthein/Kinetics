import SwiftUI

struct SettingsRowView: View {
    let item: AnySettingsItem
    @Binding var isExpanded: Bool
    let background: AnyShapeStyle

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if isExpanded {
                item.optionsView($isExpanded)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .scale(scale: 0.9, anchor: .bottom)).combined(with: .opacity),
                        removal: .push(from: .top).combined(with: .scale(scale: 0.9, anchor: .bottom)).combined(with: .opacity)
                    ))
                    .frame(maxHeight: isExpanded ? nil : .zero)
            }
        }
        .background(background.opacity(isExpanded ? 1 : 0))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppStyling.cornerRadius, topTrailingRadius: AppStyling.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var headerView: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 16) {
                item.iconView
                    .font(.system(size: 20))
                    .frame(width: 24)

                Text(item.title)
                    .font(AppStyling.titleFont)
                    .foregroundStyle(AppStyling.textColor)

                Spacer()

                if let displayValue = item.displayValue() {
                    Text(displayValue)
                        .font(AppStyling.valueFont)
                        .foregroundStyle(AppStyling.secondaryTextColor)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
