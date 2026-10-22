import { Img, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailProgress,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface GoalReachedProps extends EmailLinks {
  marketing: MarketingFooter;
  goalTitle: string;
  currentValueLabel: string;
  targetValueLabel: string;
  goalFraction: number;
  periodLabel: string;
  reachedAtLabel: string;
}

export default function GoalReached({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  goalTitle,
  currentValueLabel,
  targetValueLabel,
  goalFraction,
  periodLabel,
  reachedAtLabel,
}: GoalReachedProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Progress"
      headerDetail="Goal reached"
      previewText="A training goal you set has been reached."
      icon="flag"
      title="That goal is yours."
      intro="You set the target. Your completed training met it."
      actionLabel="View your goal"
      visual={
        <Section style={{
          border: "1px solid #484038",
          backgroundColor: theme.colors.raisedSurface,
          backgroundImage: "linear-gradient(145deg,rgba(255,106,0,0.14),rgba(255,106,0,0))",
          borderRadius: theme.radius.card,
          padding: "24px 16px",
          marginBottom: theme.space.section,
          textAlign: "center",
        }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/flag.png`}
            alt=""
            aria-hidden="true"
            width={36}
            height={36}
            style={{ display: "block", margin: "0 auto 16px" }}
          />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            margin: "0 0 8px",
          }}>Goal reached</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: theme.fontSize.heading,
            lineHeight: "28px",
            wordBreak: "break-word",
            margin: 0,
          }}>{goalTitle}</Text>
        </Section>
      }
    >
      <EmailProgress
        label="Your target"
        value={`${currentValueLabel} / ${targetValueLabel}`}
        fraction={goalFraction}
      />
      <EmailFacts items={[
        { label: "Goal period", value: periodLabel },
        { label: "Reached", value: reachedAtLabel },
      ]} />
    </EmailMessage>
  );
}

GoalReached.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  goalTitle: "Make room for twelve sessions",
  currentValueLabel: "12 sessions",
  targetValueLabel: "12 sessions",
  goalFraction: 1,
  periodLabel: "October 2026 · Europe/Kyiv",
  reachedAtLabel: "22 October 2026 · 18:42 · Europe/Kyiv",
} satisfies GoalReachedProps;
