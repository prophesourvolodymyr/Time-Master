import SwiftUI

/// A failed change, shown in place and out of the way (it fades after a few seconds), so the list stays usable.
struct ChecklistErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ChecklistLinkChip.missingColor)
            Text(message)
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .keyNavPlainButtonStyle(shape: .circle)
            .accessibilityLabel("Dismiss")
        }
        .padding(10)
        .background(ChecklistLinkChip.missingColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .task(id: message) {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}
