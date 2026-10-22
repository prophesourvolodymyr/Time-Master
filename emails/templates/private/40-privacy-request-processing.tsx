import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PrivacyRequestProcessingProps extends EmailLinks {
  requestReference: string;
  updatedOn: string;
  scopeLabel: "Selected account data" | "Selected privacy choices";
}

export default function PrivacyRequestProcessing({ requestReference, updatedOn, scopeLabel, ...links }: PrivacyRequestProcessingProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private status"
      previewText="Your request is in progress. View its private status in your account."
      icon="history"
      title="Your request is in progress."
      intro="The requested work is not yet complete. Open private status to see what remains."
      actionLabel="Check request status"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="history" />
          <EmailSteps assetBaseURL={links.assetBaseURL} items={[
            { icon: "file-text", label: "Request received", detail: "Your request has a receipt." },
            { icon: "history", label: "Completion pending", detail: "The current status is available privately." },
          ]} />
        </>
      }
      note="This request covers only the scope shown, not whole-account deletion."
    >
      <EmailFacts items={[
        { label: "Reference", value: requestReference },
        { label: "Updated", value: updatedOn },
        { label: "Requested scope", value: scopeLabel },
      ]} />
    </EmailMessage>
  );
}

PrivacyRequestProcessing.PreviewProps = {
  ...previewLinks,
  requestReference: "PRV-4821",
  updatedOn: "22 Oct 2026",
  scopeLabel: "Selected account data",
} satisfies PrivacyRequestProcessingProps;
