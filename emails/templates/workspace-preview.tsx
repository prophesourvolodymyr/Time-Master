import type { CSSProperties } from "react";
import { Heading, Section, Text } from "react-email";
import { EmailAction, EmailCaption, EmailCard, EmailFrame } from "../components/email-frame";
import { theme } from "../theme";

interface WorkspacePreviewProps {
  assetBaseURL?: string;
  previewURL?: string;
}

export default function WorkspacePreview({
  assetBaseURL = "/static",
  previewURL = "http://localhost:3002",
}: WorkspacePreviewProps) {
  return (
    <EmailFrame assetBaseURL={assetBaseURL} previewText="Your training. Your way.">
      <EmailCard>
        <Heading as="h1" style={pageTitle}>Made to move.</Heading>
        <Text style={introduction}>Your training. Your way.</Text>
        <EmailAction href={previewURL}>Open preview</EmailAction>
      </EmailCard>
      <Section style={{ textAlign: "center" }}>
        <EmailCaption>Local design preview</EmailCaption>
      </Section>
    </EmailFrame>
  );
}

WorkspacePreview.PreviewProps = {
  assetBaseURL: "/static",
  previewURL: "http://localhost:3002",
} satisfies WorkspacePreviewProps;

const pageTitle: CSSProperties = {
  color: theme.colors.text,
  fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.display,
  fontWeight: theme.fontWeight.black,
  lineHeight: theme.lineHeight.title,
  margin: `0 0 ${theme.space.stack}px`,
  textAlign: "center",
};

const introduction: CSSProperties = {
  color: theme.colors.secondaryText,
  fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.body,
  fontWeight: theme.fontWeight.regular,
  lineHeight: theme.lineHeight.body,
  margin: `0 0 ${theme.space.section}px`,
  textAlign: "center",
};

