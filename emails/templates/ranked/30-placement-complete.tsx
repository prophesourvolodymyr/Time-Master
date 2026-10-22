import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface RankedPlacementCompleteProps extends EmailLinks {
  marketing: MarketingFooter;
  movementLabel: string;
  tierLabel: string;
  rating: number;
  placementMatchCount: number;
  completedAtLabel: string;
}

export default function RankedPlacementCompleteEmail({ assetBaseURL, actionURL, preview, marketing, movementLabel, tierLabel, rating, placementMatchCount, completedAtLabel }: RankedPlacementCompleteProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Ranked"
      headerDetail="Placement complete"
      previewText="A movement placement milestone is ready to review."
      icon="shield-check"
      title="Your place, earned."
      intro="Your placement is complete for this movement. Your earned tier and rating are below."
      actionLabel="View movement rank"
      note="A tier is not a public leaderboard position. Practice does not earn Elo."
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16, textAlign: "center" }}>
            <Img src={`${assetBaseURL.replace(/\/+$/, "")}/shield-check.png`} width={48} height={48} alt="" aria-hidden="true" style={{ display: "block", margin: "0 auto 12px" }} />
            <Text style={{ margin: "0 0 6px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Placement complete</Text>
            <Text style={{ margin: "0 0 8px", color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 32, lineHeight: "39px", wordBreak: "break-word" }}>{tierLabel}</Text>
            <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 28, lineHeight: "35px", fontVariantNumeric: "tabular-nums" }}>{rating} Elo</Text>
            <Text style={{ margin: "12px 0 0", paddingTop: 12, borderTop: `1px solid ${theme.colors.border}`, color: theme.colors.secondaryText, fontSize: 14, lineHeight: "22px", wordBreak: "break-word" }}>{movementLabel}</Text>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Placement matches", value: `${placementMatchCount} final rated matches` },
        { label: "Completed", value: completedAtLabel },
      ]} />
    </EmailMessage>
  );
}

RankedPlacementCompleteEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  movementLabel: "Standard push-ups",
  tierLabel: "Silver",
  rating: 1048,
  placementMatchCount: 5,
  completedAtLabel: "22 Oct 2026 · 10:30 UTC",
} satisfies RankedPlacementCompleteProps;
