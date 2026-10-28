import SwiftUI

struct AgentAccessSettingsView: View {
#if os(macOS)
    @ObservedObject private var preferences = AgentAccessPreferences.shared
    @State private var cliStatus = AgentCLIInstaller.status
    @State private var installError: String?

    var body: some View {
        EverSettingsPage(title: "Agent Access") {
            EverSettingsSection(title: "Access", detail: "Lets AI agents and the tmax command read and build your library through this app, so changes appear here immediately.") {
                Picker("Agent access", selection: $preferences.level) {
                    ForEach(AgentAccessLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("agent-access-level")
                Text(preferences.level.detail)
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(EverColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            EverSettingsSection(title: "Command line", detail: "Run tmax context in Terminal to see what an agent sees. Tmax opens itself when a command needs it.") {
                SettingsActionRow(title: statusTitle, detail: statusDetail, symbol: "terminal")
                if cliStatus == .notInstalled || cliStatus == .foreign {
                    Button("Install tmax command") { install() }
                        .buttonStyle(EverSecondaryButtonStyle())
                        .accessibilityIdentifier("agent-install-cli")
                }
                if let installError {
                    Text(installError)
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(EverColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { cliStatus = AgentCLIInstaller.status }
    }

    private var statusTitle: String {
        switch cliStatus {
        case .installed: "tmax is installed"
        case .notInstalled: "tmax is not on your PATH"
        case .foreign: "Another tmax is installed"
        case .notBundled: "tmax is not in this build"
        }
    }

    private var statusDetail: String {
        switch cliStatus {
        case .installed: AgentCLIInstaller.link.path
        case .notInstalled: "Adds a link in ~/.local/bin"
        case .foreign: "\(AgentCLIInstaller.link.path) points somewhere else"
        case .notBundled: "Build the app with the Rust toolchain installed"
        }
    }

    private func install() {
        do {
            try AgentCLIInstaller.install()
            installError = nil
        } catch {
            installError = error.localizedDescription
        }
        cliStatus = AgentCLIInstaller.status
    }
#else
    var body: some View {
        EverSettingsPage(title: "Agent Access") {
            EverSettingsSection(title: "Mac only", detail: "Agent access and the tmax command run in the Mac app. Your iPhone receives the same library through backups or database sync.") {
                EmptyView()
            }
        }
    }
#endif
}
