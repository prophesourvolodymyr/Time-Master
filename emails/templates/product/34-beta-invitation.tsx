import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface BetaInvitationProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
  programName: string;
  testingFocus: string;
  platformLabel: string;
  accessDetails: string;
}

export default function BetaInvitation({
  assetBaseURL, actionURL, preview, marketing, subscriptionContext,
  programName, testingFocus, platformLabel, accessDetails,
}: BetaInvitationProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Beta invitation"
      headerDetail="Optional participation"
      previewText="An optional invitation to explore a pre-release build."
      icon="rocket"
      title="Take a look before launch."
      intro={testingFocus}
      actionLabel="View beta invitation"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderRadius: theme.radius.card, padding: theme.space.inset, marginBottom: theme.space.section, backgroundImage: "linear-gradient(145deg,rgba(255,106,0,0.14),rgba(255,106,0,0))" }}>
          <Row>
            <Column width="52" style={{ verticalAlign: "top", paddingTop: 3 }}>
              <Img src={`${assets}/rocket.png`} alt="" aria-hidden="true" width={36} height={36} style={{ display: "block" }} />
            </Column>
            <Column>
              <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 8px" }}>Pre-release program</Text>
              <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.title, lineHeight: 1.25, margin: 0, wordBreak: "break-word" }}>{programName}</Text>
            </Column>
          </Row>
          <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, borderTop: "1px solid #484038", paddingTop: 12, margin: "16px 0 0" }}>Invitation only · joining is a separate choice</Text>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Platform", value: platformLabel },
        { label: "Access", value: accessDetails },
      ]} />
      <EmailNotice title="Choose whether to test">
        Joining is optional. Beta software can be unstable; review the requirements before installing.
      </EmailNotice>
    </EmailMessage>
  );
}

BetaInvitation.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: beta invitations enabled.",
  programName: "Next-build preview",
  testingFocus: "Try a pre-release workflow and tell us where the experience feels unclear.",
  platformLabel: "iPhone and Mac · sample program",
  accessDetails: "Review the invitation requirements",
} satisfies BetaInvitationProps;
