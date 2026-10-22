import { Column, Img, Row, Section, Text } from "react-email";
import {
  EmailFacts,
  EmailMessage,
  EmailProgress,
  type EmailLinks,
  type MarketingFooter,
} from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

export interface SavedSessionResumeProps extends EmailLinks {
  marketing: MarketingFooter;
  workoutTitle: string;
  savedAtLabel: string;
  completedSteps: number;
  totalSteps: number;
  progressFraction: number;
  resumePointLabel: string;
  savedStateLabel: string;
}

export default function SavedSessionResume({
  assetBaseURL,
  actionURL,
  preview,
  marketing,
  workoutTitle,
  savedAtLabel,
  completedSteps,
  totalSteps,
  progressFraction,
  resumePointLabel,
  savedStateLabel,
}: SavedSessionResumeProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Your sessions"
      headerDetail="Saved session"
      previewText="Review a saved session and choose when to continue."
      icon="archive"
      title="Your place is saved."
      intro="Pick up from the saved point when it fits."
      actionLabel="Review saved session"
      note="Saved progress is not a completed session."
      visual={
        <Section style={{
          backgroundColor: theme.colors.raisedSurface,
          border: `1px solid ${theme.colors.border}`,
          borderRadius: theme.radius.card,
          padding: "16px 12px 0",
          marginBottom: theme.space.section,
        }}>
          <Row>
            <Column width="32" style={{ verticalAlign: "middle" }}>
              <Img src={`${assetBaseURL.replace(/\/+$/, "")}/archive.png`} alt="" aria-hidden="true"
                width={24} height={24} style={{ display: "block" }} />
            </Column>
            <Column style={{ verticalAlign: "middle" }}>
              <Text style={{
                fontFamily: theme.headingFontFamily,
                fontWeight: theme.fontWeight.black,
                color: theme.colors.text,
                fontSize: theme.fontSize.secondary,
                lineHeight: "21px",
                margin: 0,
              }}>Saved · In progress</Text>
            </Column>
          </Row>
          <Text style={{
            borderTop: "1px dashed #484038",
            paddingTop: 16,
            fontFamily: theme.headingFontFamily,
            fontWeight: theme.fontWeight.black,
            color: theme.colors.text,
            fontSize: theme.fontSize.heading,
            lineHeight: "28px",
            wordBreak: "break-word",
            margin: "16px 0",
          }}>{workoutTitle}</Text>
          <EmailProgress
            label="Finished steps"
            value={`${completedSteps} of ${totalSteps}`}
            fraction={progressFraction}
          />
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "Saved", value: savedAtLabel },
        { label: "Continue from", value: resumePointLabel },
        { label: "Saved state", value: savedStateLabel },
      ]} />
    </EmailMessage>
  );
}

SavedSessionResume.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  workoutTitle: "Full-body foundations",
  savedAtLabel: "22 October 2026 · 18:24 · Europe/Kyiv",
  completedSteps: 3,
  totalSteps: 8,
  progressFraction: 0.375,
  resumePointLabel: "Exercise 4 · Split squats",
  savedStateLabel: "Paused between exercises",
} satisfies SavedSessionResumeProps;
