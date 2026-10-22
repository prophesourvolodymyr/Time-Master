import { EmailFacts, EmailMessage, EmailNotice, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface NewDeviceSignInProps extends EmailLinks { deviceName: string; signedInAt: string }
export default function NewDeviceSignIn(props: NewDeviceSignInProps) {
  return <EmailMessage {...props} category="Account security" headerDetail="Sign-in notice"
    previewText="A new device signed in to your Tmax account." icon="monitor-smartphone"
    title="Recognize this device?" intro="A confirmed sign-in was recorded from a device not previously recognized for your account."
    actionLabel="Review account activity">
    <EmailFacts items={[{ label: "Device", value: props.deviceName }, { label: "Signed in", value: props.signedInAt }]} />
    <EmailNotice title="If this wasn't you">Review active access and use the secure recovery options. Never share a verification link.</EmailNotice>
  </EmailMessage>;
}
NewDeviceSignIn.PreviewProps = { ...previewLinks, deviceName: "Mac · macOS", signedInAt: "22 October, 14:30 UTC" } satisfies NewDeviceSignInProps;
