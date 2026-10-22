import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface InformationRequestedProps extends EmailLinks {
  caseReference: string;
  updatedOn: string;
}

export default function InformationRequested({ caseReference, updatedOn, ...links }: InformationRequestedProps) {
  return (
    <EmailMessage
      {...links}
      category="Private notification"
      headerDetail="Action available"
      previewText="Open your account to read a private request."
      icon="message-circle"
      title="Your attention is needed."
      intro="Open your private case to see what is needed. Please don’t send attachments by email."
      actionLabel="Open private case"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="message-circle" />
          <EmailSteps assetBaseURL={links.assetBaseURL} items={[
            { icon: "lock-keyhole", label: "Open your case", detail: "Sign in to your account." },
            { icon: "file-text", label: "Read the request", detail: "Details are available privately." },
          ]} />
        </>
      }
      note="Keep private details in your account."
    >
      <EmailFacts items={[
        { label: "Reference", value: caseReference },
        { label: "Updated", value: updatedOn },
      ]} />
    </EmailMessage>
  );
}

InformationRequested.PreviewProps = {
  ...previewLinks,
  caseReference: "CASE-4821",
  updatedOn: "22 Oct 2026",
} satisfies InformationRequestedProps;
