import { EmailFacts, EmailFeatures, EmailMessage, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface RankedAccountLinkedProps extends EmailLinks { displayName: string; linkedAt: string }

export default function RankedAccountLinked(props: RankedAccountLinkedProps) {
  return <EmailMessage {...props} category="Your account" headerDetail="Ranked connection"
    previewText="Your existing Ranked account is now linked to Tmax." icon="link"
    title="One account. Your record." intro="Your existing Ranked identity was successfully linked. Earned ratings and match history stay with it."
    actionLabel="View your account">
    <EmailFeatures assetBaseURL={props.assetBaseURL} items={[{ icon: "user-check", label: "Identity", detail: "Connected" }, { icon: "trophy", label: "Ratings", detail: "Preserved" }, { icon: "history", label: "History", detail: "Preserved" }]} />
    <EmailFacts items={[{ label: "Ranked name", value: props.displayName }, { label: "Linked", value: props.linkedAt }]} />
  </EmailMessage>;
}
RankedAccountLinked.PreviewProps = { ...previewLinks, displayName: "Alex", linkedAt: "22 October, 14:30 UTC" } satisfies RankedAccountLinkedProps;
