import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface UnusualSignInProps extends EmailLinks { eventReference: string; detectedAt: string; safeReason: string }
export default function UnusualSignIn(props: UnusualSignInProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Activity review"
    previewText="A verified account-security event needs your review." icon="shield-alert"
    title="Take a look at this sign-in." intro="An account-security event was flagged by the configured identity service. It does not by itself prove unauthorized access."
    actionLabel="Review security event">
    <EmailNotice title="Why you're receiving this">{props.safeReason}</EmailNotice>
    <EmailFacts items={[{ label: "Event", value: props.eventReference }, { label: "Detected", value: props.detectedAt }]} />
  </EmailMessage>;
}
UnusualSignIn.PreviewProps = { ...previewLinks, eventReference: "SEC-1042", detectedAt: "22 October, 14:30 UTC", safeReason: "The identity service recorded an unusual sign-in pattern. Review the secure event details to decide whether it was expected." } satisfies UnusualSignInProps;
