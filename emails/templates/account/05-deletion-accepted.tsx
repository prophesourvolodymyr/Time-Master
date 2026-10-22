import { EmailFacts, EmailMessage, EmailSteps, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface DeletionAcceptedProps extends EmailLinks { reference: string; requestedAt: string }
export default function DeletionAccepted(props: DeletionAcceptedProps) {
  return <EmailMessage {...props} category="Your account" headerDetail="Request received"
    previewText="Your account-deletion request has been received." icon="file-check"
    title="Your request is recorded." intro="Account deletion has been requested. Cleanup has not finished yet."
    actionLabel="View deletion status">
    <EmailFacts items={[{ label: "Reference", value: props.reference }, { label: "Received", value: props.requestedAt }]} />
    <EmailSteps assetBaseURL={props.assetBaseURL} items={[{ icon: "circle-check", label: "Request received", detail: "A durable receipt is available." }, { icon: "history", label: "Cleanup pending", detail: "Check the secure status page for progress." }]} />
  </EmailMessage>;
}
DeletionAccepted.PreviewProps = { ...previewLinks, reference: "DEL-1042", requestedAt: "22 October, 14:30 UTC" } satisfies DeletionAcceptedProps;
