import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface DeletionCompletedProps extends EmailLinks { reference: string; completedAt: string; completedScope: string }
export default function DeletionCompleted(props: DeletionCompletedProps) {
  return <EmailMessage {...props} category="Your account" headerDetail="Deletion status"
    previewText="The confirmed scope of your account deletion is available." icon="shield-check"
    title="Deletion confirmed." intro="The completed scope is recorded below. Review your secure receipt for retention limits and any remaining obligations."
    actionLabel="View final receipt" note="Independent ZIP backups and local device copies are not erased by a cloud-account request.">
    <EmailFacts items={[{ label: "Reference", value: props.reference }, { label: "Confirmed", value: props.completedAt }]} />
    <EmailNotice title="Confirmed scope">{props.completedScope}</EmailNotice>
  </EmailMessage>;
}
DeletionCompleted.PreviewProps = { ...previewLinks, reference: "DEL-1042", completedAt: "23 October, 09:15 UTC", completedScope: "The account and associated active-system cloud records covered by this request have been removed." } satisfies DeletionCompletedProps;
