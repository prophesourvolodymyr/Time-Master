import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface RankedEarnedRecordProps extends EmailLinks {
  marketing: MarketingFooter;
  movementLabel: string;
  recordLabel: string;
  newBest: string;
  previousBest: string | null;
  unitLabel: string;
  earnedAtLabel: string;
  resultReference: string;
}

export default function RankedEarnedRecordEmail({ assetBaseURL, actionURL, preview, marketing, movementLabel, recordLabel, newBest, previousBest, unitLabel, earnedAtLabel, resultReference }: RankedEarnedRecordProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Ranked"
      headerDetail="Earned record"
      previewText="A new best in your Ranked record is ready to review."
      icon="award"
      title="A new personal best."
      intro="A new best is confirmed in your finalized Ranked record."
      actionLabel="View earned record"
      note="This record belongs to this movement's Ranked history. Practice is excluded."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16, textAlign: "center" }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/award.png`} width={44} height={44} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 12px" }} />
            <Text style={{ margin: "0 0 12px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{recordLabel}</Text>
            <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 40, lineHeight: "48px", fontVariantNumeric: "tabular-nums", wordBreak: "break-word" }}>{newBest}</Text>
            <Text style={{ margin: "4px 0 0", color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{unitLabel}</Text>
            <Text style={{ margin: "16px 0 0", paddingTop: 12, borderTop: `1px solid ${theme.colors.border}`, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{movementLabel}</Text>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Previous best", value: previousBest === null ? "No earlier record" : `${previousBest} ${unitLabel}` },
        { label: "Earned", value: earnedAtLabel },
        { label: "Match reference", value: resultReference },
      ]} />
    </EmailMessage>
  );
}

RankedEarnedRecordEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  movementLabel: "Forearm plank",
  recordLabel: "Highest movement rating",
  newBest: "1,448",
  previousBest: "1,426",
  unitLabel: "Elo",
  earnedAtLabel: "22 Oct 2026 · 11:40 UTC",
  resultReference: "PREVIEW-MATCH-031",
} satisfies RankedEarnedRecordProps;
