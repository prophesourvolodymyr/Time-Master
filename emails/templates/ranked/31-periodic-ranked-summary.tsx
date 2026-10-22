import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailStats, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface RankedPeriodicSummaryProps extends EmailLinks {
  marketing: MarketingFooter;
  periodLabel: string;
  asOfLabel: string;
  ratedMatchCount: number;
  wins: number;
  losses: number;
  draws: number;
  movements: readonly {
    movementLabel: string;
    openingRating: number | null;
    closingRating: number;
    statusLabel: string;
  }[];
}

export default function RankedPeriodicSummaryEmail({ assetBaseURL, actionURL, preview, marketing, periodLabel, asOfLabel, ratedMatchCount, wins, losses, draws, movements }: RankedPeriodicSummaryProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Ranked"
      headerDetail="Periodic recap"
      previewText="Your movement-by-movement Ranked recap is ready."
      icon="chart-no-axes-combined"
      title="Your Ranked recap."
      intro="A movement-by-movement look at your finalized results for this period."
      actionLabel="Review Ranked history"
      note="Includes final rated matches in the stated period. Practice is excluded; ratings are not combined across movements."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16, textAlign: "center" }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/chart-no-axes-combined.png`} width={32} height={32} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 12px" }} />
            <Text style={{ margin: "0 0 12px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{periodLabel}</Text>
            <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 40, lineHeight: "48px", fontVariantNumeric: "tabular-nums" }}>{ratedMatchCount}</Text>
            <Text style={{ margin: "4px 0 0", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Final rated matches</Text>
            <EmailStats items={[
              { label: "Wins", value: String(wins) },
              { label: "Losses", value: String(losses) },
              { label: "Draws", value: String(draws) },
            ]} />
          </Column></Row>
        </Section>
      }
    >
      {movements.map((movement) => {
        const change = movement.openingRating === null ? null : movement.closingRating - movement.openingRating;
        return (
          <Section key={movement.movementLabel} style={{ marginBottom: 12, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: 16 }}>
            <Row><Column style={{ padding: 12 }}>
              <Text style={{ margin: "0 0 4px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 14, lineHeight: "21px", wordBreak: "break-word" }}>{movement.movementLabel}</Text>
              <Text style={{ margin: "0 0 10px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", wordBreak: "break-word" }}>{movement.statusLabel}</Text>
              <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 24, lineHeight: "31px", fontVariantNumeric: "tabular-nums" }}>{movement.closingRating} Elo</Text>
              <Text style={{ margin: "4px 0 0", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", fontVariantNumeric: "tabular-nums" }}>
                {change === null ? "First earned rating this period" : `${change > 0 ? "+" : ""}${change} Elo this period · from ${movement.openingRating}`}
              </Text>
            </Column></Row>
          </Section>
        );
      })}
      <EmailFacts items={[{ label: "As of", value: asOfLabel }]} />
    </EmailMessage>
  );
}

RankedPeriodicSummaryEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  periodLabel: "15–21 Oct 2026 · UTC",
  asOfLabel: "22 Oct 2026 · 00:00 UTC",
  ratedMatchCount: 12,
  wins: 7,
  losses: 4,
  draws: 1,
  movements: [
    { movementLabel: "Standard push-ups", openingRating: 1008, closingRating: 1048, statusLabel: "Silver · Placed" },
    { movementLabel: "Standard squats", openingRating: 1386, closingRating: 1408, statusLabel: "Gold · Placed" },
    { movementLabel: "Forearm plank", openingRating: 1440, closingRating: 1426, statusLabel: "Gold · Placed" },
  ],
} satisfies RankedPeriodicSummaryProps;
