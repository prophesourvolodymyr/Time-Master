import { Img, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface PersonalBestProps extends EmailLinks {
  marketing: MarketingFooter;
  exerciseTitle: string;
  recordLabel: string;
  recordValue: string;
  recordUnitLabel: string;
  previousRecordValueLabel: string;
  recordContextLabel: string;
  achievedAtLabel: string;
}

export default function PersonalBest({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  exerciseTitle,
  recordLabel,
  recordValue,
  recordUnitLabel,
  previousRecordValueLabel,
  recordContextLabel,
  achievedAtLabel,
}: PersonalBestProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Progress"
      headerDetail="Personal best"
      previewText="A new personal training record is ready to review."
      icon="trophy"
      title="Your new personal best."
      intro="Measured against your own previous record."
      actionLabel="View personal best"
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          border: `1px solid ${theme.colors.border}`,
          borderRadius: theme.radius.card,
          marginBottom: theme.space.section,
          padding: "24px 12px",
          textAlign: "center",
        }}>
          <Img
            src={`${assetBaseURL.replace(/\/+$/, "")}/trophy.png`}
            alt=""
            aria-hidden="true"
            width={28}
            height={28}
            style={{ display: "block", margin: "0 auto 12px" }}
          />
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            margin: "0 0 8px",
          }}>{recordLabel}</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: 56,
            lineHeight: "64px",
            wordBreak: "break-word",
            margin: 0,
          }}>{recordValue}</Text>
          <Text style={{
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.accent,
            fontSize: theme.fontSize.rowTitle,
            lineHeight: "22px",
            margin: "4px 0 0",
          }}>{recordUnitLabel}</Text>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Exercise", value: exerciseTitle },
        { label: "Previous best", value: previousRecordValueLabel },
        { label: "Record context", value: recordContextLabel },
        { label: "Recorded", value: achievedAtLabel },
      ]} />
    </EmailMessage>
  );
}

PersonalBest.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  exerciseTitle: "Push-ups",
  recordLabel: "Most repetitions in one set",
  recordValue: "24",
  recordUnitLabel: "repetitions",
  previousRecordValueLabel: "22 repetitions",
  recordContextLabel: "Bodyweight · one completed set",
  achievedAtLabel: "22 October 2026 · 18:42 · Europe/Kyiv",
} satisfies PersonalBestProps;
