import { EmailFrame } from "../components/email-frame";
import { EmailFooter } from "../components/email-message";
import { EmailWelcome } from "../components/email-welcome";

interface WorkspacePreviewProps {
  assetBaseURL?: string;
  previewURL?: string;
}


export default function WorkspacePreview({
  assetBaseURL = "/static",
  previewURL = "http://localhost:3002",
}: WorkspacePreviewProps) {
  return (
    <EmailFrame assetBaseURL={assetBaseURL} previewText="Build a workout. Find a route. Make it yours."
      header={{ category: "Your training, together", detail: "Workouts · Timers · Routes" }}>
      <EmailWelcome assetBaseURL={assetBaseURL} actionURL={previewURL} />
      <EmailFooter preview />
    </EmailFrame>
  );
}

WorkspacePreview.PreviewProps = {
  assetBaseURL: "/static",
  previewURL: "http://localhost:3002",
} satisfies WorkspacePreviewProps;

