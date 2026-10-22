import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailNotice, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface OfflineRouteLessonProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
}

export default function OfflineRouteLesson({ assetBaseURL, actionURL, preview, marketing, subscriptionContext }: OfflineRouteLessonProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Short lesson"
      headerDetail="Offline preparation"
      previewText="Route data and map layers are separate checks before you head out."
      icon="route"
      title="Prepare before you disconnect."
      intro="Offline route planning needs a compatible area. Map layers have their own availability and licensing limits. Check both."
      actionLabel="Explore offline preparation"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, marginBottom: theme.space.section, padding: theme.space.inset }}>
          <Text style={{ ...detail, margin: "0 0 16px" }}>Two separate preparations</Text>
          <Row style={{ tableLayout: "fixed" }}>
            <Column width="50%" style={{ paddingRight: 12, verticalAlign: "top", wordBreak: "break-word" }}>
              <Img src={`${assets}/database.png`} alt="" aria-hidden="true" width={32} height={32} style={{ display: "block" }} />
              <Text style={label}>Route data</Text>
              <Text style={detail}>One installed area covering every stop and adjustment.</Text>
            </Column>
            <Column width="50%" style={{ borderLeft: `1px solid ${theme.colors.border}`, paddingLeft: 12, verticalAlign: "top", wordBreak: "break-word" }}>
              <Img src={`${assets}/map.png`} alt="" aria-hidden="true" width={32} height={32} style={{ display: "block" }} />
              <Text style={label}>Map layers</Text>
              <Text style={detail}>Check which layers your provider allows offline.</Text>
            </Column>
          </Row>
        </Section>
      }
    >
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "download", label: "Install and check the area", detail: "Use a compatible pack large enough for the whole route." },
        { icon: "eye", label: "Open the route before leaving", detail: "Review the saved route and check map availability while you still have a connection." },
      ]} />
      <EmailNotice title="Preparation is not a conditions check">
        An offline route does not confirm current access, closures or conditions.
      </EmailNotice>
    </EmailMessage>
  );
}

OfflineRouteLesson.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: short lessons enabled.",
} satisfies OfflineRouteLessonProps;

const label: CSSProperties = { color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.rowTitle, lineHeight: 1.4, margin: "12px 0 6px" };
const detail: CSSProperties = { color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: 0 };
