import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface AppealReceiptProps extends EmailLinks {
  receiptReference: string;
  receivedOn: string;
}

export default function AppealReceipt({ receiptReference, receivedOn, ...links }: AppealReceiptProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private receipt"
      previewText="A receipt for your request is available in your account."
      icon="mail"
      title="Your receipt is ready."
      intro="Your request was received. Open your private case for the current status and any available next steps."
      actionLabel="View private receipt"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="mail" />
          <EmailNotice title="Received">This is an intake receipt, not a decision or a change to the current status.</EmailNotice>
        </>
      }
      note="Details stay in your private case."
    >
      <EmailFacts items={[
        { label: "Reference", value: receiptReference },
        { label: "Received", value: receivedOn },
      ]} />
    </EmailMessage>
  );
}

AppealReceipt.PreviewProps = {
  ...previewLinks,
  receiptReference: "REQ-4823",
  receivedOn: "22 Oct 2026",
} satisfies AppealReceiptProps;
