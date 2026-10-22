import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface ResearchInvitationProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
  studyName: string;
  researchQuestion: string;
  sessionFormat: string;
  timeCommitmentLabel: string;
}

export default function ResearchInvitation({
  assetBaseURL, actionURL, preview, marketing, subscriptionContext,
  studyName, researchQuestion, sessionFormat, timeCommitmentLabel,
}: ResearchInvitationProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Research invitation"
      headerDetail="Separate participation choice"
      previewText="An optional research invitation. Review the study before deciding."
      icon="users"
      title="Would you like to take part?"
      intro="Research is optional. Review the study information, then decide whether to join."
      actionLabel="Read study information"
      note={subscriptionContext}
      visual={
        <Section style={{ border: `1px solid ${theme.colors.border}`, backgroundColor: theme.colors.raisedSurface, borderRadius: theme.radius.card, padding: theme.space.inset, marginBottom: theme.space.section }}>
          <Row>
            <Column width="44" style={{ verticalAlign: "middle" }}><Img src={`${assets}/users.png`} alt="" aria-hidden="true" width={28} height={28} style={{ display: "block" }} /></Column>
            <Column><Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: 0 }}>Voluntary research</Text></Column>
          </Row>
          <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.title, lineHeight: 1.25, margin: "16px 0 12px", wordBreak: "break-word" }}>{studyName}</Text>
          <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.secondary, lineHeight: 1.5, margin: 0 }}>{researchQuestion}</Text>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Format", value: sessionFormat },
        { label: "Time", value: timeCommitmentLabel },
      ]} />
      <EmailNotice title="An invitation is not consent">
        Opening this email or its link does not enroll you. Participation requires a separate choice, with study-specific information and consent.
      </EmailNotice>
      <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 24px" }}>
        Declining does not change your app access. This email requests no photos or health information.
      </Text>
    </EmailMessage>
  );
}

ResearchInvitation.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: research invitations enabled. This is not research participation consent.",
  studyName: "From plan to play",
  researchQuestion: "How do you move from a saved plan to a started session?",
  sessionFormat: "Remote conversation · sample study",
  timeCommitmentLabel: "20 minutes · sample",
} satisfies ResearchInvitationProps;
