import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface ConfirmEmailProps extends EmailLinks { emailAddress: string; expiresIn: string }

export default function ConfirmEmail(props: ConfirmEmailProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Email confirmation"
    previewText="Confirm your email address to finish setting up Tmax." icon="mail"
    title="One step to your account." intro="Confirm this address to continue. This does not subscribe you to product emails."
    actionLabel="Confirm email" note="Didn't create an account? You can ignore this email.">
    <EmailFacts items={[{ label: "Email address", value: props.emailAddress }, { label: "Link valid for", value: props.expiresIn }]} />
  </EmailMessage>;
}
ConfirmEmail.PreviewProps = { ...previewLinks, emailAddress: "alex@example.com", expiresIn: "60 minutes" } satisfies ConfirmEmailProps;
