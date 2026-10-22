import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface ResultAvailableProps extends EmailLinks {
  availableOn: string;
}

export default function ResultAvailable({ availableOn, ...links }: ResultAvailableProps) {
  return (
    <EmailMessage
      {...links}
      category="Private notification"
      headerDetail="For your account"
      previewText="A private account update is ready to view."
      icon="mail"
      title="Your update is ready."
      intro="There’s a new update in your account. Sign in to view it privately."
      actionLabel="View private update"
      visual={
        <Section style={{ marginBottom: theme.space.section }}>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="mail" />
          <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, padding: theme.space.inset, textAlign: "center" }}>
            <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: 20, lineHeight: "26px", margin: "0 0 4px" }}>Ready to view</Text>
            <Text style={{ color: theme.colors.secondaryText, fontSize: 12, lineHeight: "18px", margin: 0 }}>In your signed-in account</Text>
          </Section>
        </Section>
      }
      note="Details stay in your account."
    >
      <EmailFacts items={[{ label: "Available", value: availableOn }]} />
    </EmailMessage>
  );
}

ResultAvailable.PreviewProps = {
  ...previewLinks,
  availableOn: "22 Oct 2026",
} satisfies ResultAvailableProps;
