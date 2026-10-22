import type { CSSProperties } from "react";
import { Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PlayerResumeProps extends EmailLinks {
  marketing: MarketingFooter;
  workoutName: string;
  elapsedLabel: string;
  positionLabel: string;
  phaseLabel: string;
}

const choices = [
  { icon: "play", label: "Resume", detail: "Continue the saved session if its workout remains in Library." },
  { icon: "archive", label: "Keep or discard", detail: "Close the sheet to keep the checkpoint. Read the confirmation before discarding it." },
] as const;

export default function PlayerResumeEmail({ marketing, workoutName, elapsedLabel, positionLabel, phaseLabel, ...links }: PlayerResumeProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Player guide"
      headerDetail="Resume options"
      previewText="Review a saved checkpoint before choosing how to continue."
      icon="history"
      title="Pick up deliberately."
      intro="When saved progress is available, review the elapsed time, position and phase before continuing."
      actionLabel="Review resume options"
      note="Discard can keep qualifying sessions as partial history. The confirmation explains the outcome. Resume checkpoints stay on this device."
      visual={
        <Section style={checkpoint}>
          <Text style={caption}>Resume layout</Text>
          <Text style={name}>{workoutName}</Text>
          <Text style={elapsed}>{elapsedLabel}</Text>
          <Text style={caption}>Elapsed at checkpoint</Text>
          <EmailFacts items={[
            { label: "Position", value: positionLabel },
            { label: "Phase", value: phaseLabel },
          ]} />
        </Section>
      }
    >
      <EmailSteps assetBaseURL={links.assetBaseURL} items={choices} />
    </EmailMessage>
  );
}

PlayerResumeEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  workoutName: "Evening routine",
  elapsedLabel: "08:20",
  positionLabel: "Section 2 · Set 1",
  phaseLabel: "Rest between sets",
} satisfies PlayerResumeProps;

const checkpoint: CSSProperties = {
  marginBottom: theme.space.section, padding: theme.space.inset,
  backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const caption: CSSProperties = {
  margin: 0, color: theme.colors.secondaryText, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px",
};
const name: CSSProperties = {
  margin: "5px 0 12px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.sectionTitle,
  lineHeight: "23px", wordBreak: "break-word",
};
const elapsed: CSSProperties = {
  margin: "0 0 4px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: 36, lineHeight: "44px", wordBreak: "break-word",
};
