import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface SignInMethodAddedProps extends EmailLinks { methodName: string; changedAt: string }
export default function SignInMethodAdded(props: SignInMethodAddedProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Sign-in method added"
    previewText="A sign-in method was connected to your Tmax account." icon="user-check"
    title="A new way to sign in." intro="A sign-in method was successfully connected to your existing account."
    actionLabel="Review sign-in methods" note="Didn't make this change? Review your account-security options.">
    <EmailFacts items={[{ label: "Method", value: props.methodName }, { label: "Connected", value: props.changedAt }]} />
  </EmailMessage>;
}
SignInMethodAdded.PreviewProps = { ...previewLinks, methodName: "Configured identity provider", changedAt: "22 October, 14:30 UTC" } satisfies SignInMethodAddedProps;
