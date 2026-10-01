import AppKit
import SwiftUI

struct FluidOnboardingLandingHero<Actions: View>: View {
    @Environment(\.theme) private var theme

    let eyebrow: String
    let title: String
    let accentTitle: String
    let firstDetail: String
    let secondDetail: String
    let actions: Actions

    init(
        eyebrow: String,
        title: String,
        accentTitle: String,
        firstDetail: String,
        secondDetail: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.accentTitle = accentTitle
        self.firstDetail = firstDetail
        self.secondDetail = secondDetail
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            FluidOnboardingAppIconMark()
                .padding(.bottom, self.eyebrow.isEmpty ? 40 : 26)

            if !self.eyebrow.isEmpty {
                Text(self.eyebrow)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4.2)
                    .foregroundStyle(FluidOnboardingLandingColors.blue.opacity(0.72))
                    .textCase(.uppercase)
                    .padding(.bottom, 16)
            }

            VStack(spacing: 4) {
                Text(self.title)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)

                Text(self.accentTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .italic()
                    .foregroundStyle(FluidOnboardingLandingColors.blue)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
            }
            .fixedSize(horizontal: false, vertical: true)

            .padding(.bottom, 28)

            VStack(spacing: 8) {
                Text(self.firstDetail)
                Text(self.secondDetail)
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.82)
            .padding(.bottom, 42)

            self.actions
        }
        .padding(.horizontal, self.theme.metrics.onboardingSurface.landing.heroPadding)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct FluidOnboardingLandingBackdrop: View {
    @Environment(\.theme) private var theme
    let glowCenter: UnitPoint
    init(glowCenter: UnitPoint = UnitPoint(x: 0.5, y: 0.18)) { self.glowCenter = glowCenter }
    var body: some View { self.theme.palette.windowBackground.ignoresSafeArea() }
}

struct FluidOnboardingCompactProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(self.value, 0), 1)
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(FluidOnboardingLandingColors.blue)
                    .frame(width: width * clampedValue)
                    .shadow(color: FluidOnboardingLandingColors.blue.opacity(0.38), radius: 8, x: 0, y: 0)
            }
        }
        .frame(width: 292, height: 4)
        .accessibilityHidden(true)
    }
}

struct FluidOnboardingCompactAppIconMark: View {
    private static let appIconImage: NSImage = NSApplication.shared.applicationIconImage
        ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    let size: CGFloat

    init(size: CGFloat = 66) {
        self.size = size
    }

    var body: some View {
        Image(nsImage: Self.appIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: self.size, height: self.size)

            .accessibilityHidden(true)
    }
}

struct FluidOnboardingLandingHoverTracker: NSViewRepresentable {
    let onMove: (CGPoint, CGSize) -> Void
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: self.onMove, onExit: self.onExit)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        context.coordinator.onMove = self.onMove
        context.coordinator.onExit = self.onExit
        view.coordinator = context.coordinator
    }

    final class Coordinator {
        var onMove: (CGPoint, CGSize) -> Void
        var onExit: () -> Void

        init(onMove: @escaping (CGPoint, CGSize) -> Void, onExit: @escaping () -> Void) {
            self.onMove = onMove
            self.onExit = onExit
        }
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?
        private var trackingArea: NSTrackingArea?

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea {
                self.removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .activeInKeyWindow,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved,
            ]
            let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self)
            self.addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            self.report(event)
        }

        override func mouseMoved(with event: NSEvent) {
            self.report(event)
        }

        override func mouseExited(with event: NSEvent) {
            self.coordinator?.onExit()
        }

        private func report(_ event: NSEvent) {
            let location = self.convert(event.locationInWindow, from: nil)
            self.coordinator?.onMove(location, self.bounds.size)
        }
    }
}

struct FluidOnboardingLandingPrimaryButton: View {
    static let size = CGSize(width: 236, height: 44)
    let title: String
    let action: () -> Void

    var body: some View {
        Button(self.title, action: self.action)
            .buttonStyle(PremiumButtonStyle(height: 44))
            .frame(width: Self.size.width)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
    }
}

