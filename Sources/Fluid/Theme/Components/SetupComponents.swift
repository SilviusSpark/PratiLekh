//
//  SetupComponents.swift
//  fluid
//
//  Helper components for setup and onboarding UI
//

import AppKit
import SwiftUI

// MARK: - Setup Step View

struct SetupStepView: View {
    @Environment(\.theme) private var theme
    let step: Int
    let title: String
    let description: String
    let status: SetupStatus
    let action: () -> Void
    var actionButtonTitle: String = "Configure"
    var showActionButton: Bool = true

    enum SetupStatus {
        case pending, completed, inProgress
    }

    var body: some View {
        if self.status == .completed || !self.showActionButton {
            self.rowContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(self.title)
                .accessibilityValue(self.status == .completed ? "Complete" : "")
        } else {
            Button(action: self.action) { self.rowContent }
                .buttonStyle(.plain)
        }
    }

    private var rowContent: some View {
            HStack(alignment: .center, spacing: 10) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(self.statusColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(self.statusColor.opacity(0.25), lineWidth: 1)
                        )

                    if self.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(self.statusColor)
                            .font(.body.weight(.semibold))
                    } else if self.status == .inProgress {
                        ProgressView()
                            .controlSize(.small)
                            .fixedSize()
                            .tint(self.statusColor)
                    } else {
                        Text("\(self.step)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(self.statusColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(self.theme.palette.primaryText)

                    if self.status != .completed {
                        Text(self.description)
                            .font(.caption)
                            .foregroundStyle(self.theme.palette.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Action button or status badge
                if self.status != .completed && self.showActionButton {
                    HStack(spacing: 3) {
                        Text(self.actionButtonTitle)
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(self.theme.palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(self.theme.palette.accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, self.status == .completed ? 4 : 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.status == .completed
                        ? self.theme.palette.accent.opacity(0.06)
                        : self.theme.palette.cardBackground.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                self.status == .completed
                                    ? self.theme.palette.accent.opacity(0.25)
                                    : self.theme.palette.cardBorder.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
    }

    private var statusColor: Color {
        switch self.status {
        case .completed: return self.theme.palette.accent
        case .inProgress: return self.theme.palette.accent
        case .pending: return .secondary
        }
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    @Environment(\.theme) private var theme
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(self.theme.palette.accent.opacity(0.15))
                    .frame(width: 22, height: 22)

                Text("\(self.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(self.theme.palette.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(self.title)
                    .font(.subheadline.weight(.medium))

                Text(self.description)
                    .font(.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
                    .lineLimit(2)
            }
        }
    }
}
