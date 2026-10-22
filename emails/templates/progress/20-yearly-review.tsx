import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailStats,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface YearlyReviewProps extends EmailLinks {
  marketing: MarketingFooter;
  yearLabel: string;
  completedSessionCount: number;
  trainingMinutes: number;
  activeMonthCount: number;
  mostCompletedWorkoutTitle: string;
  highlightTitle: string;
  highlightDetail: string;
}

export default function YearlyReview({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  yearLabel,
  completedSessionCount,
  trainingMinutes,
  activeMonthCount,
  mostCompletedWorkoutTitle,
  highlightTitle,
  highlightDetail,
}: YearlyReviewProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Training review"
      headerDetail="Yearly review"
      previewText="A year of completed training, brought into one view."
      icon="history"
      title="Look at what you finished."
      intro="Not a comparison. A record of your own year."
      actionLabel="Explore your year"
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          backgroundImage: "linear-gradient(180deg,rgba(255,106,0,0.10),rgba(255,106,0,0))",
          borderTop: "2px solid #FF6A00",
          borderRadius: theme.radius.card,
          padding: "20px 12px 24px",
          marginBottom: theme.space.section,
          textAlign: "center",
        }}>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.sectionTitle,
            lineHeight: "24px",
            margin: "0 0 12px",
          }}>{yearLabel}</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: 64,
            lineHeight: "72px",
            wordBreak: "break-word",
            margin: 0,
          }}>{completedSessionCount}</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.secondary,
            lineHeight: "22px",
            margin: "4px 0 0",
          }}>completed sessions</Text>
        </Section>
      }
    >
      <EmailStats items={[
        { label: "Training time", value: String(trainingMinutes), unit: "minutes" },
        { label: "Months with training", value: String(activeMonthCount) },
      ]} />
      <EmailFacts items={[{ label: "Most completed workout", value: mostCompletedWorkoutTitle }]} />
      <EmailNotice title={highlightTitle}>{highlightDetail}</EmailNotice>
    </EmailMessage>
  );
}

YearlyReview.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  yearLabel: "2025 · Europe/Kyiv",
  completedSessionCount: 128,
  trainingMinutes: 3824,
  activeMonthCount: 11,
  mostCompletedWorkoutTitle: "Strength essentials",
  highlightTitle: "Your own rhythm",
  highlightDetail: "A year that made room for strength, mobility, and time away.",
} satisfies YearlyReviewProps;
