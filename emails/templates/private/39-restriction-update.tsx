import {
  EmailFacts,
  EmailMessage,
  EmailNotice,
  EmailSymbol,
  type EmailLinks,
} from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface RestrictionUpdateProps extends EmailLinks {
  caseReference: string;
  updatedOn: string;
}

export default function RestrictionUpdate({ caseReference, updatedOn, ...links }: RestrictionUpdateProps) {
  return (
    <EmailMessage
      {...links}
      category="Account update"
      headerDetail="Private status"
      previewText="Your account has a private status update."
      icon="info"
      title="Your account has an update."
      intro="Open your private case for the current status and any available actions."
      actionLabel="View private status"
      visual={
        <>
          <EmailSymbol assetBaseURL={links.assetBaseURL} name="info" />
          <EmailNotice title="Status updated">The current details are available only in your account.</EmailNotice>
        </>
      }
      note="Sign in to the account this notification belongs to."
    >
      <EmailFacts items={[
        { label: "Reference", value: caseReference },
        { label: "Updated", value: updatedOn },
      ]} />
    </EmailMessage>
  );
}

RestrictionUpdate.PreviewProps = {
  ...previewLinks,
  caseReference: "CASE-4821",
  updatedOn: "22 Oct 2026",
} satisfies RestrictionUpdateProps;
