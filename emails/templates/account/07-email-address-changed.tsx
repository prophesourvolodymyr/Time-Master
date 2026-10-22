import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface EmailAddressChangedProps extends EmailLinks { newEmailAddress: string; changedAt: string }
export default function EmailAddressChanged(props: EmailAddressChangedProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Email address updated"
    previewText="Your Tmax account email address has changed." icon="mail"
    title="Your sign-in address is updated." intro="The account email change succeeded. Use the confirmed address below for future sign-ins."
    actionLabel="Review account security">
    <EmailFacts items={[{ label: "New address", value: props.newEmailAddress }, { label: "Changed", value: props.changedAt }]} />
    <EmailNotice title="Unexpected change?">Open the secure account-recovery options. Do not send passwords or identity documents by reply.</EmailNotice>
  </EmailMessage>;
}
EmailAddressChanged.PreviewProps = { ...previewLinks, newEmailAddress: "alex@example.com", changedAt: "22 October, 14:30 UTC" } satisfies EmailAddressChangedProps;
