import { Column, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailSymbol, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface PersistentSyncFailureProps extends EmailLinks {
  deviceName: string;
  failureSinceLabel: string;
  lastAttemptLabel: string;
  lastCompletedSyncLabel: string;
  reasonSummary: string;
  localDataStatus: string;
}

export default function PersistentSyncFailureEmail({ assetBaseURL, actionURL, preview, deviceName, failureSinceLabel, lastAttemptLabel, lastCompletedSyncLabel, reasonSummary, localDataStatus }: PersistentSyncFailureProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Sync attention"
      previewText="Library sync still needs your attention."
      icon="cloud-off"
      title="Sync needs attention."
      intro="Recent attempts have not completed. Open Database Sync to review the issue."
      actionLabel="Review sync issue"
      note={localDataStatus}
      visual={
        <Section style={{ marginBottom: 24 }}>
          <EmailSymbol assetBaseURL={assetBaseURL} name="cloud-off" />
          <Section style={{ backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card }}>
            <Row><Column style={{ padding: 16 }}>
              <Text style={{ margin: "0 0 8px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 17, lineHeight: "23px" }}>Not completed</Text>
              <Text style={{ margin: 0, color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{reasonSummary}</Text>
            </Column></Row>
          </Section>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Device", value: deviceName },
        { label: "Issue since", value: failureSinceLabel },
        { label: "Last attempt", value: lastAttemptLabel },
        { label: "Last completed", value: lastCompletedSyncLabel },
      ]} />
    </EmailMessage>
  );
}

PersistentSyncFailureEmail.PreviewProps = {
  ...previewLinks,
  deviceName: "Preview Mac",
  failureSinceLabel: "21 Oct 2026 · 16:10 UTC",
  lastAttemptLabel: "22 Oct 2026 · 09:40 UTC",
  lastCompletedSyncLabel: "21 Oct 2026 · 08:12 UTC",
  reasonSummary: "The sync service could not be reached after repeated attempts.",
  localDataStatus: "Edits remain on this Mac. Other devices may not have these changes yet.",
} satisfies PersistentSyncFailureProps;
