import SwiftUI

struct DatabaseSyncSettingsView: View {
    @ObservedObject private var sync = DatabaseSyncStore.shared
    @ObservedObject private var account = CloudAccountStore.shared

    private var syncBinding: Binding<Bool> {
        Binding(get: { sync.syncEnabled }, set: { enabled in
            Task { await sync.setSyncEnabled(enabled) }
        })
    }

    var body: some View {
        EverSettingsPage(title: "Database Sync") {
            EverSettingsSection(title: "Exercise database", detail: "Syncs exercise pages, guides, covers and their referenced media. Profile, workouts, history, routes, music, secrets and ZIP backups stay out of cloud sync.") {
                Toggle("Sync exercise database", isOn: syncBinding)
                    .font(TimeMasterFont.rowTitle())
                    .disabled(sync.changingMode || account.busy)
                    .accessibilityIdentifier("database-sync-enabled")
                if sync.changingMode {
                    HStack(spacing: EverSpacing.x2) {
                        TmaxLoadingIndicator()
                        Text("Waiting for in-flight sync to stop…").font(TimeMasterFont.caption())
                    }
                }
                Text(sync.syncEnabled
                     ? "Enabled for this device. Sync runs while the app is active and you are signed in."
                     : "Local only on this device. No database uploads, downloads or polling run while this is off.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }

            EverSettingsSection(title: "Status") {
                SettingsActionRow(title: sync.status.rawValue, symbol: statusSymbol)
                if let date = sync.lastSuccessfulSync {
                    SettingsActionRow(title: "Last successful sync", detail: date.formatted(date: .abbreviated, time: .shortened), symbol: "clock")
                    if sync.hasTransferReport {
                        Text("Last completed transfer: \(sync.uploadedFiles) uploaded · \(sync.downloadedFiles) downloaded")
                            .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                    }
                } else {
                    Text("No successful sync recorded for this account on this device.")
                        .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
                }
                if let error = sync.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(TimeMasterFont.caption()).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("database-sync-error")
                }
                if sync.conflicts > 0 {
                    Text("\(sync.conflicts) conflict\(sync.conflicts == 1 ? "" : "s") preserved during the last sync. Review recoverable copies in Backups/Sync Conflicts; no conflicting local work was silently discarded.")
                        .font(TimeMasterFont.caption()).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    Task { await sync.syncNow() }
                } label: {
                    Label(sync.isSyncing ? "Syncing…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(EverPrimaryButtonStyle())
                .disabled(!sync.canSyncNow || sync.isSyncing)
                .accessibilityIdentifier("database-sync-now")
                Text("Local edits remain usable offline. A failed sync is not a cloud save; it is retried while this device's sync is enabled.")
                    .font(TimeMasterFont.caption()).foregroundStyle(EverColor.textSecondary)
            }

            EverSettingsSection(title: "Account", detail: "Each account has an isolated exercise library. Switching waits for sync to stop, then restores that account's files before syncing.") {
                NavigationLink { CloudAccountSettingsView() } label: {
                    SettingsActionRow(title: account.session == nil ? "Optional: sign in to sync" : "Tmax account", detail: account.email, symbol: "person.crop.circle") {
                        Image(systemName: "chevron.right").foregroundStyle(EverColor.textTertiary)
                    }
                }.buttonStyle(.plain)
            }

            EverSettingsSection(title: "Always available locally", detail: "You can edit the exercise library and import or export ZIP files without an account. Turning sync off does not delete local or cloud files.") {
                NavigationLink { BackupView() } label: {
                    SettingsActionRow(title: "Backup & Transfer", symbol: "archivebox") {
                        Image(systemName: "chevron.right").foregroundStyle(EverColor.textTertiary)
                    }
                }.buttonStyle(.plain)
            }
        }
        .tint(Theme.toolbarOrange)
        .accessibilityIdentifier("database-sync-settings")
    }

    private var statusSymbol: String {
        switch sync.status {
        case .localOnly: return "internaldrive"
        case .signedOut: return "person.crop.circle.badge.questionmark"
        case .waiting: return "clock"
        case .syncing, .switching, .stopping: return "arrow.triangle.2.circlepath"
        case .upToDate: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }
}
