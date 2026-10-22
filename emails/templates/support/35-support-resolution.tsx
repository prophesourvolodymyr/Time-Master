import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface SupportResolutionProps extends EmailLinks {
  caseReference: string;
  statusLabel: string;
  resolvedAtLabel: string;
  resolutionSummary: string;
  resolutionDetail: string;
  replyInstructions: string;
  actionLabel: string;
}

export default function SupportResolution({
  assetBaseURL, actionURL, preview, caseReference, statusLabel, resolvedAtLabel,
  resolutionSummary, resolutionDetail, replyInstructions, actionLabel,
}: SupportResolutionProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Support"
      headerDetail="Resolution update"
      previewText="A resolution has been recorded in your support case."
      icon="circle-check"
      title="Resolution recorded."
      intro={resolutionSummary}
      actionLabel={actionLabel}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card, padding: theme.space.inset, marginBottom: theme.space.section, backgroundImage: "linear-gradient(135deg,rgba(255,106,0,0.10),rgba(255,106,0,0))" }}>
          <Row>
            <Column width="60" style={{ verticalAlign: "middle" }}><Img src={`${assets}/circle-check.png`} alt="" aria-hidden="true" width={40} height={40} style={{ display: "block" }} /></Column>
            <Column>
              <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 6px" }}>Case status</Text>
              <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.display, lineHeight: 1.25, margin: 0, wordBreak: "break-word" }}>{statusLabel}</Text>
            </Column>
          </Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Reference", value: caseReference },
        { label: "Updated", value: resolvedAtLabel },
      ]} />
      <EmailNotice title="What changed">{resolutionDetail}</EmailNotice>
      <EmailNotice title="If you still need help">{replyInstructions}</EmailNotice>
    </EmailMessage>
  );
}

SupportResolution.PreviewProps = {
  ...previewLinks,
  caseReference: "PREVIEW-1042",
  statusLabel: "Resolved · sample",
  resolvedAtLabel: "22 Oct 2026 · sample resolution",
  resolutionSummary: "The question about set and section breaks has been answered in your support conversation.",
  resolutionDetail: "The case includes the distinction between set rest and section rest, plus the steps for checking each setting.",
  replyInstructions: "If the behavior still differs from those steps, use the conversation to describe what you see and check the available reply options.",
  actionLabel: "View case resolution",
} satisfies SupportResolutionProps;
