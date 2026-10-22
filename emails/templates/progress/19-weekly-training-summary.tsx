import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailProgress,
  EmailStats,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface WeeklyTrainingSummaryProps extends EmailLinks {
  marketing: MarketingFooter;
  periodLabel: string;
  completedSessionCount: number;
  trainingMinutes: number;
  trainingDayCount: number;
  goalLabel: string;
  goalValueLabel: string;
  goalFraction: number;
  highlightTitle: string;
  highlightDetail: string;
}

export default function WeeklyTrainingSummary({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  periodLabel,
  completedSessionCount,
  trainingMinutes,
  trainingDayCount,
  goalLabel,
  goalValueLabel,
  goalFraction,
  highlightTitle,
  highlightDetail,
}: WeeklyTrainingSummaryProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Training review"
      headerDetail="Weekly summary"
      previewText="A concise look at your completed training for the week."
      icon="chart-no-axes-combined"
      title="Your week, in focus."
      intro="Finished sessions. Time you made for them."
      actionLabel="Open weekly review"
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          border: `1px solid ${theme.colors.border}`,
          borderRadius: theme.radius.card,
          padding: "16px 8px 0",
          marginBottom: theme.space.section,
        }}>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            textAlign: "center",
            margin: "0 0 8px",
          }}>{periodLabel}</Text>
          <EmailStats items={[
            { label: "Completed sessions", value: String(completedSessionCount) },
            { label: "Training time", value: String(trainingMinutes), unit: "minutes" },
          ]} />
        </Section>
      }
    >
      <EmailProgress label={goalLabel} value={goalValueLabel} fraction={goalFraction} />
      <EmailFacts items={[{ label: "Training days", value: String(trainingDayCount) }]} />
      <EmailNotice title={highlightTitle}>{highlightDetail}</EmailNotice>
    </EmailMessage>
  );
}

WeeklyTrainingSummary.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  periodLabel: "19–25 October 2026 · Europe/Kyiv",
  completedSessionCount: 3,
  trainingMinutes: 92,
  trainingDayCount: 3,
  goalLabel: "Weekly session goal",
  goalValueLabel: "3 of 4 sessions",
  goalFraction: 0.75,
  highlightTitle: "A balanced mix",
  highlightDetail: "Strength and mobility both had a place in this week's completed sessions.",
} satisfies WeeklyTrainingSummaryProps;
