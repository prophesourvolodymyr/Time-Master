import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PlayerWorkflowLessonProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
}

export default function PlayerWorkflowLesson({ assetBaseURL, actionURL, preview, marketing, subscriptionContext }: PlayerWorkflowLessonProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Short lesson"
      headerDetail="Player workflow"
      previewText="Workout timing and music have separate controls."
      icon="play"
      title="One session. Two controls."
      intro="The workout clock and music playback have separate controls. Choose the one you mean to change."
      actionLabel="Explore the player workflow"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, marginBottom: theme.space.section, padding: theme.space.inset }}>
          <Row>
            <Column width="44" style={{ verticalAlign: "middle" }}><Img src={`${assets}/timer.png`} alt="" aria-hidden="true" width={28} height={28} style={{ display: "block" }} /></Column>
            <Column><Text style={label}>Workout</Text><Text style={detail}>Pause or resume the session.</Text></Column>
            <Column width="32" style={{ verticalAlign: "middle", paddingLeft: 8 }}><Img src={`${assets}/pause.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} /></Column>
          </Row>
          <Section style={{ borderTop: `1px solid ${theme.colors.border}`, marginTop: theme.space.inset, paddingTop: theme.space.inset }}>
            <Row>
              <Column width="44" style={{ verticalAlign: "middle" }}><Img src={`${assets}/music.png`} alt="" aria-hidden="true" width={28} height={28} style={{ display: "block" }} /></Column>
              <Column><Text style={label}>Music</Text><Text style={detail}>Use its separate playback controls.</Text></Column>
              <Column width="32" style={{ verticalAlign: "middle", paddingLeft: 8 }}><Img src={`${assets}/play.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} /></Column>
            </Row>
          </Section>
          <Text style={{ ...detail, margin: "16px 0 0", borderTop: "1px solid #484038", paddingTop: 12 }}>Control guide · not a live player</Text>
        </Section>
      }
    >
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "clipboard-list", label: "Prepare the session", detail: "Review the set order and breaks before starting." },
        { icon: "pause", label: "Pause when you mean to continue", detail: "Use the workout pause control for the session, not the music transport." },
        { icon: "flag", label: "Stop when you mean to finish", detail: "Stop ends the session; it is different from pause." },
      ]} />
    </EmailMessage>
  );
}

PlayerWorkflowLesson.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: short lessons enabled.",
} satisfies PlayerWorkflowLessonProps;

const label: CSSProperties = { color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.rowTitle, lineHeight: 1.4, margin: 0 };
const detail: CSSProperties = { color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "4px 0 0" };
