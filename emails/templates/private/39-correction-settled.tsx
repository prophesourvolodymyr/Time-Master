import {
  EmailFacts,
  EmailMessage,
  EmailSteps,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface CorrectionSettledProps extends EmailLinks {
  recordReference: string;
  updatedOn: string;
}

export default function CorrectionSettled({ recordReference, updatedOn, ...links }: CorrectionSettledProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Ready to view"
      previewText="An updated private record is available in your account."
      icon="refresh-cw"
      title="An updated record is ready."
      intro="An update is available in your account. Open the private record to read the current details."
      actionLabel="View updated record"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="refresh-cw" />
          <EmailSteps assetBaseURL={links.assetBaseURL} items={[
            { icon: "file-text", label: "Updated record", detail: "The current version is available." },
            { icon: "lock-keyhole", label: "Private access", detail: "Read it in your signed-in account." },
          ]} />
        </>
      }
      note="The private record contains the confirmed details."
    >
      <EmailFacts items={[
        { label: "Reference", value: recordReference },
        { label: "Updated", value: updatedOn },
      ]} />
    </EmailMessage>
  );
}

CorrectionSettled.PreviewProps = {
  ...previewLinks,
  recordReference: "REC-4821",
  updatedOn: "22 Oct 2026",
} satisfies CorrectionSettledProps;
