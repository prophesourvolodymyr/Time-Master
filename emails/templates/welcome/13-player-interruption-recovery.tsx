import { EmailMessage, EmailNotice, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface PlayerInterruptionRecoveryProps extends EmailLinks {
  marketing: MarketingFooter;
}

const recovery = [
  { icon: "pause", label: "Before you step away", detail: "Use Pause when you want the timer to wait." },
  { icon: "refresh-cw", label: "When you return", detail: "Check the current phase and time. Unpaused timing can advance while you are away." },
  { icon: "history", label: "If the app was closed", detail: "Review saved progress if a resume checkpoint is available." },
] as const;

export default function PlayerInterruptionRecoveryEmail({ marketing, ...links }: PlayerInterruptionRecoveryProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Player guide"
      headerDetail="Interruption & recovery"
      previewText="Leaving the app is not the same as pressing Pause."
      icon="shield"
      title="Leaving is not pausing."
      intro="Locking the screen or switching apps is not a Pause command. Make the choice in the player."
      actionLabel="Read recovery behavior"
      visual={<EmailSteps assetBaseURL={links.assetBaseURL} items={recovery} />}
    >
      <EmailNotice title="Background execution is not guaranteed">
        iOS may suspend the app. Do not rely on uninterrupted background sound or a continuously running screen; review the player when you return.
      </EmailNotice>
    </EmailMessage>
  );
}

PlayerInterruptionRecoveryEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies PlayerInterruptionRecoveryProps;
