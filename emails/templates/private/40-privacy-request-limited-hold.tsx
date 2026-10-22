import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface PrivacyRequestLimitedHoldProps extends EmailLinks {
  requestReference: string;
  updatedOn: string;
  scopeLabel: "Selected account data" | "Selected privacy choices";
}

export default function PrivacyRequestLimitedHold({ requestReference, updatedOn, scopeLabel, ...links }: PrivacyRequestLimitedHoldProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private status"
      previewText="There is a private status update for your request."
      icon="file-text"
      title="A private status update."
      intro="Part of the requested scope remains on hold. Open private status for the limits and current progress."
      actionLabel="View request status"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="file-text" />
          <EmailSteps assetBaseURL={links.assetBaseURL} items={[
            { icon: "lock-keyhole", label: "Limited hold", detail: "The affected scope is explained privately." },
            { icon: "clipboard-list", label: "Other requested work", detail: "Tracked separately in the same request." },
          ]} />
        </>
      }
      note="A limited hold does not describe the status of your whole account."
    >
      <EmailFacts items={[
        { label: "Reference", value: requestReference },
        { label: "Updated", value: updatedOn },
        { label: "Requested scope", value: scopeLabel },
      ]} />
    </EmailMessage>
  );
}

PrivacyRequestLimitedHold.PreviewProps = {
  ...previewLinks,
  requestReference: "PRV-4821",
  updatedOn: "22 Oct 2026",
  scopeLabel: "Selected account data",
} satisfies PrivacyRequestLimitedHoldProps;
