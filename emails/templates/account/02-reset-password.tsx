import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface ResetPasswordProps extends EmailLinks { emailAddress: string; expiresIn: string }

export default function ResetPassword(props: ResetPasswordProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Password recovery"
    previewText="Use your requested link to reset your Tmax password." icon="key-round"
    title="A fresh start. Securely." intro="Use this requested link on the device where you started password recovery."
    actionLabel="Reset password" note="Didn't request this? Ignore the email; your password has not changed.">
    <EmailFacts items={[{ label: "Account", value: props.emailAddress }, { label: "Link valid for", value: props.expiresIn }]} />
  </EmailMessage>;
}
ResetPassword.PreviewProps = { ...previewLinks, emailAddress: "alex@example.com", expiresIn: "60 minutes" } satisfies ResetPasswordProps;
