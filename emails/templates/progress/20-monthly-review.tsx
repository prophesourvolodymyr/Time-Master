import { Img, Section, Text } from "react-email";
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

export interface MonthlyReviewProps extends EmailLinks {
  marketing: MarketingFooter;
  periodLabel: string;
  completedSessionCount: number;
  trainingMinutes: number;
  trainingDayCount: number;
  mostPracticedType: string;
  goalLabel: string;
  goalValueLabel: string;
  goalFraction: number;
  highlightTitle: string;
  highlightDetail: string;
}

export default function MonthlyReview({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  periodLabel,
  completedSessionCount,
  trainingMinutes,
  trainingDayCount,
  mostPracticedType,
  goalLabel,
  goalValueLabel,
  goalFraction,
  highlightTitle,
  highlightDetail,
}: MonthlyReviewProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Training review"
      headerDetail="Monthly review"
      previewText="Your monthly training review is ready to explore."
      icon="calendar-check"
      title="A month made of moments."
      intro="A little distance makes the whole picture clearer."
      actionLabel="Open monthly review"
      visual={
        <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/calendar-check.png`}
            alt=""
            aria-hidden="true"
            width={32}
            height={32}
            style={{ display: "block", margin: "0 auto 12px" }}
          />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: theme.fontSize.heading,
            lineHeight: "27px",
            margin: "0 0 12px",
          }}>{periodLabel}</Text>
          <EmailStats items={[
            { label: "Completed sessions", value: String(completedSessionCount) },
            { label: "Training days", value: String(trainingDayCount) },
          ]} />
        </Section>
      }
    >
      <EmailProgress label={goalLabel} value={goalValueLabel} fraction={goalFraction} />
      <EmailFacts items={[
        { label: "Training time", value: `${trainingMinutes} minutes` },
        { label: "Most practiced type", value: mostPracticedType },
      ]} />
      <EmailNotice title={highlightTitle}>{highlightDetail}</EmailNotice>
    </EmailMessage>
  );
}

MonthlyReview.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  periodLabel: "September 2026 · Europe/Kyiv",
  completedSessionCount: 12,
  trainingMinutes: 348,
  trainingDayCount: 11,
  mostPracticedType: "Strength",
  goalLabel: "Monthly session goal",
  goalValueLabel: "12 of 16 sessions",
  goalFraction: 0.75,
  highlightTitle: "More room for mobility",
  highlightDetail: "Your completed sessions included four mobility practices this month.",
} satisfies MonthlyReviewProps;
