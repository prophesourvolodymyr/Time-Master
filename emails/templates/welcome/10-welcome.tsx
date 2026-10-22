import { EmailFrame } from "../../components/email-frame";
import { EmailFooter, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { EmailWelcome } from "../../components/email-welcome";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface WelcomeProps extends EmailLinks {
  marketing: MarketingFooter;
}


export default function WelcomeEmail({ marketing, ...links }: WelcomeProps) {
  return (
    <EmailFrame assetBaseURL={links.assetBaseURL} previewText="Build a workout. Find a route. Make it yours."
      header={{ category: "Getting started", detail: "Welcome guide" }}>
      <EmailWelcome assetBaseURL={links.assetBaseURL} actionURL={links.actionURL} />
      <EmailFooter marketing={marketing} preview={links.preview} />
    </EmailFrame>
  );
}

WelcomeEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies WelcomeProps;
