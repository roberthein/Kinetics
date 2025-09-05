import SwiftUI
import Combine
import Kinetics

@MainActor
final class SettingsViewModel: SettingsMenuViewModel {
    private let center: KineticsSpringCenter

    @Published private(set) var items: [AnySettingsItem] = []

    let background = AnyShapeStyle(.black)
    let itemBackground: AnyShapeStyle = AnyShapeStyle(
        AppStyling.glassGradient
    )

    @Published var examplesItem = ExamplesSettingsItem()
    @Published var presetItem = PresetSettingsItem()
    @Published var responseItem = ResponseSettingsItem()
    @Published var dampingRatioItem = DampingRatioSettingsItem()

    private var cancellables = Set<AnyCancellable>()

    init(center: KineticsSpringCenter) {
        self.center = center
        applySpringToControls(center.spring)

        setupItems()
        observeControlChanges()
        observeCenterChanges()
    }


    private func setupItems() {
        items = [
            AnySettingsItem(item: examplesItem) { [weak self] option in
                guard let self else { return }
                self.examplesItem.selectedOption = option
                self.objectWillChange.send()
            },
            AnySettingsItem(item: presetItem) { [weak self] option in
                guard let self else { return }
                self.presetItem.selectedOption = option
                self.responseItem.selectedOption = .response(option.spring.response)
                self.dampingRatioItem.selectedOption = .dampingRatio(option.spring.dampingRatio)
                self.pushSpring()
                self.objectWillChange.send()
            },
            AnySettingsItem(
                item: responseItem,
                onOptionSelected: { [weak self] option in
                    guard let self else { return }
                    self.responseItem.selectedOption = option
                    self.presetItem.selectedOption = nil
                    self.pushSpring()
                    self.objectWillChange.send()
                },
                onSliderChanged: { [weak self] value in
                    guard let self else { return }
                    self.responseItem.updateFromSliderValue(value)
                    self.presetItem.selectedOption = nil
                    self.pushSpring()
                    self.objectWillChange.send()
                }
            ),
            AnySettingsItem(
                item: dampingRatioItem,
                onOptionSelected: { [weak self] option in
                    guard let self else { return }
                    self.dampingRatioItem.selectedOption = option
                    self.presetItem.selectedOption = nil
                    self.pushSpring()
                    self.objectWillChange.send()
                },
                onSliderChanged: { [weak self] value in
                    guard let self else { return }
                    self.dampingRatioItem.updateFromSliderValue(value)
                    self.presetItem.selectedOption = nil
                    self.pushSpring()
                    self.objectWillChange.send()
                }
            )
        ]
    }


    private func observeCenterChanges() {
        center.$spring
            .sink { [weak self] spring in
                guard let self else { return }
                if spring != self.currentSpring {
                    self.applySpringToControls(spring)
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    private func observeControlChanges() {
        Publishers.Merge3(
            presetItem.$selectedOption.map { _ in () }.eraseToAnyPublisher(),
            responseItem.$selectedOption.map { _ in () }.eraseToAnyPublisher(),
            dampingRatioItem.$selectedOption.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in self?.pushSpring() }
        .store(in: &cancellables)

        items.forEach { item in
            item.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }


    var currentSpring: KineticsSpring {
        if let preset = presetItem.selectedOption {
            return preset.spring
        } else {
            let response = responseItem.selectedOption?.value ?? KineticsSpring.playful.response
            let damping  = dampingRatioItem.selectedOption?.value ?? KineticsSpring.playful.dampingRatio
            return KineticsSpring(dampingRatio: damping, response: response)
        }
    }

    private func pushSpring() {
        let new = currentSpring
        if center.spring != new {
            center.set(new)
        }
    }

    private func applySpringToControls(_ s: KineticsSpring) {
        if let match = presetItem.matchingPreset(for: s) {
            presetItem.selectedOption = match
        } else {
            presetItem.selectedOption = nil
        }
        responseItem.selectedOption = .response(s.response)
        dampingRatioItem.selectedOption = .dampingRatio(s.dampingRatio)
    }
}
