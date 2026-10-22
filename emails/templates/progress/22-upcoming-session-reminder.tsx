import { Img, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface UpcomingSessionReminderProps extends EmailLinks {
  marketing: MarketingFooter;
  workoutTitle: string;
  reminderLabel: string;
  dateLabel: string;
  timeLabel: string;
  timezoneLabel: string;
  durationLabel: string;
  preparationNote: string;
}

export default function UpcomingSessionReminder({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  workoutTitle,
  reminderLabel,
  dateLabel,
  timeLabel,
  timezoneLabel,
  durationLabel,
  preparationNote,
}: UpcomingSessionReminderProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Your schedule"
      headerDetail="Session reminder"
      previewText="A reminder for a session on your training schedule."
      icon="alarm-clock"
      title="A moment on your calendar."
      intro="Take a look at the plan before your session."
      actionLabel="View session plan"
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          border: "1px solid #484038",
          borderRadius: theme.radius.card,
          padding: "20px 12px",
          textAlign: "center",
          marginBottom: theme.space.section,
        }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/alarm-clock.png`}
            alt=""
            aria-hidden="true"
            width={28}
            height={28}
            style={{ display: "block", margin: "0 auto 12px" }}
          />
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            margin: "0 0 8px",
          }}>{reminderLabel}</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.text,
            fontSize: theme.fontSize.secondary,
            lineHeight: "22px",
            margin: 0,
          }}>{dateLabel}</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: 44,
            lineHeight: "54px",
            wordBreak: "break-word",
            margin: "8px 0 4px",
          }}>{timeLabel}</Text>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            margin: 0,
          }}>{timezoneLabel}</Text>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Session", value: workoutTitle },
        { label: "Planned time", value: durationLabel },
      ]} />
      <EmailNotice title="Before you begin">{preparationNote}</EmailNotice>
    </EmailMessage>
  );
}

UpcomingSessionReminder.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  workoutTitle: "Strength essentials",
  reminderLabel: "Tomorrow",
  dateLabel: "Friday, 23 October 2026",
  timeLabel: "18:30",
  timezoneLabel: "Europe/Kyiv",
  durationLabel: "30 minutes",
  preparationNote: "Review your exercise order and have your usual equipment ready.",
} satisfies UpcomingSessionReminderProps;
