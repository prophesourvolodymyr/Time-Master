import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PolicyUpdateProps extends EmailLinks { policyVersion: string; effectiveDate: string; changeSummary: string }
export default function PolicyUpdate(props: PolicyUpdateProps) {
  return <EmailMessage {...props} category="Your account" headerDetail="Privacy update"
    previewText="Review an important update to Tmax privacy information." icon="file-text"
    title="Know what is changing." intro="Review the updated policy and any choices that need your attention."
    actionLabel="Review policy update" note="Opening an email or link does not grant a new data-processing permission.">
    <EmailFacts items={[{ label: "Policy version", value: props.policyVersion }, { label: "Effective date", value: props.effectiveDate }]} />
    <EmailNotice title="The change, briefly">{props.changeSummary}</EmailNotice>
  </EmailMessage>;
}
PolicyUpdate.PreviewProps = { ...previewLinks, policyVersion: "Preview revision", effectiveDate: "1 November 2026", changeSummary: "An updated explanation of data handling is ready to review. Any required new consent is requested separately in the app." } satisfies PolicyUpdateProps;
