import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface ZipBackupReminderProps extends EmailLinks {
  marketing: MarketingFooter;
  deviceName: string;
  lastExportLabel: string;
  exportScopeLabel: string;
}

export default function ZipBackupReminderEmail({ assetBaseURL, actionURL, preview, marketing, deviceName, lastExportLabel, exportScopeLabel }: ZipBackupReminderProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Library"
      headerDetail="Optional reminder"
      previewText="A reminder to make a separate local ZIP copy, if you want one."
      icon="archive"
      title="Keep a separate copy."
      intro="Create a local ZIP in Backup & Transfer. You choose what to include and where to save it."
      actionLabel="Open Backup & Transfer"
      note="This reminder has no download attached. A local ZIP is not a hosted backup, and library sync is not complete app backup."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16, textAlign: "center" }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/archive.png`} width={40} height={40} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 12px" }} />
            <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 32, lineHeight: "39px" }}>ZIP</Text>
            <Text style={{ margin: "4px 0 0", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>A separate local snapshot</Text>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Device", value: deviceName },
        { label: "Last export", value: lastExportLabel },
        { label: "Export scope", value: exportScopeLabel },
      ]} />
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "clipboard-list", label: "Choose the data", detail: "Review the export selection in the app." },
        { icon: "folder", label: "Save your ZIP", detail: "Choose a location you can access later." },
      ]} />
    </EmailMessage>
  );
}

ZipBackupReminderEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  deviceName: "Preview Mac",
  lastExportLabel: "15 Oct 2026 · 17:20 UTC",
  exportScopeLabel: "Selected exercise-library files and media",
} satisfies ZipBackupReminderProps;
