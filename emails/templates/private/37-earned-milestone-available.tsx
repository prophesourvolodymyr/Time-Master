import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailFeatures,
  EmailMessage,
  EmailSymbol,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface EarnedMilestoneAvailableProps extends EmailLinks {
  availableOn: string;
  marketing: MarketingFooter;
}

export default function EarnedMilestoneAvailable({ availableOn, marketing, ...links }: EarnedMilestoneAvailableProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Private notification"
      headerDetail="For your account"
      previewText="A new private account update is available."
      icon="mail"
      title="Something new is ready."
      intro="A new update is waiting in your account. Open it when you’re ready."
      actionLabel="Open private update"
      visual={
        <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="mail" />
          <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: 32, lineHeight: "38px", margin: "0 0 8px" }}>For you.</Text>
          <Text style={{ color: theme.colors.secondaryText, fontSize: 12, lineHeight: "18px", margin: 0 }}>View it privately in your account.</Text>
        </Section>
      }
      note="Your optional email choices are available below."
    >
      <EmailFeatures assetBaseURL={links.assetBaseURL} items={[
        { icon: "lock-keyhole", label: "Private", detail: "Sign in to view" },
        { icon: "settings", label: "Your choice", detail: "Optional emails" },
      ]} />
      <EmailFacts items={[{ label: "Available", value: availableOn }]} />
    </EmailMessage>
  );
}

EarnedMilestoneAvailable.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  availableOn: "22 Oct 2026",
} satisfies EarnedMilestoneAvailableProps;
