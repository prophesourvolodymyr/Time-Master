import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, EmailStats, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

type FinalRating =
  | { kind: "rated"; before: number; after: number }
  | { kind: "unchanged"; reason: string };

interface FinalRankedResultProps extends EmailLinks {
  movementLabel: string;
  outcomeLabel: string;
  resultDetail: string;
  resultReference: string;
  finalizedAtLabel: string;
  scores: { yourValue: string; opponentValue: string; unitLabel: string } | null;
  rating: FinalRating;
}

export default function FinalRankedResultEmail({ assetBaseURL, actionURL, preview, movementLabel, outcomeLabel, resultDetail, resultReference, finalizedAtLabel, scores, rating }: FinalRankedResultProps) {
  const ratingChange = rating.kind === "rated" ? rating.after - rating.before : null;
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Ranked"
      headerDetail="Final result"
      previewText="A finalized match result is ready to review."
      icon="flag"
      title="Your result is ready."
      intro="The match service has finalized your result. Open the saved match for its full details."
      actionLabel="Open final result"
      note="Elo belongs to this movement only. Practice does not earn Elo."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16, textAlign: "center" }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/flag.png`} width={32} height={32} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 12px" }} />
            <Text style={{ margin: "0 0 6px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 28, lineHeight: "35px", wordBreak: "break-word" }}>{outcomeLabel}</Text>
            <Text style={{ margin: "0 0 12px", color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{movementLabel}</Text>
            {scores ? <EmailStats items={[
              { label: "Your score", value: scores.yourValue, unit: scores.unitLabel },
              { label: "Opponent score", value: scores.opponentValue, unit: scores.unitLabel },
            ]} /> : null}
            <Section style={{ borderTop: `1px dashed ${theme.colors.border}`, paddingTop: 12 }}>
              {rating.kind === "rated" ? <>
                <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 28, lineHeight: "35px", fontVariantNumeric: "tabular-nums" }}>{rating.after} Elo</Text>
                <Text style={{ margin: "4px 0 0", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>{ratingChange !== null && ratingChange > 0 ? "+" : ""}{ratingChange} Elo · from {rating.before}</Text>
              </> : <>
                <Text style={{ margin: "0 0 4px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 17, lineHeight: "23px" }}>No Elo change</Text>
                <Text style={{ margin: 0, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>{rating.reason}</Text>
              </>}
            </Section>
          </Column></Row>
        </Section>
      }
    >
      <EmailNotice title="Result detail">{resultDetail}</EmailNotice>
      <EmailFacts items={[
        { label: "Finalized", value: finalizedAtLabel },
        { label: "Match reference", value: resultReference },
      ]} />
    </EmailMessage>
  );
}

FinalRankedResultEmail.PreviewProps = {
  ...previewLinks,
  movementLabel: "Standard push-ups",
  outcomeLabel: "You won",
  resultDetail: "The final scores and rating change were accepted by the match service.",
  resultReference: "PREVIEW-MATCH-029",
  finalizedAtLabel: "22 Oct 2026 · 10:30 UTC",
  scores: { yourValue: "32", opponentValue: "29", unitLabel: "valid reps" },
  rating: { kind: "rated", before: 1024, after: 1048 },
} satisfies FinalRankedResultProps;
