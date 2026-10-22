import { EmailMessage, EmailNotice, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface AICoachProviderApprovalProps extends EmailLinks {
  marketing: MarketingFooter;
}

const setup = [
  { icon: "globe", label: "Choose provider + model", detail: "Use an available endpoint you can access." },
  { icon: "key-round", label: "Add your own key", detail: "Enter credentials in AI Coach settings, never in an email." },
  { icon: "bot", label: "Ask, then review", detail: "Read proposed library or settings changes before applying them." },
] as const;

export default function AICoachProviderApprovalEmail({ marketing, ...links }: AICoachProviderApprovalProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="AI Coach setup"
      previewText="Choose a provider, configure access and review app changes before approval."
      icon="bot"
      title="Your provider. Your approval."
      intro="Choose the provider and model. Keep its access, pricing and data terms in view."
      actionLabel="Read the AI Coach guide"
      visual={<EmailSteps assetBaseURL={links.assetBaseURL} items={setup} />}
      note="Approval controls app changes, not provider processing of your conversation. Provider access and charges are separate from Tmax."
    >
      <EmailNotice title="Approve or reject">
        Library and settings writes wait for your review. Approve applies the proposed change; Reject leaves it unapplied.
      </EmailNotice>
    </EmailMessage>
  );
}

AICoachProviderApprovalEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies AICoachProviderApprovalProps;
