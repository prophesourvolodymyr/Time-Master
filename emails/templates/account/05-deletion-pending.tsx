import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface DeletionPendingProps extends EmailLinks { reference: string; updatedAt: string; statusSummary: string }
export default function DeletionPending(props: DeletionPendingProps) {
  return <EmailMessage {...props} category="Your account" headerDetail="Deletion update"
    previewText="An update is available for your account-deletion request." icon="history"
    title="Cleanup is still in progress." intro="Your deletion request remains open. This is not a completion confirmation."
    actionLabel="Check request status">
    <EmailFacts items={[{ label: "Reference", value: props.reference }, { label: "Last update", value: props.updatedAt }]} />
    <EmailNotice title="Current status">{props.statusSummary}</EmailNotice>
  </EmailMessage>;
}
DeletionPending.PreviewProps = { ...previewLinks, reference: "DEL-1042", updatedAt: "22 October, 15:10 UTC", statusSummary: "Active-system cleanup is pending. Review the secure receipt for the current scope and any applicable retention limits." } satisfies DeletionPendingProps;
