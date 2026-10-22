import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface SecurityNoticeProps extends EmailLinks { noticeTitle: string; safeSummary: string; issuedAt: string; reference: string }
export default function SecurityNotice(props: SecurityNoticeProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Important notice"
    previewText="An important Tmax account-security notice is available." icon="shield-alert"
    title={props.noticeTitle} intro="Review the verified notice and any recommended account actions."
    actionLabel="Review security notice" note="Tmax will never ask you to reply with a password or recovery code.">
    <EmailNotice title="What to know">{props.safeSummary}</EmailNotice>
    <EmailFacts items={[{ label: "Notice", value: props.reference }, { label: "Issued", value: props.issuedAt }]} />
  </EmailMessage>;
}
SecurityNotice.PreviewProps = { ...previewLinks, noticeTitle: "A security update to review.", safeSummary: "A verified account notice is available. Read the secure details before deciding whether any action is needed.", issuedAt: "22 October, 14:30 UTC", reference: "SEC-1042" } satisfies SecurityNoticeProps;
