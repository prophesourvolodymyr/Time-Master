#if os(iOS)
import SwiftUI
import UIKit

struct OutdoorTypePicker: View {
    @Binding var previewKind: OutdoorActivityKind
    let committedKind: OutdoorActivityKind
    let prompt: OutdoorModeReminder.Prompt?
    let onCommit: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var preferredRowHeight: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            if let prompt {
                Text(prompt == .choose ? "What are you heading out for?" : "Ready for a \(previewKind.displayName.lowercased())?")
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            GeometryReader { proxy in
                OutdoorActivityCarousel(
                    kind: $previewKind,
                    rowHeight: max(44, min(preferredRowHeight, proxy.size.height / 3))
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipped()
            Button(action: onCommit) {
                Label("Accept", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(OutdoorPineButtonStyle(prominent: true))
            .accessibilityLabel("Accept \(previewKind.displayName)")
            .accessibilityValue("Current Start type: \(committedKind.displayName)")
            .accessibilityIdentifier("confirm-outdoor-mode")
            .accessibilityHint(prompt == nil ? "Use this activity and close the picker" : "Use this activity, close the picker, and start recording")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

private struct OutdoorActivityCarousel: UIViewRepresentable {
    @Binding var kind: OutdoorActivityKind
    let rowHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(kind: $kind, rowHeight: rowHeight) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.backgroundColor = .clear
        picker.setContentHuggingPriority(.defaultLow, for: .vertical)
        picker.accessibilityLabel = "Workout type"
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.kind = $kind
        if coordinator.rowHeight != rowHeight {
            coordinator.rowHeight = rowHeight
            picker.reloadAllComponents()
        }
        if let row = Coordinator.choices.firstIndex(of: kind), picker.selectedRow(inComponent: 0) != row {
            picker.selectRow(row, inComponent: 0, animated: false)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPickerView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: rowHeight * 4, height: rowHeight * 3))
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        static let choices = OutdoorActivityKind.newRecordingChoices
        var kind: Binding<OutdoorActivityKind>
        var rowHeight: CGFloat
        private let feedback = UISelectionFeedbackGenerator()

        init(kind: Binding<OutdoorActivityKind>, rowHeight: CGFloat) {
            self.kind = kind
            self.rowHeight = rowHeight
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { Self.choices.count }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { rowHeight }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let option = Self.choices[row]
            let label = view as? UILabel ?? UILabel()
            let font = UIFont.systemFont(ofSize: rowHeight * 0.68, weight: .bold)
            let color = UIColor(Theme.textPrimary)
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: option.iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: font.pointSize * 0.8))?.withTintColor(color, renderingMode: .alwaysOriginal)
            if let image = attachment.image {
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2, width: image.size.width, height: image.size.height)
            }
            let title = NSMutableAttributedString(attachment: attachment)
            title.append(NSAttributedString(string: " \(option.displayName)", attributes: [.font: font, .foregroundColor: color]))
            label.attributedText = title
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.accessibilityLabel = option.displayName
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            kind.wrappedValue = Self.choices[row]
            feedback.selectionChanged()
        }
    }
}
#endif
