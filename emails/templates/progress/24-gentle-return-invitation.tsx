import { Column, Img, Row, Section, Text } from "react-email";
import {
  EmailMessage,
  EmailNotice,
  EmailSymbol,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface GentleReturnInvitationProps extends EmailLinks {
  marketing: MarketingFooter;
  suggestedWorkoutTitle: string;
  suggestedDurationLabel: string;
  invitationContextLabel: string;
  planContextLabel: string;
}

export default function GentleReturnInvitation({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  suggestedWorkoutTitle,
  suggestedDurationLabel,
  invitationContextLabel,
  planContextLabel,
}: GentleReturnInvitationProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Your next session"
      headerDetail="An open invitation"
      previewText="A session to consider whenever the moment suits you."
      icon="route"
      title="Whenever it fits."
      intro="No catching up. Just an invitation to choose your next session."
      actionLabel="Explore your plan"
      note="Planned rest and vacation do not need a catch-up session."
      visual={
        <Section style={{ marginBottom: theme.space.section }}>
          <EmailSymbol assetBaseURL={assetBaseURL} name="route" />
          <Text style={{
            fontFamily: theme.fontFamily,
            color: theme.colors.secondaryText,
            fontSize: theme.fontSize.caption,
            lineHeight: "19px",
            textAlign: "center",
            margin: "0 0 12px",
          }}>{invitationContextLabel}</Text>
          <Section style={{
            backgroundColor: theme.colors.raisedSurface,
            border: `1px solid ${theme.colors.border}`,
            borderRadius: theme.radius.card,
            padding: 16,
          }}>
            <Row>
              <Column width="36" style={{ verticalAlign: "top" }}>
                <Img src={`${assetBaseURL.replace(/\/+$/, "")}/play.png`} alt="" aria-hidden="true"
                  width={24} height={24} style={{ display: "block" }} />
              </Column>
              <Column style={{ verticalAlign: "top", wordBreak: "break-word" }}>
                <Text style={{
                  fontFamily: theme.headingFontFamily,
                  fontWeight: theme.fontWeight.black,
                  color: theme.colors.text,
                  fontSize: theme.fontSize.rowTitle,
                  lineHeight: "22px",
                  margin: 0,
                }}>{suggestedWorkoutTitle}</Text>
                <Text style={{
                  fontFamily: theme.fontFamily,
                  color: theme.colors.secondaryText,
                  fontSize: theme.fontSize.caption,
                  lineHeight: "19px",
                  margin: "4px 0 0",
                }}>{suggestedDurationLabel}</Text>
              </Column>
            </Row>
          </Section>
        </Section>
      }
    >
      <EmailNotice title="Your pace">{planContextLabel}</EmailNotice>
    </EmailMessage>
  );
}

GentleReturnInvitation.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  suggestedWorkoutTitle: "A little mobility",
  suggestedDurationLabel: "12 minutes · no equipment",
  invitationContextLabel: "An option for your next training day",
  planContextLabel: "Keep your planned rest days and vacation. Choose a session when you want one.",
} satisfies GentleReturnInvitationProps;
