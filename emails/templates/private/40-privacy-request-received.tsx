import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PrivacyRequestReceivedProps extends EmailLinks {
  requestReference: string;
  receivedOn: string;
  scopeLabel: "Selected account data" | "Selected privacy choices";
}

export default function PrivacyRequestReceived({ requestReference, receivedOn, scopeLabel, ...links }: PrivacyRequestReceivedProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private receipt"
      previewText="Your request was received. Open your account for private status."
      icon="lock-keyhole"
      title="Your request was received."
      intro="Your privacy request has a receipt. Open private status for the confirmed scope and next steps."
      actionLabel="View request status"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="lock-keyhole" />
          <EmailNotice title="Received">Intake is confirmed. Completion has not been confirmed.</EmailNotice>
        </>
      }
      note="This request covers only the scope shown, not whole-account deletion."
    >
      <EmailFacts items={[
        { label: "Reference", value: requestReference },
        { label: "Received", value: receivedOn },
        { label: "Requested scope", value: scopeLabel },
      ]} />
    </EmailMessage>
  );
}

PrivacyRequestReceived.PreviewProps = {
  ...previewLinks,
  requestReference: "PRV-4821",
  receivedOn: "22 Oct 2026",
  scopeLabel: "Selected account data",
} satisfies PrivacyRequestReceivedProps;
