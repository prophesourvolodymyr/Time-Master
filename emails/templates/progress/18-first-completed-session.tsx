import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailStats,
  EmailSymbol,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface FirstCompletedSessionProps extends EmailLinks {
  marketing: MarketingFooter;
  workoutTitle: string;
  completedAtLabel: string;
  durationLabel: string;
  completedExercisesLabel: string;
}

export default function FirstCompletedSession({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  workoutTitle,
  completedAtLabel,
  durationLabel,
  completedExercisesLabel,
}: FirstCompletedSessionProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Progress"
      headerDetail="Session complete"
      previewText="Your first completed session is ready to review."
      icon="circle-check"
      title="First session. Finished."
      intro="A clear starting point. A session you saw through."
      actionLabel="View session"
      visual={
        <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
          <EmailSymbol assetBaseURL={assetBaseURL} name="circle-check" />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.rowTitle,
            lineHeight: "21px",
            margin: "0 0 8px",
          }}>Completed</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.text,
            fontSize: theme.fontSize.secondary,
            lineHeight: "22px",
            wordBreak: "break-word",
            margin: 0,
          }}>{workoutTitle}</Text>
        </Section>
      }
    >
      <EmailStats items={[
        { label: "Session time", value: durationLabel },
        { label: "Exercises finished", value: completedExercisesLabel },
      ]} />
      <EmailFacts items={[{ label: "Completed", value: completedAtLabel }]} />
    </EmailMessage>
  );
}

FirstCompletedSession.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  workoutTitle: "Full-body foundations",
  completedAtLabel: "22 October 2026 · 18:42 · Europe/Kyiv",
  durationLabel: "24 min",
  completedExercisesLabel: "6",
} satisfies FirstCompletedSessionProps;
