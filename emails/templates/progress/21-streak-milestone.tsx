import { Img, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface StreakMilestoneProps extends EmailLinks {
  marketing: MarketingFooter;
  streakValue: number;
  streakUnitLabel: string;
  milestoneLabel: string;
  earnedAtLabel: string;
  streakRuleLabel: string;
  restDayRuleLabel: string;
  vacationRuleLabel: string;
}

export default function StreakMilestone({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  streakValue,
  streakUnitLabel,
  milestoneLabel,
  earnedAtLabel,
  streakRuleLabel,
  restDayRuleLabel,
  vacationRuleLabel,
}: StreakMilestoneProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Progress"
      headerDetail="Streak milestone"
      previewText="Your training streak has reached an earned milestone."
      icon="flame"
      title="A milestone in your rhythm."
      intro="A moment to appreciate the sessions behind the number."
      actionLabel="View your streak"
      visual={
        <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/flame.png`}
            alt=""
            aria-hidden="true"
            width={36}
            height={36}
            style={{ display: "block", margin: "0 auto 12px" }}
          />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: 64,
            lineHeight: "72px",
            wordBreak: "break-word",
            margin: 0,
          }}>{streakValue}</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.secondary,
            lineHeight: "22px",
            margin: "4px 0 12px",
          }}>{streakUnitLabel}</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: theme.fontSize.rowTitle,
            lineHeight: "22px",
            margin: 0,
          }}>{milestoneLabel}</Text>
        </Section>
      }
    >
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "dumbbell", label: "Training", detail: streakRuleLabel },
        { icon: "pause", label: "Rest days", detail: restDayRuleLabel },
        { icon: "calendar", label: "Vacation", detail: vacationRuleLabel },
      ]} />
      <EmailFacts items={[{ label: "Milestone earned", value: earnedAtLabel }]} />
    </EmailMessage>
  );
}

StreakMilestone.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  streakValue: 7,
  streakUnitLabel: "scheduled training days",
  milestoneLabel: "A week of following through",
  earnedAtLabel: "22 October 2026 · Europe/Kyiv",
  streakRuleLabel: "Completed scheduled training days count toward this streak.",
  restDayRuleLabel: "Planned rest preserves the streak without adding a training day.",
  vacationRuleLabel: "Vacation pauses the count; it does not add completed training.",
} satisfies StreakMilestoneProps;
