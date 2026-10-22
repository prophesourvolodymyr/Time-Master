import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailStats, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface FirstWorkoutProps extends EmailLinks {
  marketing: MarketingFooter;
  workoutName: string;
  workLabel: string;
  restLabel: string;
}

const steps = [
  { icon: "book-open", label: "Choose a page", detail: "Add an exercise, skill or tutorial to the routine." },
  { icon: "timer", label: "Set the rhythm", detail: "Review work duration, rest and preparation time." },
  { icon: "play", label: "Start deliberately", detail: "Choose your warm-up before timed work begins." },
] as const;

export default function FirstWorkoutEmail({ marketing, workoutName, workLabel, restLabel, ...links }: FirstWorkoutProps) {
  const assets = links.assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="First workout"
      previewText="Build a readable plan, then let the player handle its timing."
      icon="clipboard-list"
      title="Make the first plan simple."
      intro="Build the plan first. Let the player handle its timing."
      actionLabel="Read the workout guide"
      visual={
        <Section style={plan}>
          <Row>
            <Column width="44" style={{ verticalAlign: "top", paddingRight: 12 }}>
              <Img src={`${assets}/clipboard-list.png`} width={32} height={32} alt="" aria-hidden="true" style={{ display: "block" }} />
            </Column>
            <Column>
              <Text style={caption}>Plan layout</Text>
              <Text style={name}>{workoutName}</Text>
            </Column>
          </Row>
          <EmailStats items={[
            { label: "Work", value: workLabel },
            { label: "Rest", value: restLabel },
          ]} />
        </Section>
      }
    >
      <EmailSteps assetBaseURL={links.assetBaseURL} items={steps} />
    </EmailMessage>
  );
}

FirstWorkoutEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  workoutName: "A small first routine",
  workLabel: "30 sec",
  restLabel: "20 sec",
} satisfies FirstWorkoutProps;

const plan: CSSProperties = {
  marginBottom: theme.space.section,
  padding: theme.space.inset,
  backgroundColor: theme.colors.raisedSurface,
  border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const caption: CSSProperties = {
  margin: "0 0 4px", color: theme.colors.secondaryText,
  fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: "18px",
};
const name: CSSProperties = {
  margin: "0 0 12px", color: theme.colors.text,
  fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black,
  fontSize: theme.fontSize.sectionTitle, lineHeight: "23px", wordBreak: "break-word",
};
