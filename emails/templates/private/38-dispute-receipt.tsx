import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface DisputeReceiptProps extends EmailLinks {
  receiptReference: string;
  receivedOn: string;
}

export default function DisputeReceipt({ receiptReference, receivedOn, ...links }: DisputeReceiptProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private receipt"
      previewText="Your request was received. Private status is available."
      icon="clipboard-list"
      title="Your request is recorded."
      intro="Your submission has a receipt. Open your private case to view its current status."
      actionLabel="Open private case"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="clipboard-list" />
          <EmailSteps assetBaseURL={links.assetBaseURL} items={[
            { icon: "file-check", label: "Received", detail: "Intake is confirmed." },
            { icon: "lock-keyhole", label: "Private status", detail: "Available in your account." },
          ]} />
        </>
      }
      note="A receipt does not confirm a decision or any change."
    >
      <EmailFacts items={[
        { label: "Reference", value: receiptReference },
        { label: "Received", value: receivedOn },
      ]} />
    </EmailMessage>
  );
}

DisputeReceipt.PreviewProps = {
  ...previewLinks,
  receiptReference: "REQ-4822",
  receivedOn: "22 Oct 2026",
} satisfies DisputeReceiptProps;
