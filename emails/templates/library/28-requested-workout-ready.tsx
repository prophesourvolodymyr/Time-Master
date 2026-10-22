import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFacts, EmailMessage, EmailSteps, type EmailLinks } from "../../components/email-message";
import { previewLinks } from "../../components/email-preview";
import { theme } from "../../theme";

interface RequestedWorkoutReadyProps extends EmailLinks {
  workoutTitle: string;
  fileName: string;
  formatLabel: string;
  fileSizeLabel: string;
  preparedAtLabel: string;
  accessLabel: string;
  blocks: readonly { icon: string; label: string; detail: string }[];
}

export default function RequestedWorkoutReadyEmail({ assetBaseURL, actionURL, preview, workoutTitle, fileName, formatLabel, fileSizeLabel, preparedAtLabel, accessLabel, blocks }: RequestedWorkoutReadyProps) {
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      category="Library"
      headerDetail="Requested workout"
      previewText="The workout copy you requested is ready to open."
      icon="clipboard-list"
      title="Your workout is ready."
      intro="The plan you requested is ready. Review it before you begin."
      actionLabel="Open requested workout"
      note={accessLabel}
      visual={
        <Section style={{ marginBottom: 24, backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card }}>
          <Row><Column style={{ padding: 16 }}>
            <Row>
              <Column width="44" style={{ verticalAlign: "top" }}><Img src={`${assetBaseURL.replace(/\/+$/, "")}/clipboard-list.png`} width={30} height={30} alt="" aria-hidden="true" style={{ display: "block" }} /></Column>
              <Column>
                <Text style={{ margin: "0 0 4px", color: theme.colors.secondaryText, fontSize: 12, lineHeight: "19px" }}>Requested plan</Text>
                <Text style={{ margin: 0, color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: 900, fontSize: 20, lineHeight: "26px", wordBreak: "break-word" }}>{workoutTitle}</Text>
              </Column>
            </Row>
            <Section style={{ marginTop: 16, borderTop: `1px solid ${theme.colors.border}`, paddingTop: 4 }}>
              <EmailSteps assetBaseURL={assetBaseURL} items={blocks} />
            </Section>
          </Column></Row>
        </Section>
      }
    >
      <EmailFacts items={[
        { label: "File", value: fileName },
        { label: "Format", value: formatLabel },
        { label: "Size", value: fileSizeLabel },
        { label: "Prepared", value: preparedAtLabel },
      ]} />
    </EmailMessage>
  );
}

RequestedWorkoutReadyEmail.PreviewProps = {
  ...previewLinks,
  workoutTitle: "Bodyweight foundations",
  fileName: "sample-bodyweight-foundations.pdf",
  formatLabel: "PDF workout",
  fileSizeLabel: "640 KB",
  preparedAtLabel: "22 Oct 2026 · 10:08 UTC",
  accessLabel: "Preview availability: 24 hours after preparation. The preview action opens the local design reference.",
  blocks: [
    { icon: "activity", label: "Warm-up", detail: "Easy movement and range of motion." },
    { icon: "dumbbell", label: "Main set", detail: "Push-ups, squats and controlled holds." },
    { icon: "pause", label: "Finish", detail: "Rest and review the plan notes." },
  ],
} satisfies RequestedWorkoutReadyProps;
