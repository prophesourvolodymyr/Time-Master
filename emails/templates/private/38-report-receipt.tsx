import { Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface ReportReceiptProps extends EmailLinks {
  receiptReference: string;
  receivedOn: string;
}

export default function ReportReceipt({ receiptReference, receivedOn, ...links }: ReportReceiptProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private receipt"
      previewText="Your request was received. View the receipt in your account."
      icon="file-text"
      title="Your request was received."
      intro="Keep this reference for your request. Its current status is available in your private case."
      actionLabel="View private receipt"
      visual={
        <Section style={{ marginBottom: theme.space.section }}>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="file-text" />
          <Section style={{ borderTop: `1px solid ${theme.colors.border}`, borderBottom: `1px solid ${theme.colors.border}`, padding: "16px 0", textAlign: "center" }}>
            <Text style={{ color: theme.colors.secondaryText, fontSize: 12, lineHeight: "18px", margin: "0 0 4px" }}>Receipt reference</Text>
            <Text style={{ color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: 24, lineHeight: "30px", wordBreak: "break-word", margin: 0 }}>{receiptReference}</Text>
          </Section>
        </Section>
      }
      note="This confirms intake only, not a decision or review."
    >
      <EmailFacts items={[
        { label: "Status", value: "Received" },
        { label: "Received", value: receivedOn },
      ]} />
    </EmailMessage>
  );
}

ReportReceipt.PreviewProps = {
  ...previewLinks,
  receiptReference: "REQ-4821",
  receivedOn: "22 Oct 2026",
} satisfies ReportReceiptProps;
