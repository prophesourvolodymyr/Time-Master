import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFeatures, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PlayerMusicProps extends EmailLinks {
  marketing: MarketingFooter;
}

const lanes = [
  { icon: "timer", label: "Workout", detail: "Work and rest timing" },
  { icon: "music", label: "Local audio", detail: "Clips on your music timeline" },
] as const;
const features = [
  { icon: "layers", label: "Arrange", detail: "Place clips in time." },
  { icon: "music", label: "Choose", detail: "Repeat a selection or continue in silence." },
] as const;

export default function PlayerMusicEmail({ marketing, ...links }: PlayerMusicProps) {
  const assets = links.assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Player guide"
      headerDetail="Local music"
      previewText="Arrange your local audio without confusing music controls with the workout timer."
      icon="music"
      title="Give the routine a soundtrack."
      intro="Import audio you may use, then place clips on the workout's music timeline."
      actionLabel="Read the music guide"
      note="Stopping music does not end the workout. This guide covers local audio, not streaming-service availability."
      visual={
        <Section style={timeline}>
          {lanes.map(({ icon, label, detail }) => (
            <Row key={label}>
              <Column width="44" style={{ padding: "14px 12px 14px 0", verticalAlign: "top" }}>
                <Img src={`${assets}/${icon}.png`} width={28} height={28} alt="" aria-hidden="true" style={{ display: "block" }} />
              </Column>
              <Column style={{ padding: "12px 0", borderBottom: `1px solid ${theme.colors.border}` }}>
                <Text style={laneTitle}>{label}</Text>
                <Text style={laneDetail}>{detail}</Text>
              </Column>
            </Row>
          ))}
        </Section>
      }
    >
      <EmailFeatures assetBaseURL={links.assetBaseURL} items={features} />
    </EmailMessage>
  );
}

PlayerMusicEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies PlayerMusicProps;

const timeline: CSSProperties = {
  marginBottom: theme.space.section, padding: "4px 16px",
  backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const laneTitle: CSSProperties = {
  margin: "0 0 3px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: "21px",
};
const laneDetail: CSSProperties = {
  margin: 0, color: theme.colors.secondaryText, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px",
};
