import type { CSSProperties } from "react";
import { Section, Text } from "react-email";
import { EmailFeatures, EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PlayerTimerControlsProps extends EmailLinks {
  marketing: MarketingFooter;
  remainingLabel: string;
  phaseLabel: string;
}

const controls = [
  { icon: "pause", label: "Pause", detail: "Hold the timer." },
  { icon: "play", label: "Resume", detail: "Continue the phase." },
] as const;

export default function PlayerTimerControlsEmail({ marketing, remainingLabel, phaseLabel, ...links }: PlayerTimerControlsProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Player guide"
      headerDetail="Timer controls"
      previewText="Know the phase. Pause, resume or stop deliberately."
      icon="timer"
      title="Know the next move."
      intro="Read the current phase before the number. Preparation, work and rest each have their own timing."
      actionLabel="Read the timer guide"
      visual={
        <Section>
          <Section style={clock}>
            <Text style={caption}>Player layout</Text>
            <Text style={time}>{remainingLabel}</Text>
            <Text style={phase}>{phaseLabel}</Text>
          </Section>
          <EmailFeatures assetBaseURL={links.assetBaseURL} items={controls} />
        </Section>
      }
    >
      <EmailNotice title="Stop is different from Pause">
        Stop ends the session after confirmation. Pause holds your place so you can continue.
      </EmailNotice>
    </EmailMessage>
  );
}

PlayerTimerControlsEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  remainingLabel: "00:30",
  phaseLabel: "Work",
} satisfies PlayerTimerControlsProps;

const clock: CSSProperties = {
  marginBottom: theme.space.section, padding: "20px 12px",
  textAlign: "center", backgroundColor: theme.colors.raisedSurface,
  border: "1px solid #484038", borderRadius: theme.radius.card,
};
const caption: CSSProperties = {
  margin: 0, color: theme.colors.secondaryText, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px",
};
const time: CSSProperties = {
  margin: "8px 0", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: 48, lineHeight: "58px", wordBreak: "break-word",
};
const phase: CSSProperties = {
  margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: "21px",
};
