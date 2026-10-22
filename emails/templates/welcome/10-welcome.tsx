import { EmailFeatures, EmailMessage, EmailNotice, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface WelcomeProps extends EmailLinks {
  marketing: MarketingFooter;
}

const modes = [
  { icon: "dumbbell", label: "On device", detail: "Library, plans and timer. No account required." },
  { icon: "cloud", label: "With account", detail: "Exercise sync and Ranked. Services required." },
] as const;

export default function WelcomeEmail({ marketing, ...links }: WelcomeProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="Welcome guide"
      previewText="Start locally. Connect only the account features you choose."
      icon="rocket"
      title="Start on your terms."
      intro="Keep your routine on-device. Connect only the account features you choose."
      actionLabel="Explore the app guide"
      visual={<EmailFeatures assetBaseURL={links.assetBaseURL} items={modes} />}
      note="Feature availability depends on your build and configured services."
    >
      <EmailNotice title="Not an everything-sync account">
        Exercise-library sync does not synchronize your local Profile, workouts, history, routes or music.
      </EmailNotice>
    </EmailMessage>
  );
}

WelcomeEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies WelcomeProps;
