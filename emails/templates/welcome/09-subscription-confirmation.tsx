import { EmailFacts, EmailMessage, EmailSymbol, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";

interface SubscriptionConfirmationProps extends EmailLinks {
  subscriptionLabel: string;
  expiresLabel: string;
}

export default function SubscriptionConfirmationEmail({ subscriptionLabel, expiresLabel, ...links }: SubscriptionConfirmationProps) {
  return (
    <EmailMessage
      {...links}
      category="Email subscription"
      headerDetail="Confirmation"
      previewText="Confirm your choice before receiving optional Tmax emails."
      icon="mail"
      title="One step to subscribe."
      intro={`Confirm to receive ${subscriptionLabel}. This is not an account-verification email.`}
      actionLabel="Confirm subscription"
      visual={<EmailSymbol assetBaseURL={links.assetBaseURL} name="mail" />}
      note="If you did not ask for these emails, ignore this message. Opening the email does not subscribe you."
    >
      <EmailFacts items={[
        { label: "Emails", value: subscriptionLabel },
        { label: "Link expires", value: expiresLabel },
      ]} />
    </EmailMessage>
  );
}

SubscriptionConfirmationEmail.PreviewProps = {
  ...previewLinks,
  subscriptionLabel: "Tmax guides and product news",
  expiresLabel: "23 October 2026, 18:00 UTC",
} satisfies SubscriptionConfirmationProps;
