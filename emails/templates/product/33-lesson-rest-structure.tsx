import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface RestStructureLessonProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
}

export default function RestStructureLesson({ assetBaseURL, actionURL, preview, marketing, subscriptionContext }: RestStructureLessonProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Short lesson"
      headerDetail="Rest structure"
      previewText="Give set rest and section rest their own place."
      icon="pause"
      title="Build the breaks in."
      intro="Rest between sets and rest between sections do different jobs. Set them separately when you plan a workout."
      actionLabel="Explore rest structure"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, marginBottom: theme.space.section, padding: theme.space.inset }}>
          <Text style={{ ...caption, margin: "0 0 16px" }}>Inside a section</Text>
          <Row style={{ tableLayout: "fixed" }}>
            <Column width="33%" style={stage}>
              <Img src={`${assets}/dumbbell.png`} alt="" aria-hidden="true" width={28} height={28} style={symbol} />
              <Text style={stageLabel}>Set</Text>
            </Column>
            <Column width="34%" style={{ ...stage, borderLeft: `1px solid ${theme.colors.border}`, borderRight: `1px solid ${theme.colors.border}` }}>
              <Img src={`${assets}/pause.png`} alt="" aria-hidden="true" width={28} height={28} style={symbol} />
              <Text style={stageLabel}>Set rest</Text>
            </Column>
            <Column width="33%" style={stage}>
              <Img src={`${assets}/dumbbell.png`} alt="" aria-hidden="true" width={28} height={28} style={symbol} />
              <Text style={stageLabel}>Next set</Text>
            </Column>
          </Row>
          <Section style={{ borderTop: "1px solid #484038", marginTop: theme.space.inset, paddingTop: theme.space.inset }}>
            <Row>
              <Column width="36" style={{ verticalAlign: "middle" }}>
                <Img src={`${assets}/layers.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} />
              </Column>
              <Column><Text style={{ ...stageLabel, margin: 0, textAlign: "left" }}>Section rest</Text><Text style={{ ...caption, margin: "3px 0 0" }}>A separate break before the next section.</Text></Column>
            </Row>
          </Section>
        </Section>
      }
    >
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "timer", label: "Set the small gaps", detail: "Adjust the rest after each set to shape its transition." },
        { icon: "layers", label: "Plan the bigger change", detail: "Use section rest for the break between sections, rather than stretching every set rest." },
      ]} />
    </EmailMessage>
  );
}

RestStructureLesson.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: short lessons enabled.",
} satisfies RestStructureLessonProps;

const caption: CSSProperties = { color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: 0 };
const stage: CSSProperties = { padding: "4px 5px", verticalAlign: "top", textAlign: "center", wordBreak: "break-word" };
const symbol: CSSProperties = { display: "block", margin: "0 auto" };
const stageLabel: CSSProperties = { color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: 1.5, margin: "10px 0 0", textAlign: "center" };
