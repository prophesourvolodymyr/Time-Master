import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailStats, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface FirstLibrarySyncProps extends EmailLinks {
  report: {
    deviceName: string;
    completedAtLabel: string;
    uploadedFiles: number;
    downloadedFiles: number;
  };
}

export default function FirstLibrarySyncEmail({ assetBaseURL, actionURL, preview, report }: FirstLibrarySyncProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Sync receipt"
      previewText="Your first completed exercise-library sync has a receipt."
      icon="cloud-check"
      title="First sync complete."
      intro="Your exercise-library sync completed on the device below."
      actionLabel="Review library sync"
      note="Exercise-library files and referenced media only. This is not a complete app backup or confirmation of downloads on other devices."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row>
            <Column style={{ padding: 16 }}>
              <Row>
                <Column width="40" style={{ verticalAlign: "middle" }}>
                  <Img src={`${assetBaseURL.replace(/\/+$/, "")}/cloud-check.png`} width={28} height={28} alt="" aria-hidden="true" style={{ display: "block" }} />
                </Column>
                <Column>
                  <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 15, lineHeight: "21px" }}>Completed</Text>
                  <Text style={{ margin: "3px 0 0", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>First sync receipt</Text>
                </Column>
              </Row>
              <EmailStats items={[
                { label: "Files uploaded", value: String(report.uploadedFiles) },
                { label: "Files downloaded", value: String(report.downloadedFiles) },
              ]} />
              <Text style={{ margin: 0, borderTop: `1px dashed ${theme.colors.border}`, paddingTop: 12, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Transfers reported by this device</Text>
            </Column>
          </Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Device", value: report.deviceName },
        { label: "Completed", value: report.completedAtLabel },
      ]} />
    </EmailMessage>
  );
}

FirstLibrarySyncEmail.PreviewProps = {
  ...previewLinks,
  report: {
    deviceName: "Preview Mac",
    completedAtLabel: "22 Oct 2026 · 09:42 UTC",
    uploadedFiles: 18,
    downloadedFiles: 6,
  },
} satisfies FirstLibrarySyncProps;
