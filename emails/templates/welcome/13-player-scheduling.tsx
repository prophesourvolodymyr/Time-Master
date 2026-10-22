import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface PlayerSchedulingProps extends EmailLinks {
  marketing: MarketingFooter;
  dayLabel: string;
  entries: readonly { timeLabel: string; workoutName: string; cadenceLabel: string }[];
}

const steps = [
  { icon: "calendar", label: "Choose the day", detail: "Place a workout on the day you intend to train." },
  { icon: "refresh-cw", label: "Choose the rhythm", detail: "Keep it on one day or repeat it through your week." },
] as const;

export default function PlayerSchedulingEmail({ marketing, dayLabel, entries, ...links }: PlayerSchedulingProps) {
  const assets = links.assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Player guide"
      headerDetail="Scheduling"
      previewText="Choose a day, a time and a repeat pattern for your plan."
      icon="calendar-check"
      title="Give the plan a place."
      intro="Pick a day and time. Repeat it when the routine belongs in your week."
      actionLabel="Read the schedule guide"
      note="A schedule is a plan, not a completed workout. Reminders use separate device settings."
      visual={
        <Section style={schedule}>
          <Row>
            <Column width="36" style={{ paddingRight: 10 }}>
              <Img src={`${assets}/calendar-check.png`} width={24} height={24} alt="" aria-hidden="true" style={{ display: "block" }} />
            </Column>
            <Column>
              <Text style={small}>Schedule layout</Text>
              <Text style={day}>{dayLabel}</Text>
            </Column>
          </Row>
          {entries.map(({ timeLabel, workoutName, cadenceLabel }, index) => (
            <Row key={`${timeLabel}-${index}`}>
              <Column width="70" style={{ padding: "16px 10px 0 0", verticalAlign: "top" }}>
                <Text style={time}>{timeLabel}</Text>
              </Column>
              <Column style={{ borderLeft: `2px solid ${theme.colors.accent}`, padding: "14px 0 0 12px", verticalAlign: "top" }}>
                <Text style={entryName}>{workoutName}</Text>
                <Text style={small}>{cadenceLabel}</Text>
              </Column>
            </Row>
          ))}
        </Section>
      }
    >
      <EmailSteps assetBaseURL={links.assetBaseURL} items={steps} />
    </EmailMessage>
  );
}

PlayerSchedulingEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  dayLabel: "Monday",
  entries: [
    { timeLabel: "07:30", workoutName: "Morning mobility", cadenceLabel: "Repeats weekly" },
    { timeLabel: "18:00", workoutName: "Strength plan", cadenceLabel: "This day only" },
  ],
} satisfies PlayerSchedulingProps;

const schedule: CSSProperties = {
  marginBottom: theme.space.section, padding: theme.space.inset,
  backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const small: CSSProperties = {
  margin: 0, color: theme.colors.secondaryText, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px", wordBreak: "break-word",
};
const day: CSSProperties = {
  margin: "2px 0 8px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.heading, lineHeight: "26px",
};
const time: CSSProperties = {
  margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: "21px",
  wordBreak: "break-word",
};
const entryName: CSSProperties = { ...time, marginBottom: 3 };
