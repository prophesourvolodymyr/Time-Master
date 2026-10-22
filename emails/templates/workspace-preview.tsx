import type { CSSProperties } from "react";
import { Column, Heading, Row, Section, Text } from "react-email";
import { EmailAction, EmailCaption, EmailCard, EmailFrame } from "../components/email-frame";
import { EmailIcon } from "../components/email-icon";
import { theme } from "../theme";

interface WorkspacePreviewProps {
  assetBaseURL?: string;
  previewURL?: string;
}

const capabilities = [
  { icon: "dumbbell", label: "Train", detail: "Workouts" },
  { icon: "timer", label: "Focus", detail: "Timers" },
  { icon: "route", label: "Explore", detail: "Routes" },
] as const;

export default function WorkspacePreview({
  assetBaseURL = "/static",
  previewURL = "http://localhost:3002",
}: WorkspacePreviewProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");

  return (
    <EmailFrame assetBaseURL={assetBaseURL} previewText="Workouts, timers, and routes. At your pace.">
      <EmailCard>
        <Heading as="h1" style={headline}>Made to move.</Heading>
        <Text style={introduction}>Workouts, timers, and routes. At your pace.</Text>
        <Section style={capabilityStrip}>
          <Row style={{ tableLayout: "fixed" }}>
            {capabilities.map(({ icon, label, detail }) => (
              <Column key={icon} width="33.33%" style={capabilityColumn}>
                <EmailIcon src={`${assets}/${icon}.png`} label={label} detail={detail} />
              </Column>
            ))}
          </Row>
        </Section>
        <EmailAction href={previewURL} iconSrc={`${assets}/arrow-up-right.png`}>
          Open preview
        </EmailAction>
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

const headline: CSSProperties = {
  color: theme.colors.text,
  fontFamily: theme.headingFontFamily,
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


const capabilityStrip: CSSProperties = {
  margin: `0 0 ${theme.space.section}px`,
};

const capabilityColumn: CSSProperties = {
  textAlign: "center",
  verticalAlign: "top",
};
