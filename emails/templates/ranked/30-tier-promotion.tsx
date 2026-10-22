import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface RankedTierPromotionProps extends EmailLinks {
  marketing: MarketingFooter;
  movementLabel: string;
  previousTierLabel: string;
  tierLabel: string;
  beforeRating: number;
  afterRating: number;
  earnedAtLabel: string;
  resultReference: string;
}

export default function RankedTierPromotionEmail({ assetBaseURL, actionURL, preview, marketing, movementLabel, previousTierLabel, tierLabel, beforeRating, afterRating, earnedAtLabel, resultReference }: RankedTierPromotionProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Ranked"
      headerDetail="Tier milestone"
      previewText="A newly earned Ranked tier is ready to review."
      icon="trophy"
      title="A new tier, earned."
      intro="A finalized result moved this movement into a new tier."
      actionLabel="View earned tier"
      note="This is movement-specific Ranked progression. Practice does not earn Elo."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16 }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/trophy.png`} width={40} height={40} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 16px" }} />
            <Row style={{ tableLayout: "fixed" }}>
              <Column width="50%" style={{ verticalAlign: "top", paddingRight: 6, textAlign: "center", wordBreak: "break-word" }}>
                <Text style={{ margin: "0 0 6px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Previous tier</Text>
                <Text style={{ margin: "0 0 8px", color: theme.colors.secondaryText, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 20, lineHeight: "27px" }}>{previousTierLabel}</Text>
                <Text style={{ margin: 0, color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px", fontVariantNumeric: "tabular-nums" }}>{beforeRating} Elo</Text>
              </Column>
              <Column width="50%" style={{ verticalAlign: "top", paddingLeft: 6, textAlign: "center", borderLeft: `1px solid ${theme.colors.border}`, wordBreak: "break-word" }}>
                <Text style={{ margin: "0 0 6px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Earned tier</Text>
                <Text style={{ margin: "0 0 8px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 20, lineHeight: "27px" }}>{tierLabel}</Text>
                <Text style={{ margin: 0, color: theme.colors.text, fontSize: 12, lineHeight: "19px", fontVariantNumeric: "tabular-nums" }}>{afterRating} Elo</Text>
              </Column>
            </Row>
            <Text style={{ margin: "16px 0 0", paddingTop: 12, borderTop: `1px solid ${theme.colors.border}`, color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", textAlign: "center", wordBreak: "break-word" }}>{movementLabel}</Text>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Earned", value: earnedAtLabel },
        { label: "Match reference", value: resultReference },
      ]} />
    </EmailMessage>
  );
}

RankedTierPromotionEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  movementLabel: "Standard squats",
  previousTierLabel: "Silver",
  tierLabel: "Gold",
  beforeRating: 1386,
  afterRating: 1408,
  earnedAtLabel: "22 Oct 2026 · 11:15 UTC",
  resultReference: "PREVIEW-MATCH-030",
} satisfies RankedTierPromotionProps;
