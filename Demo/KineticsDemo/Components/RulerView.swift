import SwiftUI

struct RulerView: View {
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var currentValue: Double
    @State private var scrollPosition: ScrollPosition = .init(idType: Double.self)
    @State private var isUpdatingFromScroll = false

    enum Alignment { case top, bottom }

    let alignment: Alignment
    let valueRange: ClosedRange<Double>
    let tickSpacing: Double
    let stepSize: Double
    let subStepCount: Int
    let onValueChanged: (Double) -> Void

    private let tickMarkSize: CGFloat = 22
    private let majorTickHeight: CGFloat = 44
    private let minorTickHeight: CGFloat = 44
    private let currentValueColor: AnyShapeStyle = AnyShapeStyle(AppStyling.greenGradient)
    private let defaultColor: AnyShapeStyle = AnyShapeStyle(AppStyling.textColor)
    private let minorTickOpacity: Double = 0.5
    private let majorTickMinScale: CGFloat = 0.6
    private let majorTickMaxScale: CGFloat = 1.0
    private let minorTickMinScale: CGFloat = 0.3
    private let minorTickMaxScale: CGFloat = 0.6

    private var stepLength: CGFloat { tickMarkSize + CGFloat(tickSpacing) }
    private var maxScaleDistance: CGFloat { stepLength }

    public init(
        currentValue: Double,
        alignment: Alignment,
        range: ClosedRange<Double>,
        stepSize: Double,
        subStepCount: Int,
        tickSpacing: Double,
        onValueChanged: @escaping (Double) -> Void = { _ in }
    ) {
        self._currentValue = State(initialValue: currentValue)
        self.alignment = alignment
        self.valueRange = range
        self.tickSpacing = tickSpacing
        self.stepSize = stepSize
        self.subStepCount = subStepCount
        self.onValueChanged = onValueChanged
    }

