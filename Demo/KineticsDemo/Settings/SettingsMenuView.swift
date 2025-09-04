import SwiftUI

@MainActor
struct SettingsMenuView<ViewModel: SettingsMenuViewModel>: View {
    @StateObject var viewModel: ViewModel
    @State private var expandedItemId: UUID?
    @Binding var height: CGFloat

    var body: some View {
        menuContent
            .background(backgroundView)
            .sensoryFeedback(.selection, trigger: expandedItemId)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        height = proxy.size.height
                    }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        withAnimation(.softSpring) {
                            height = newHeight
                        }
                    }
            })
    }

    @ViewBuilder
    private var backgroundView: some View {
        GlassView(blurIntensity: 0.2)
            .clipShape(RoundedRectangle(cornerRadius: AppStyling.cornerRadius, style: .continuous))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var menuContent: some View {
        VStack(spacing: .zero) {
            ForEach(viewModel.items) { item in
                SettingsRowView(
                    item: item,
                    isExpanded: Binding(
                        get: { expandedItemId == item.id },
                        set: { newValue in
                            withAnimation(.softSpring) {
                                if newValue {
                                    expandedItemId = item.id
                                } else {
                                    expandedItemId = nil
                                }
                            }
                        }
                    ),
                    background: viewModel.itemBackground
                )
                .opacity(anotherItemIsOpened(besides: item) ? 0.3 : 1)
                .saturation(anotherItemIsOpened(besides: item) ? 0 : 1)
            }
        }
    }

    private func anotherItemIsOpened(besides item: AnySettingsItem) -> Bool {
        expandedItemId != nil && expandedItemId != item.id
    }
}
