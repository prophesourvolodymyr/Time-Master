import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface DecisionAvailableProps extends EmailLinks {
  caseReference: string;
  updatedOn: string;
}

export default function DecisionAvailable({ caseReference, updatedOn, ...links }: DecisionAvailableProps) {
  return (
    <EmailMessage
      {...links}
      category="Private notification"
      headerDetail="Ready to view"
      previewText="A private update is available in your account."
      icon="file-text"
      title="A private update is ready."
      intro="Open your private case to read the update and see any available next steps."
      actionLabel="Read private update"
      visual={
        <Section style={{ marginBottom: theme.space.section, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, backgroundColor: theme.colors.raisedSurface, padding: theme.space.inset }}>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="file-text" />
          <Text style={{ fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, color: theme.colors.text, fontSize: 20, lineHeight: "26px", textAlign: "center", margin: "0 0 4px" }}>Ready to read</Text>
          <Text style={{ color: theme.colors.secondaryText, fontSize: 12, lineHeight: "18px", textAlign: "center", margin: 0 }}>Sign in to view the current record.</Text>
        </Section>
      }
      note="This email does not include the private details."
    >
      <EmailFacts items={[
        { label: "Reference", value: caseReference },
        { label: "Updated", value: updatedOn },
      ]} />
    </EmailMessage>
  );
}

DecisionAvailable.PreviewProps = {
  ...previewLinks,
  caseReference: "CASE-4821",
  updatedOn: "22 Oct 2026",
} satisfies DecisionAvailableProps;
