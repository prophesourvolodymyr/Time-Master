import { EmailFeatures, EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";

interface OutdoorPlanRecordSaveProps extends EmailLinks {
  marketing: MarketingFooter;
}

const journey = [
  { icon: "route", label: "Plan", detail: "Choose stops inside an installed area." },
  { icon: "activity", label: "Record", detail: "Allow location access and start deliberately." },
  { icon: "archive", label: "Save", detail: "Review the recording, then save it to Library." },
] as const;
const preparation = [
  { icon: "shield", label: "Privacy", detail: "Review exports and start/finish masking." },
  { icon: "download", label: "Offline", detail: "Import a compatible area before leaving." },
] as const;

export default function OutdoorPlanRecordSaveEmail({ marketing, ...links }: OutdoorPlanRecordSaveProps) {
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="Outdoor guide"
      previewText="Plan a route, record deliberately and review what you save or share."
      icon="route"
      title="Plan it. Record it. Keep it."
      intro="A planned route is not a recording. Start when ready, then review what you keep."
      actionLabel="Read the outdoor guide"
      visual={<EmailSteps assetBaseURL={links.assetBaseURL} items={journey} />}
      note="Planning data stays on-device. Area coverage and platform capabilities vary. Sharing a file does not create a hosted route page."
    >
      <EmailFeatures assetBaseURL={links.assetBaseURL} items={preparation} />
    </EmailMessage>
  );
}

OutdoorPlanRecordSaveEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies OutdoorPlanRecordSaveProps;
