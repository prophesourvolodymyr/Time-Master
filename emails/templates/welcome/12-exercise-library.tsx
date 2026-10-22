import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailFeatures, EmailMessage, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface ExerciseLibraryProps extends EmailLinks {
  marketing: MarketingFooter;
}

const pages = [
  { icon: "folder", label: "Library folders", detail: "Give related pages a home.", nested: false },
  { icon: "dumbbell", label: "Exercise", detail: "Timing, notes and media.", nested: true },
  { icon: "book-open", label: "Skill or tutorial", detail: "Instructions worth keeping.", nested: true },
] as const;
const capabilities = [
  { icon: "layers", label: "Organize", detail: "Group related pages." },
  { icon: "clipboard-list", label: "Use in a plan", detail: "Add content to a workout." },
] as const;

export default function ExerciseLibraryEmail({ marketing, ...links }: ExerciseLibraryProps) {
  const assets = links.assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      {...links}
      marketing={marketing}
      category="Getting started"
      headerDetail="Exercise library"
      previewText="Keep exercise instructions, links and media beside the plan."
      icon="library"
      title="Keep the how close."
      intro="Keep instructions, links and reference media with the page. Add exercise, skill or tutorial pages to your workout."
      actionLabel="Explore the library guide"
      visual={
        <Section style={tree}>
          {pages.map(({ icon, label, detail, nested }) => (
            <Row key={label}>
              <Column width={nested ? 24 : 4} style={{ borderLeft: nested ? `2px solid ${theme.colors.border}` : undefined }} />
              <Column width="38" style={{ padding: "12px 10px 12px 0", verticalAlign: "top" }}>
                <Img src={`${assets}/${icon}.png`} width={24} height={24} alt="" aria-hidden="true" style={{ display: "block" }} />
              </Column>
              <Column style={{ padding: "10px 0", verticalAlign: "top" }}>
                <Text style={labelStyle}>{label}</Text>
                <Text style={detailStyle}>{detail}</Text>
              </Column>
            </Row>
          ))}
        </Section>
      }
    >
      <EmailFeatures assetBaseURL={links.assetBaseURL} items={capabilities} />
    </EmailMessage>
  );
}

ExerciseLibraryEmail.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
} satisfies ExerciseLibraryProps;

const tree: CSSProperties = {
  marginBottom: theme.space.section, padding: theme.space.inset,
  backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`,
  borderRadius: theme.radius.card,
};
const labelStyle: CSSProperties = {
  margin: "0 0 3px", color: theme.colors.text, fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: "21px",
};
const detailStyle: CSSProperties = {
  margin: 0, color: theme.colors.secondaryText, fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption, lineHeight: "18px",
};
