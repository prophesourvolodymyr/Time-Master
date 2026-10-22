import { Column, Img, Row, Section, Text } from "react-email";
import {
  EmailMessage,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

type AgendaDate = {
  id: string;
  dayLabel: string;
  dateLabel: string;
};

export type WeeklyAgendaEntry = AgendaDate & (
  | { kind: "session"; workoutTitle: string; timeLabel: string; durationLabel: string }
  | { kind: "rest"; detail: string }
  | { kind: "vacation"; detail: string }
);

export interface WeeklyAgendaProps extends EmailLinks {
  marketing: MarketingFooter;
  periodLabel: string;
  timezoneLabel: string;
  entries: readonly WeeklyAgendaEntry[];
}

export default function WeeklyAgenda({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  periodLabel,
  timezoneLabel,
  entries,
}: WeeklyAgendaProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");

  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Your schedule"
      headerDetail="Weekly agenda"
      previewText="A clear view of your planned training, rest, and time away."
      icon="calendar"
      title="Your week has room."
      intro="Sessions, rest, and time away. All part of the plan."
      actionLabel="Open your schedule"
      visual={
        <Section style={{ marginBottom: theme.space.section }}>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: theme.fontSize.sectionTitle,
            lineHeight: "25px",
            textAlign: "center",
            margin: "0 0 16px",
          }}>{periodLabel}</Text>
          <Section style={{
            backgroundColor: theme.colors.raisedSurface,
            border: `1px solid ${theme.colors.border}`,
            borderRadius: theme.radius.card,
            padding: "4px 12px",
          }}>
            {entries.map((entry) => {
              const icon = entry.kind === "session" ? "dumbbell" : entry.kind === "rest" ? "pause" : "calendar";
              const title = entry.kind === "session" ? entry.workoutTitle : entry.kind === "rest" ? "Rest day" : "Vacation";
              const detail = entry.kind === "session" ? `${entry.timeLabel} · ${entry.durationLabel}` : entry.detail;

              return (
                <Row key={entry.id} style={{ tableLayout: "fixed" }}>
                  <Column width="52" style={{ padding: "14px 0", verticalAlign: "top" }}>
                    <Text style={{
                      fontFamily: theme.headingFontFamily,
                      fontWeight: theme.fontWeight.black,
                      color: entry.kind === "session" ? theme.colors.accent : theme.colors.text,
                      fontSize: theme.fontSize.rowTitle,
                      lineHeight: "21px",
                      margin: 0,
                    }}>{entry.dayLabel}</Text>
                    <Text style={{
                      fontFamily: theme.fontFamily,
                      color: theme.colors.secondaryText,
                      fontSize: theme.fontSize.micro,
                      lineHeight: "18px",
                      margin: "3px 0 0",
                    }}>{entry.dateLabel}</Text>
                  </Column>
                  <Column style={{
                    padding: "14px 0 14px 12px",
                    borderLeft: `1px solid ${theme.colors.border}`,
                    verticalAlign: "top",
                    wordBreak: "break-word",
                  }}>
                    <Img src={`${assets}/${icon}.png`} alt="" aria-hidden="true" width={20} height={20}
                      style={{ display: "block", marginBottom: 6 }} />
                    <Text style={{
                      fontFamily: theme.headingFontFamily,
                      fontWeight: theme.fontWeight.black,
                      color: theme.colors.text,
                      fontSize: theme.fontSize.secondary,
                      lineHeight: "21px",
                      margin: 0,
                    }}>{title}</Text>
                    <Text style={{
                      fontFamily: theme.fontFamily,
                      color: theme.colors.secondaryText,
                      fontSize: theme.fontSize.caption,
                      lineHeight: "19px",
                      margin: "4px 0 0",
                    }}>{detail}</Text>
                  </Column>
                </Row>
              );
            })}
          </Section>
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.micro,
            lineHeight: "18px",
            textAlign: "center",
            margin: "12px 0 0",
          }}>Times shown in {timezoneLabel}</Text>
        </Section>
      }
    />
  );
}

WeeklyAgenda.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  periodLabel: "19–25 October 2026",
  timezoneLabel: "Europe/Kyiv",
  entries: [
    { id: "monday-strength", kind: "session", dayLabel: "Mon", dateLabel: "19 Oct", workoutTitle: "Strength essentials", timeLabel: "18:30", durationLabel: "30 min" },
    { id: "wednesday-mobility", kind: "session", dayLabel: "Wed", dateLabel: "21 Oct", workoutTitle: "Evening mobility", timeLabel: "19:00", durationLabel: "15 min" },
    { id: "friday-rest", kind: "rest", dayLabel: "Fri", dateLabel: "23 Oct", detail: "Planned rest. No session scheduled." },
    { id: "saturday-vacation", kind: "vacation", dayLabel: "Sat", dateLabel: "24 Oct", detail: "Time away. Your training plan is on pause." },
  ],
} satisfies WeeklyAgendaProps;
