import SwiftUI
import Combine
import Kinetics

/// ViewModel that edits spring settings and keeps them in sync with a shared `KineticsSpringCenter`.
@MainActor
final class SettingsViewModel: SettingsMenuViewModel {
    // Externally provided center (inject `KineticsSpringCenter.shared` from your view hierarchy)
    private let center: KineticsSpringCenter

    @Published private(set) var items: [AnySettingsItem] = []

    let background = AnyShapeStyle(.black)
    let itemBackground: AnyShapeStyle = AnyShapeStyle(
        AppStyling.glassGradient
    )

    // Public so views can read them
    @Published var examplesItem = ExamplesSettingsItem()
    @Published var presetItem = PresetSettingsItem()
    @Published var responseItem = ResponseSettingsItem()
    @Published var dampingRatioItem = DampingRatioSettingsItem()

    private var cancellables = Set<AnyCancellable>()

    /// Inject the spring center you use in the environment (`KineticsSpringCenter.shared` typically).
    init(center: KineticsSpringCenter) {
        self.center = center
        // Seed controls from the current center spring
        applySpringToControls(center.spring)

        setupItems()
        observeControlChanges()
        observeCenterChanges()
    }

    // MARK: - Items wiring

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
                // Drive linked controls from preset
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

    // MARK: - Change observation

    /// If other views mutate the same center, mirror those changes into our controls.
    private func observeCenterChanges() {
        center.$spring
            .sink { [weak self] spring in
                guard let self else { return }
                // Avoid feedback loop: only apply if different from our derived value
                if spring != self.currentSpring {
                    self.applySpringToControls(spring)
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    /// Also react if someone mutates these @Publisheds directly.
    private func observeControlChanges() {
        Publishers.Merge3(
            presetItem.$selectedOption.map { _ in () }.eraseToAnyPublisher(),
            responseItem.$selectedOption.map { _ in () }.eraseToAnyPublisher(),
            dampingRatioItem.$selectedOption.map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in self?.pushSpring() }
        .store(in: &cancellables)

        // Relay child item objectWillChange to our own so lists refresh properly.
        items.forEach { item in
            item.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Derived spring & publishing

    /// Returns the current spring configuration based on selected settings.
    var currentSpring: KineticsSpring {
        if let preset = presetItem.selectedOption {
            return preset.spring
        } else {
            let response = responseItem.selectedOption?.value ?? KineticsSpring.playful.response
            let damping  = dampingRatioItem.selectedOption?.value ?? KineticsSpring.playful.dampingRatio
            return KineticsSpring(dampingRatio: damping, response: response)
        }
    }

    /// Push the derived spring to the shared center (no-op if unchanged).
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
