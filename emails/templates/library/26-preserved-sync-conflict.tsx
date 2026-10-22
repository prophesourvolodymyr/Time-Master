import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface PreservedSyncConflictProps extends EmailLinks {
  fileDisplayName: string;
  deviceName: string;
  detectedAtLabel: string;
  preservedCopyDetail: string;
  currentVersionDetail: string;
  recoveryLocationLabel: string;
}

export default function PreservedSyncConflictEmail({ assetBaseURL, actionURL, preview, fileDisplayName, deviceName, detectedAtLabel, preservedCopyDetail, currentVersionDetail, recoveryLocationLabel }: PreservedSyncConflictProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Review needed"
      previewText="A preserved library version is ready for your review."
      icon="layers"
      title="One file. Two versions."
      intro="A local version was preserved during sync. Review the copies before restoring or merging."
      actionLabel="Review preserved copy"
      note="No merge has been assumed. Review the recovery copy in the app before making changes."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16 }}>
            <Row>
              <Column width="36" style={{ verticalAlign: "top" }}><Img src={`${assets}/layers.png`} width={24} height={24} alt="" aria-hidden="true" style={{ display: "block" }} /></Column>
              <Column><Text style={{ margin: "0 0 16px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 16, lineHeight: "23px", wordBreak: "break-word" }}>{fileDisplayName}</Text></Column>
            </Row>
            <Section style={{ border: "1px solid #484038", borderRadius: 12, marginBottom: 12 }}>
              <Row><Column style={{ padding: 12 }}>
                <Text style={{ margin: "0 0 4px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 14, lineHeight: "21px" }}>Preserved local copy</Text>
                <Text style={{ margin: 0, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{preservedCopyDetail}</Text>
              </Column></Row>
            </Section>
            <Section style={{ border: `1px solid ${theme.colors.border}`, borderRadius: 12 }}>
              <Row><Column style={{ padding: 12 }}>
                <Text style={{ margin: "0 0 4px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 14, lineHeight: "21px" }}>Current library version</Text>
                <Text style={{ margin: 0, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{currentVersionDetail}</Text>
              </Column></Row>
            </Section>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Device", value: deviceName },
        { label: "Detected", value: detectedAtLabel },
        { label: "Recovery location", value: recoveryLocationLabel },
      ]} />
    </EmailMessage>
  );
}

PreservedSyncConflictEmail.PreviewProps = {
  ...previewLinks,
  fileDisplayName: "Sample exercise guide",
  deviceName: "Preview Mac",
  detectedAtLabel: "22 Oct 2026 · 09:42 UTC",
  preservedCopyDetail: "Local guide edits saved as a recovery copy at 09:42 UTC.",
  currentVersionDetail: "The synced guide revision currently used by this library.",
  recoveryLocationLabel: "Backups / Sync Conflicts",
} satisfies PreservedSyncConflictProps;
