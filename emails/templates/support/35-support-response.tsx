import type { CSSProperties } from "react";
import { Column, Heading, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailSteps, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface SupportResponseProps extends EmailLinks {
  caseReference: string;
  statusLabel: string;
  responseAuthorLabel: string;
  respondedAtLabel: string;
  responseTitle: string;
  responseParagraphs: readonly string[];
  nextSteps: readonly { icon: string; label: string; detail: string }[];
  replyInstructions: string;
  actionLabel: string;
}

export default function SupportResponse({
  assetBaseURL, actionURL, preview, caseReference, statusLabel, responseAuthorLabel,
  respondedAtLabel, responseTitle, responseParagraphs, nextSteps, replyInstructions, actionLabel,
}: SupportResponseProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Support"
      headerDetail="Conversation update"
      previewText="There is a response in your support conversation."
      icon="message-circle"
      title="A response to your request."
      intro="The reply and next steps are below."
      actionLabel={actionLabel}
      note={replyInstructions}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, marginBottom: theme.space.section, padding: theme.space.inset }}>
          <Row>
            <Column width="44" style={{ verticalAlign: "middle" }}><Img src={`${assets}/message-circle.png`} alt="" aria-hidden="true" width={28} height={28} style={{ display: "block" }} /></Column>
            <Column><Text style={{ ...caption, margin: "0 0 3px" }}>Support conversation</Text><Text style={{ ...strong, margin: 0, wordBreak: "break-word" }}>{caseReference}</Text></Column>
          </Row>
        </Section>
      }
    >
      <Section style={{ backgroundColor: theme.colors.raisedSurface, borderLeft: "2px solid #FF6A00", borderRadius: "0 20px 20px 0", padding: theme.space.inset, marginBottom: theme.space.section }}>
        <Text style={{ ...strong, margin: 0 }}>{responseAuthorLabel}</Text>
        <Text style={{ ...caption, margin: "3px 0 16px" }}>{respondedAtLabel}</Text>
        <Heading as="h2" style={{ ...strong, fontSize: theme.fontSize.sectionTitle, lineHeight: 1.4, margin: "0 0 10px" }}>{responseTitle}</Heading>
        {responseParagraphs.map((paragraph, index) => <Text key={index} style={{ color: theme.colors.text, fontFamily: theme.fontFamily, fontWeight: theme.fontWeight.regular, fontSize: theme.fontSize.secondary, lineHeight: 1.5, margin: "0 0 10px", wordBreak: "break-word" }}>{paragraph}</Text>)}
      </Section>
      <EmailSteps assetBaseURL={assetBaseURL} items={nextSteps} />
      <EmailFacts items={[{ label: "Case status", value: statusLabel }]} />
    </EmailMessage>
  );
}

SupportResponse.PreviewProps = {
  ...previewLinks,
  caseReference: "PREVIEW-1042",
  statusLabel: "Awaiting your reply · sample",
  responseAuthorLabel: "Tmax support · sample reply",
  respondedAtLabel: "22 Oct 2026 · sample time",
  responseTitle: "The two rest controls are separate.",
  responseParagraphs: [
    "The break between sections is separate from the rest after a set. Changing one does not replace the other.",
  ],
  nextSteps: [
    { icon: "timer", label: "Review set rest", detail: "Check the rest-after duration for the set you want to change." },
    { icon: "layers", label: "Review section rest", detail: "Check the break between sections before replaying the session." },
  ],
  replyInstructions: "Use the support conversation to reply with what you see.",
  actionLabel: "Open support conversation",
} satisfies SupportResponseProps;

const caption: CSSProperties = { color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5 };
const strong: CSSProperties = { color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: 1.5 };
