import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PracticeVersusRankedProps extends EmailLinks {
  marketing: MarketingFooter;
}

const modes = [
  { icon: "user-round", title: "Practice", context: "Solo, on this device", detail: "No Elo. No competitive match slot." },
  { icon: "users", title: "Ranked", context: "Account + available service", detail: "An opponent and a rating for the exact movement." },
] as const;

export default function PracticeVersusRankedEmail({ marketing, ...links }: PracticeVersusRankedProps) {
  const assets = links.assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Movement guide"
      headerDetail="Exercise duels"
      previewText="Practice stays local. Ranked is a separate, service-backed competition."
      icon="users"
      title="Learn first. Compete by choice."
      intro="Calibrate the camera in Practice. Choose Ranked when account access, service availability and movement eligibility allow it."
      actionLabel="Compare the modes"
      note="This guide covers exercise duels, not Physique Duels. Local display levels are not competitive Elo."
      visual={
        <Section style={comparison}>
          {modes.map(({ icon, title, context, detail }) => (
            <Row key={title}>
              <Column width="44" style={{ padding: "16px 12px 16px 0", verticalAlign: "top" }}>
                <Img src={`${assets}/${icon}.png`} width={28} height={28} alt="" aria-hidden="true" style={{ display: "block" }} />
              </Column>
              <Column style={{ padding: "14px 0", borderBottom: `1px solid ${theme.colors.border}` }}>
                <Text style={modeTitle}>{title}</Text>
                <Text style={contextStyle}>{context}</Text>
                <Text style={detailStyle}>{detail}</Text>
              </Column>
            </Row>
          ))}
        </Section>
      }
    >
      <EmailNotice title="Exercise-camera privacy">
        Practice stays local. Exercise duels send timestamped joint estimates for scoring; images and video stay on-device.
      </EmailNotice>
    </EmailMessage>
  );
}

PracticeVersusRankedEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies PracticeVersusRankedProps;

const comparison: CSSProperties = {
  marginBottom: theme.space.section, padding: "2px 16px",
  backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const modeTitle: CSSProperties = {
  margin: "0 0 3px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.sectionTitle, lineHeight: "23px",
};
const contextStyle: CSSProperties = {
  margin: "0 0 5px", color: theme.colors.text, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px",
};
const detailStyle: CSSProperties = { ...contextStyle, margin: 0, color: theme.colors.secondaryText };
