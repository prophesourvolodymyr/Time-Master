import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PasswordChangedProps extends EmailLinks { emailAddress: string; changedAt: string }

export default function PasswordChanged(props: PasswordChangedProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Change confirmed"
    previewText="Your Tmax password has been changed." icon="shield-check"
    title="Your password is updated." intro="The password change for your account succeeded."
    actionLabel="Review account security">
    <EmailFacts items={[{ label: "Account", value: props.emailAddress }, { label: "Changed", value: props.changedAt }]} />
    <EmailNotice title="Wasn't you?">Open account security to get recovery help. Never share a password or recovery link by email.</EmailNotice>
  </EmailMessage>;
}
PasswordChanged.PreviewProps = { ...previewLinks, emailAddress: "alex@example.com", changedAt: "22 October, 14:30 UTC" } satisfies PasswordChangedProps;
