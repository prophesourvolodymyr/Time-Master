import { Img, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface SessionCountMilestoneProps extends EmailLinks {
  marketing: MarketingFooter;
  completedSessionCount: number;
  milestoneLabel: string;
  achievedAtLabel: string;
  latestWorkoutTitle: string;
}

export default function SessionCountMilestone({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  completedSessionCount,
  milestoneLabel,
  achievedAtLabel,
  latestWorkoutTitle,
}: SessionCountMilestoneProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Progress"
      headerDetail="Session milestone"
      previewText="A completed-session milestone is ready to celebrate."
      icon="award"
      title="Every finish adds up."
      intro="An earned milestone, one completed session at a time."
      actionLabel="View milestone"
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          backgroundImage: "linear-gradient(160deg,rgba(255,106,0,0.12),rgba(255,106,0,0))",
          border: "1px solid #484038",
          borderRadius: theme.radius.card,
          marginBottom: theme.space.section,
          padding: "24px 12px",
          textAlign: "center",
        }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/award.png`}
            alt=""
            aria-hidden="true"
            width={28}
            height={28}
            style={{ display: "block", margin: "0 auto 12px" }}
          />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: 64,
            lineHeight: "70px",
            wordBreak: "break-word",
            margin: 0,
          }}>{completedSessionCount}</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.secondary,
            lineHeight: "22px",
            margin: "4px 0 12px",
          }}>completed sessions</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.rowTitle,
            lineHeight: "22px",
            margin: 0,
          }}>{milestoneLabel}</Text>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Latest session", value: latestWorkoutTitle },
        { label: "Milestone reached", value: achievedAtLabel },
      ]} />
    </EmailMessage>
  );
}

SessionCountMilestone.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  completedSessionCount: 25,
  milestoneLabel: "A quarter century of finishes",
  achievedAtLabel: "22 October 2026 · Europe/Kyiv",
  latestWorkoutTitle: "Strength essentials",
} satisfies SessionCountMilestoneProps;
