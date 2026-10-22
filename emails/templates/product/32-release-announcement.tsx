import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailFeatures, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface ReleaseAnnouncementProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
  versionLabel: string;
  releaseDateLabel: string;
  headline: string;
  summary: string;
  features: readonly { icon: string; label: string; detail: string }[];
  availabilityLabel: string;
}

export default function ReleaseAnnouncement({
  assetBaseURL, actionURL, preview, marketing, subscriptionContext, versionLabel,
  releaseDateLabel, headline, summary, features, availabilityLabel,
}: ReleaseAnnouncementProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Product update"
      headerDetail="Release notes"
      previewText={headline}
      icon="megaphone"
      title={headline}
      intro={summary}
      actionLabel="Read the release notes"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card, marginBottom: theme.space.section, backgroundImage: "linear-gradient(135deg,rgba(255,106,0,0.14),rgba(255,106,0,0))" }}>
          <Row>
            <Column style={{ padding: theme.space.inset, verticalAlign: "middle" }}>
              <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 8px" }}>The release</Text>
              <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.display, lineHeight: 1.25, margin: 0, wordBreak: "break-word" }}>{versionLabel}</Text>
              <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "8px 0 0" }}>{releaseDateLabel}</Text>
            </Column>
            <Column width="64" style={{ padding: "16px 16px 16px 0", verticalAlign: "middle" }}>
              <Img src={`${assets}/megaphone.png`} alt="" aria-hidden="true" width={40} height={40} style={{ display: "block" }} />
            </Column>
          </Row>
        </Section>
      }
    >
      <EmailFeatures assetBaseURL={assetBaseURL} items={features} />
      <EmailFacts items={[{ label: "Availability", value: availabilityLabel }]} />
    </EmailMessage>
  );
}

ReleaseAnnouncement.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: product announcements enabled.",
  versionLabel: "Preview edition",
  releaseDateLabel: "Sample release · not published",
  headline: "A closer look at the details.",
  summary: "From planning the breaks to finding your next exercise, here are the highlights in this sample release.",
  features: [
    { icon: "layers", label: "Rest structure", detail: "Distinct breaks for sets and sections." },
    { icon: "folder", label: "Your library", detail: "Related exercises, grouped together." },
    { icon: "play", label: "Player controls", detail: "Workout timing and music, kept separate." },
  ],
  availabilityLabel: "Design sample only",
} satisfies ReleaseAnnouncementProps;
