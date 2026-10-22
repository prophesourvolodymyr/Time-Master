import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface RequestedGuideReadyProps extends EmailLinks {
  guideTitle: string;
  fileName: string;
  formatLabel: string;
  fileSizeLabel: string;
  sectionCount: number;
  preparedAtLabel: string;
  accessLabel: string;
}

export default function RequestedGuideReadyEmail({ assetBaseURL, actionURL, preview, guideTitle, fileName, formatLabel, fileSizeLabel, sectionCount, preparedAtLabel, accessLabel }: RequestedGuideReadyProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Requested guide"
      previewText="The guide copy you requested is ready to open."
      icon="book-open"
      title="Your guide is ready."
      intro="Open the guide copy you requested using the link below."
      actionLabel="Open requested guide"
      note={accessLabel}
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16 }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/book-open.png`} width={36} height={36} alt="" aria-hidden="true" style={{ display: "block", marginBottom: 16 }} />
            <Text style={{ margin: "0 0 8px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 22, lineHeight: "28px", wordBreak: "break-word" }}>{guideTitle}</Text>
            <Text style={{ margin: "0 0 16px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{fileName}</Text>
            <Row style={{ borderTop: `1px solid ${theme.colors.border}` }}>
              <Column style={{ paddingTop: 12, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 14, lineHeight: "21px", wordBreak: "break-word" }}>{formatLabel}</Column>
              <Column style={{ paddingTop: 12, textAlign: "right", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{fileSizeLabel}</Column>
            </Row>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Guide sections", value: String(sectionCount) },
        { label: "Prepared", value: preparedAtLabel },
      ]} />
    </EmailMessage>
  );
}

RequestedGuideReadyEmail.PreviewProps = {
  ...previewLinks,
  guideTitle: "A guide to tempo push-ups",
  fileName: "sample-tempo-push-ups.pdf",
  formatLabel: "PDF guide",
  fileSizeLabel: "1.2 MB",
  sectionCount: 4,
  preparedAtLabel: "22 Oct 2026 · 10:05 UTC",
  accessLabel: "Preview availability: 24 hours after preparation. The preview action opens the local design reference.",
} satisfies RequestedGuideReadyProps;
