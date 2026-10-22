import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface ServiceRestoredProps extends EmailLinks { restoredService: string; restoredAt: string; recoverySummary: string }
export default function ServiceRestored(props: ServiceRestoredProps) {
  return <EmailMessage {...props} category="Service status" headerDetail="Recovery confirmed"
    previewText="A previously affected Tmax service has recovered." icon="cloud-check"
    title="The service is available again." intro="The affected service has recovered. Check your app for the state of any individual pending operation."
    actionLabel="View recovery details">
    <EmailFacts items={[{ label: "Service", value: props.restoredService }, { label: "Recovered", value: props.restoredAt }]} />
    <EmailNotice title="What this means">{props.recoverySummary}</EmailNotice>
  </EmailMessage>;
}
ServiceRestored.PreviewProps = { ...previewLinks, restoredService: "Exercise-library sync", restoredAt: "22 October, 15:20 UTC", recoverySummary: "Transfers can resume while sync is enabled. This notice does not mean every device has finished downloading." } satisfies ServiceRestoredProps;
