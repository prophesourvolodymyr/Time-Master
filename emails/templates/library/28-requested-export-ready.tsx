import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailStats, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface RequestedExportReadyProps extends EmailLinks {
  fileName: string;
  formatLabel: string;
  fileSizeLabel: string;
  fileCount: number;
  scopeLabel: string;
  preparedAtLabel: string;
  accessLabel: string;
}

export default function RequestedExportReadyEmail({ assetBaseURL, actionURL, preview, fileName, formatLabel, fileSizeLabel, fileCount, scopeLabel, preparedAtLabel, accessLabel }: RequestedExportReadyProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Requested export"
      previewText="The export copy you requested is ready to access."
      icon="download"
      title="Your export is ready."
      intro="Access the copy you requested. Its included data is listed below."
      actionLabel="Access requested export"
      note={accessLabel}
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16 }}>
            <Row>
              <Column width="40" style={{ verticalAlign: "middle" }}><Img src={`${assetBaseURL.replace(/\/+$/, "")}/database.png`} width={28} height={28} alt="" aria-hidden="true" style={{ display: "block" }} /></Column>
              <Column><Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 16, lineHeight: "23px", wordBreak: "break-word" }}>{formatLabel}</Text></Column>
            </Row>
            <Text style={{ margin: "16px 0", color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{fileName}</Text>
            <EmailStats items={[
              { label: "Files included", value: String(fileCount) },
              { label: "Export size", value: fileSizeLabel },
            ]} />
            <Text style={{ margin: 0, borderTop: `1px dashed ${theme.colors.border}`, paddingTop: 12, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Requested copy · Not continuous backup</Text>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Included data", value: scopeLabel },
        { label: "Prepared", value: preparedAtLabel },
      ]} />
    </EmailMessage>
  );
}

RequestedExportReadyEmail.PreviewProps = {
  ...previewLinks,
  fileName: "sample-exercise-library.zip",
  formatLabel: "ZIP export",
  fileSizeLabel: "18.4 MB",
  fileCount: 24,
  scopeLabel: "Exercise pages, guides, covers and referenced media",
  preparedAtLabel: "22 Oct 2026 · 10:12 UTC",
  accessLabel: "Preview availability: 24 hours after preparation. A local ZIP is not automatically hosted; this preview link opens the local design reference.",
} satisfies RequestedExportReadyProps;
