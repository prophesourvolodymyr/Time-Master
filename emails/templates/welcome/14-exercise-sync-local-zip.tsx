import { EmailFeatures, EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface ExerciseSyncLocalZipProps extends EmailLinks {
  marketing: MarketingFooter;
}

const connection = [
  { icon: "monitor-smartphone", label: "iPhone + Mac", detail: "Use the same account." },
  { icon: "cloud", label: "Exercise library", detail: "Pages, guides and referenced media." },
] as const;
const choices = [
  { icon: "cloud", label: "Exercise-database sync", detail: "Needs a configured service. Runs while the app is active and you are signed in." },
  { icon: "cloud-off", label: "Local only", detail: "Turn sync off on this device to stop database uploads, downloads and polling." },
  { icon: "archive", label: "Carry a ZIP", detail: "Export a local backup and transfer it yourself, signed in or out." },
] as const;

export default function ExerciseSyncLocalZipEmail({ marketing, ...links }: ExerciseSyncLocalZipProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="Devices & library"
      previewText="Understand exercise sync, local-only mode and manual ZIP transfer."
      icon="monitor-smartphone"
      title="The library. Not everything."
      intro="Connect your exercise library between supported iPhone and Mac builds. Local-only use and manual ZIP transfer remain separate choices."
      actionLabel="Read the transfer guide"
      visual={<EmailFeatures assetBaseURL={links.assetBaseURL} items={connection} />}
      note="Profile, workouts, history, routes, music, secrets and ZIP backups are outside exercise-database sync."
    >
      <EmailSteps assetBaseURL={links.assetBaseURL} items={choices} />
    </EmailMessage>
  );
}

ExerciseSyncLocalZipEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies ExerciseSyncLocalZipProps;
