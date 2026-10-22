import { EmailFacts, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface SignInMethodRemovedProps extends EmailLinks { methodName: string; changedAt: string }
export default function SignInMethodRemoved(props: SignInMethodRemovedProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Sign-in method removed"
    previewText="A sign-in method was disconnected from your Tmax account." icon="unlink"
    title="A connection was removed." intro="This sign-in method is no longer connected. Review the remaining ways to access your account."
    actionLabel="Review sign-in methods" note="Unexpected removal? Open account recovery from the secure app flow.">
    <EmailFacts items={[{ label: "Method", value: props.methodName }, { label: "Disconnected", value: props.changedAt }]} />
  </EmailMessage>;
}
SignInMethodRemoved.PreviewProps = { ...previewLinks, methodName: "Configured identity provider", changedAt: "22 October, 14:30 UTC" } satisfies SignInMethodRemovedProps;