private struct FluidOnboardingAppIconMark: View {
    @Environment(\.theme) private var theme
    var body: some View {
        PratiLekhMark().stroke(self.theme.palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
    }
}

private struct FluidOnboardingPortalGlow: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.secondary,
                            FluidOnboardingLandingColors.blue.opacity(0.64),
                            FluidOnboardingLandingColors.blue.opacity(0.05),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 112
                    )
                )
                .blur(radius: 7)
                .frame(width: 230, height: 25)

            Ellipse()
                .stroke(FluidOnboardingLandingColors.blue.opacity(0.42), lineWidth: 3)
                .blur(radius: 1.4)
                .frame(width: 326, height: 35)

            Ellipse()
                .stroke(FluidOnboardingLandingColors.blue.opacity(0.24), lineWidth: 1.4)
                .frame(width: 260, height: 22)
        }
    }
}

enum FluidOnboardingLandingColors {
    static let blue = FluidBrandColors.blue
}

private struct OnboardingSelectableSurfaceModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let isSelected: Bool
    let cornerRadius: CGFloat?
    let padding: CGFloat?
    let selectedBorderOpacity: Double?

    func body(content: Content) -> some View {
        let surface = self.theme.metrics.onboardingSurface
        let radius = self.cornerRadius ?? surface.optionCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .padding(self.padding ?? surface.optionPadding)
            .background(
                shape
                    .fill(self.theme.palette.cardBackground.opacity(
                        self.isSelected ? surface.selectedFillOpacity : surface.normalFillOpacity
                    ))
                    .overlay(
                        shape.stroke(
                            self.isSelected
                                ? self.theme.palette.accent.opacity(self.selectedBorderOpacity ?? surface.selectedBorderOpacity)
                                : self.theme.palette.cardBorder.opacity(surface.normalBorderOpacity),
                            lineWidth: 1
                        )
                    )
            )
            .contentShape(shape)
    }
}

private struct OnboardingEditorSurfaceModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        let surface = self.theme.metrics.onboardingSurface
        let radius = self.cornerRadius ?? surface.editorCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .padding(surface.editorPadding)
            .background(
                shape
                    .fill(self.theme.palette.cardBackground)
                    .overlay(
                        shape.stroke(self.theme.palette.cardBorder.opacity(surface.editorBorderOpacity), lineWidth: 1)
                    )
            )
    }
}

private struct OnboardingProminentButtonModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let controlSize: ControlSize?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let controlSize {
            content
                .buttonStyle(.borderedProminent)
                .controlSize(controlSize)
                .tint(self.theme.palette.accent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(self.theme.palette.accent)
        }
    }
}

private struct OnboardingSecondaryButtonModifier: ViewModifier {
    let controlSize: ControlSize?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let controlSize {
            content
                .buttonStyle(.bordered)
                .controlSize(controlSize)
        } else {
            content
                .buttonStyle(.bordered)
        }
    }
}

extension View {
    func fluidOnboardingSelectableSurface(
        isSelected: Bool,
        cornerRadius: CGFloat? = nil,
        padding: CGFloat? = nil,
        selectedBorderOpacity: Double? = nil
    ) -> some View {
        self.modifier(OnboardingSelectableSurfaceModifier(
            isSelected: isSelected,
            cornerRadius: cornerRadius,
            padding: padding,
            selectedBorderOpacity: selectedBorderOpacity
        ))
    }

    func fluidOnboardingEditorSurface(cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(OnboardingEditorSurfaceModifier(cornerRadius: cornerRadius))
    }

    func fluidOnboardingProminentButton(controlSize: ControlSize? = nil) -> some View {
        self.modifier(OnboardingProminentButtonModifier(controlSize: controlSize))
    }

    func fluidOnboardingSecondaryButton(controlSize: ControlSize? = nil) -> some View {
        self.modifier(OnboardingSecondaryButtonModifier(controlSize: controlSize))
    }
}
