import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface SupportReceivedProps extends EmailLinks {
  caseReference: string;
  receivedAtLabel: string;
  statusLabel: string;
  replyInstructions: string;
  actionLabel: string;
}

export default function SupportReceived({
  assetBaseURL, actionURL, preview, caseReference, receivedAtLabel,
  statusLabel, replyInstructions, actionLabel,
}: SupportReceivedProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Support"
      headerDetail="Request receipt"
      previewText="Your support request has a receipt and reference."
      icon="file-check"
      title="Your request was received."
      intro="Keep the reference below to follow your request."
      actionLabel={actionLabel}
      note={replyInstructions}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, padding: theme.space.inset, marginBottom: theme.space.section }}>
          <Row>
            <Column>
              <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 8px" }}>Support reference</Text>
              <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.display, lineHeight: 1.25, margin: 0, wordBreak: "break-word" }}>{caseReference}</Text>
            </Column>
            <Column width="52" style={{ verticalAlign: "middle", paddingLeft: 12 }}><Img src={`${assets}/file-check.png`} alt="" aria-hidden="true" width={36} height={36} style={{ display: "block" }} /></Column>
          </Row>
          <Section style={{ borderTop: "1px dashed #484038", paddingTop: 8, marginTop: 16 }}>
            <EmailFacts items={[
              { label: "Received", value: receivedAtLabel },
              { label: "Status", value: statusLabel },
            ]} />
          </Section>
        </Section>
      }
    >
      <EmailNotice title="Receipt, not a review">
        This confirms receipt only. It is not a review outcome or a response-time promise.
      </EmailNotice>
    </EmailMessage>
  );
}

SupportReceived.PreviewProps = {
  ...previewLinks,
  caseReference: "PREVIEW-1042",
  receivedAtLabel: "22 Oct 2026 · sample receipt",
  statusLabel: "Received · sample",
  replyInstructions: "Use the request page to add details. Reply availability is shown in the conversation.",
  actionLabel: "View support request",
} satisfies SupportReceivedProps;
