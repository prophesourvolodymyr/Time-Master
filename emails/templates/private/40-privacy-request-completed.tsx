import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PrivacyRequestCompletedProps extends EmailLinks {
  requestReference: string;
  completedOn: string;
  scopeLabel: "Selected account data" | "Selected privacy choices";
}

export default function PrivacyRequestCompleted({ requestReference, completedOn, scopeLabel, ...links }: PrivacyRequestCompletedProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private status"
      previewText="The requested scope is complete in active systems. View private status for details."
      icon="file-check"
      title="Your requested work is complete."
      intro="The requested scope is complete in active systems. Open private status for the confirmed details."
      actionLabel="View completion details"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="file-check" />
          <EmailNotice title="Only the requested scope">This does not delete your whole account. Whole-account deletion uses the existing account flow.</EmailNotice>
        </>
      }
      note="Any separate backup or processor retention is listed in private status; this is not a claim of instant erasure everywhere."
    >
      <EmailFacts items={[
        { label: "Reference", value: requestReference },
        { label: "Completed", value: completedOn },
        { label: "Requested scope", value: scopeLabel },
      ]} />
    </EmailMessage>
  );
}

PrivacyRequestCompleted.PreviewProps = {
  ...previewLinks,
  requestReference: "PRV-4821",
  completedOn: "22 Oct 2026",
  scopeLabel: "Selected account data",
} satisfies PrivacyRequestCompletedProps;
