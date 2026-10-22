import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface ServiceInterruptionProps extends EmailLinks { affectedService: string; startedAt: string; statusSummary: string }
export default function ServiceInterruption(props: ServiceInterruptionProps) {
  return <EmailMessage {...props} category="Service status" headerDetail="Interruption notice"
    previewText="A Tmax service interruption may affect an account feature." icon="cloud-off"
    title="A service needs attention." intro="An interruption has been confirmed. Check the current status before retrying affected actions."
    actionLabel="View service status">
    <EmailFacts items={[{ label: "Affected service", value: props.affectedService }, { label: "Started", value: props.startedAt }]} />
    <EmailNotice title="Current impact">{props.statusSummary}</EmailNotice>
  </EmailMessage>;
}
ServiceInterruption.PreviewProps = { ...previewLinks, affectedService: "Exercise-library sync", startedAt: "22 October, 14:30 UTC", statusSummary: "Cloud transfers may be delayed. Existing local exercise files remain available on your device." } satisfies ServiceInterruptionProps;
