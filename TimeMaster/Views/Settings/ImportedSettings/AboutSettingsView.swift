import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        EverSettingsPage(title: "About") {
            EverSettingsSection(title: "TimeMaster") {
                HStack {
                    Text("Version")
                        .font(TimeMasterFont.rowTitle())
                    Spacer(minLength: EverSpacing.x2)
                    Text(appVersion)
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(EverColor.textSecondary)
                }
                .frame(minHeight: EverLayout.standardRowMinimum)

                HStack {
                    Text("Build")
                        .font(TimeMasterFont.rowTitle())
                    Spacer(minLength: EverSpacing.x2)
                    Text(buildNumber)
                        .font(TimeMasterFont.technical())
                        .foregroundStyle(EverColor.textSecondary)
                }
                .frame(minHeight: EverLayout.standardRowMinimum)

            }

        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
