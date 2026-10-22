import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface FeedbackRequestProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
  contextLabel: string;
  question: string;
  feedbackGuidance: string;
}

export default function FeedbackRequest({
  assetBaseURL, actionURL, preview, marketing, subscriptionContext,
  contextLabel, question, feedbackGuidance,
}: FeedbackRequestProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Feedback"
      headerDetail="Optional reply"
      previewText="A short, optional question about your experience with Tmax."
      icon="message-circle"
      title="What would you change?"
      intro="Share what worked or what got in your way. A reply is entirely optional."
      actionLabel="Share feedback"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, padding: theme.space.inset, marginBottom: theme.space.section }}>
          <Row>
            <Column width="40" style={{ verticalAlign: "middle" }}><Img src={`${assets}/message-circle.png`} alt="" aria-hidden="true" width={28} height={28} style={{ display: "block" }} /></Column>
            <Column><Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: 0 }}>One question</Text></Column>
          </Row>
          <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontStyle: "italic", fontSize: theme.fontSize.title, lineHeight: 1.4, margin: "16px 0 0", wordBreak: "break-word" }}>{question}</Text>
        </Section>
      }
    >
      <EmailFacts items={[{ label: "Topic", value: contextLabel }]} />
      <EmailNotice title="A little context helps">{feedbackGuidance}</EmailNotice>
      <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 24px" }}>
        Please leave passwords, private photos and health details out of your feedback.
      </Text>
    </EmailMessage>
  );
}

FeedbackRequest.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: product feedback requests enabled.",
  contextLabel: "Workout setup",
  question: "Where does setting up a workout feel slow?",
  feedbackGuidance: "Tell us what you expected, what happened, and one change you would make.",
} satisfies FeedbackRequestProps;