    var body: some View {
        GeometryReader { gp in
            let containerWidth = gp.size.width
            let centerMargins = max((containerWidth - stepLength) / 2, 0)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(majorTickValues, id: \.self) { tickValue in
                        let selected = isApproximatelySelected(tickValue, currentValue)

                        TickCell(
                            value: tickValue,
                            isSelected: selected,
                            isLast: majorTickValues.last == tickValue,
                            tickSpacing: tickSpacing,
                            tickSize: tickMarkSize,
                            subStepCount: subStepCount,
                            valueRange: valueRange,
                            stepSize: stepSize,
                            currentValueColor: currentValueColor,
                            defaultColor: defaultColor,
                            minorTickOpacity: minorTickOpacity,
                            majorTickHeight: majorTickHeight,
                            minorTickHeight: minorTickHeight,
                            maxScaleDistance: maxScaleDistance,
                            majorTickMinScale: majorTickMinScale,
                            majorTickMaxScale: majorTickMaxScale,
                            minorTickMinScale: minorTickMinScale,
                            minorTickMaxScale: minorTickMaxScale,
                            layoutDirection: layoutDirection,
                            alignment: alignment,
                            stepLength: stepLength
                        )
                        .frame(width: stepLength)
                        .id(tickValue)
                    }
                }
                .scrollTargetLayout()
            }
            .layoutDirectionBehavior(.mirrors(in: .rightToLeft))
            .contentMargins(.horizontal, centerMargins, for: .scrollContent)
            .scrollTargetBehavior(.snap(step: stepLength))
            .scrollPosition($scrollPosition, anchor: .center)
            .background {
                CurrentValueIndicatorView(tickSize: tickMarkSize, tickSpacing: tickSpacing)
            }
            .onAppear {
                scrollToCurrentValue(animated: false)
            }
            .onChange(of: scrollPosition) { _, newPos in
                if let id = newPos.viewID(type: Double.self) {
                    isUpdatingFromScroll = true
                    currentValue = id
                    isUpdatingFromScroll = false
                    onValueChanged(id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
        .sensoryFeedback(.selection, trigger: currentValue)
    }

    private var majorTickValues: [Double] {
        let lower = valueRange.lowerBound
        let upper = valueRange.upperBound
        guard stepSize > 0, upper >= lower else { return [] }
        let steps = Int(round((upper - lower) / stepSize))
        return (0...steps).map { i in
            let v = lower + Double(i) * stepSize
            return clamp(roundToStepGrid(v), to: valueRange)
        }
    }

    private func isApproximatelySelected(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= max(stepSize * 0.25, 1e-9)
    }

    private func roundToStepGrid(_ v: Double) -> Double {
        let base = valueRange.lowerBound
        let k = (v - base) / stepSize
        return base + (k.rounded() * stepSize)
    }

    private func clamp(_ v: Double, to range: ClosedRange<Double>) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    private func nearestMajorValue(to value: Double) -> Double {
        roundToStepGrid(clamp(value, to: valueRange))
    }

    private func scrollToCurrentValue(animated: Bool) {
        let target = nearestMajorValue(to: currentValue)
        if animated {
            withAnimation(.snappy) { scrollPosition.scrollTo(id: target) }
        } else {
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { scrollPosition.scrollTo(id: target) }
        }
    }
}

private struct TickCell: View {
    let value: Double
    let isSelected: Bool
    let isLast: Bool
    let tickSpacing: Double
    let tickSize: CGFloat
    let subStepCount: Int
    let valueRange: ClosedRange<Double>
    let stepSize: Double
    let currentValueColor: AnyShapeStyle
    let defaultColor: AnyShapeStyle
    let minorTickOpacity: Double
    let majorTickHeight: CGFloat
    let minorTickHeight: CGFloat
    let maxScaleDistance: CGFloat
    let majorTickMinScale: CGFloat
    let majorTickMaxScale: CGFloat
    let minorTickMinScale: CGFloat
    let minorTickMaxScale: CGFloat
    let layoutDirection: LayoutDirection
    let alignment: RulerView.Alignment
    let stepLength: CGFloat

    var body: some View {
        VStack {
            if alignment == .top {
                TickLabelView(
                    value: value,
                    isSelected: isSelected,
                    currentValueColor: currentValueColor,
                    defaultColor: defaultColor,
                    layoutDirection: layoutDirection
                )
            }

            MajorTickMark(
                isSelected: isSelected,
                height: majorTickHeight,
                currentValueColor: currentValueColor,
                defaultColor: defaultColor,
                maxScaleDistance: maxScaleDistance,
                minScale: majorTickMinScale,
                maxScale: majorTickMaxScale,
                alignment: alignment
            )
            .overlay {
                if !isLast {
                    MinorTickMarksView(
                        subStepCount: subStepCount,
                        height: minorTickHeight,
                        opacity: minorTickOpacity,
                        defaultColor: defaultColor,
                        maxScaleDistance: maxScaleDistance,
                        minScale: minorTickMinScale,
                        maxScale: minorTickMaxScale,
                        alignment: alignment,
                        stepLength: stepLength,
                        directionSign: layoutDirection == .rightToLeft ? -1 : 1
                    )
                }
            }

            if alignment == .bottom {
                TickLabelView(
                    value: value,
                    isSelected: isSelected,
                    currentValueColor: currentValueColor,
                    defaultColor: defaultColor,
                    layoutDirection: layoutDirection
                )
            }
        }
    }
}

private struct TickLabelView: View {
    let value: Double
    let isSelected: Bool
    let currentValueColor: AnyShapeStyle
    let defaultColor: AnyShapeStyle
    let layoutDirection: LayoutDirection

    var body: some View {
        Text(value, format: .number)
            .font(AppStyling.valueFont)
            .layoutDirectionBehavior(.mirrors(in: layoutDirection == .rightToLeft ? .leftToRight : .rightToLeft))
            .foregroundStyle(isSelected ? currentValueColor : defaultColor)
    }
}

private struct MajorTickMark: View {
    let isSelected: Bool
    let height: CGFloat
    let currentValueColor: AnyShapeStyle
    let defaultColor: AnyShapeStyle
    let maxScaleDistance: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    let alignment: RulerView.Alignment

    var body: some View {
        Rectangle()
            .fill(isSelected ? currentValueColor : defaultColor)
            .frame(width: 1, height: height)
            .visualEffect { content, proxy in
                let distance = distanceFromCenter(in: proxy)
                let t = max(min(1 - Double(distance) / maxScaleDistance, 1), 0)
                let eased = UnitCurve.easeOut.value(at: t)
                let scale = minScale + (maxScale - minScale) * eased
                return content.scaleEffect(y: scale, anchor: alignment == .top ? .top : .bottom)
            }
    }

    nonisolated private func distanceFromCenter(in proxy: GeometryProxy) -> CGFloat {
        let scrollWidth = proxy.bounds(of: .scrollView)?.width ?? 0
        let center = scrollWidth / 2
        return abs(center - proxy.frame(in: .scrollView).midX)
    }
}

private struct MinorTickMarksView: View {
    let subStepCount: Int
    let height: CGFloat
    let opacity: Double
    let defaultColor: AnyShapeStyle
    let maxScaleDistance: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    let alignment: RulerView.Alignment
    let stepLength: CGFloat
    let directionSign: CGFloat

    var body: some View {
        ForEach(0..<subStepCount, id: \.self) { i in
            let offset = CGFloat(i + 1) * (stepLength / CGFloat(subStepCount + 1)) * directionSign
            Rectangle()
                .fill(defaultColor.opacity(opacity))
                .frame(width: 1, height: height)
                .visualEffect { content, proxy in
                    let scrollWidth = proxy.bounds(of: .scrollView)?.width ?? 0
                    let distance = abs(scrollWidth / 2 - proxy.frame(in: .scrollView).midX)
                    let t = max(min(1 - Double(distance) / maxScaleDistance, 1), 0)
                    let eased = UnitCurve.easeOut.value(at: t)
                    let scale = minScale + (maxScale - minScale) * eased
                    return content.scaleEffect(y: scale, anchor: alignment == .top ? .top : .bottom)
                }
                .offset(x: offset)
        }
    }
}

private struct CurrentValueIndicatorView: View {
    let tickSize: CGFloat
    let tickSpacing: Double

    var body: some View {
        RoundedRectangle(cornerRadius: AppStyling.cornerRadius, style: .continuous)
            .frame(width: (tickSize + tickSpacing) * 2)
            .foregroundStyle(AppStyling.rulerGlassGradient)
    }
}

struct SnapScrollTargetBehavior: ScrollTargetBehavior {
    let step: CGFloat
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard step > 0 else { return }
        let x = target.rect.origin.x
        target.rect.origin.x = (x / step).rounded() * step
    }
}

fileprivate extension ScrollTargetBehavior where Self == SnapScrollTargetBehavior {
    static func snap(step: CGFloat) -> SnapScrollTargetBehavior { .init(step: step) }
}
