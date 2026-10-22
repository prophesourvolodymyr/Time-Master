import type { CSSProperties, ReactNode } from "react";
import { Body, Button, Column, Container, Head, Html, Img, Preview, Row, Section, Text } from "react-email";
import { theme } from "../theme";
import { EmailFonts } from "./email-fonts";

interface EmailFrameProps {
  previewText: string;
  assetBaseURL: string;
  children: ReactNode;
}

export function EmailFrame({ previewText, assetBaseURL, children }: EmailFrameProps) {
  const assets = assetBaseURL.replace(/\/$/, "");
  return (
    <Html lang="en">
      <Head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme" content="dark" />
        <meta name="supported-color-schemes" content="dark" />
        <EmailFonts assetBaseURL={assetBaseURL} />
      </Head>
      <Preview>{previewText}</Preview>
      <Body style={body}>
        <Container style={container}>
          <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
            <Img src={`${assets}/tmax-logo.png`} alt="Tmax app logo" width={224} height={224}
              style={{ display: "block", margin: "0 auto", maxWidth: "100%", height: "auto", borderRadius: theme.radius.card }} />
            <Text style={wordmark}>Tmax</Text>
          </Section>
          {children}
        </Container>
      </Body>
    </Html>
  );
}

export function EmailCard({ children }: { children: ReactNode }) {
  return (
    <Section style={card}>
      <Row>
        <Column style={{ padding: theme.space.inset }}>{children}</Column>
      </Row>
    </Section>
  );
}


export function EmailAction({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Button href={href} style={action}>
      {children}
    </Button>
  );
}

export function EmailCaption({ children }: { children: ReactNode }) {
  return <Text style={caption}>{children}</Text>;
}

const body: CSSProperties = {
  backgroundColor: theme.colors.background,
  color: theme.colors.text,
  fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.body,
  fontWeight: theme.fontWeight.regular,
  lineHeight: theme.lineHeight.body,
  margin: 0,
  padding: theme.space.inset,
};

const container: CSSProperties = {
  maxWidth: theme.readableWidth,
  margin: "0 auto",
  width: "100%",
};

const card: CSSProperties = {
  backgroundColor: theme.colors.surface,
  border: `1px solid ${theme.colors.border}`,
  borderCollapse: "separate",
  borderRadius: theme.radius.card,
};

const action: CSSProperties = {
  backgroundColor: theme.colors.accent,
  borderRadius: theme.radius.button,
  color: theme.colors.onAccent,
  display: "block",
  boxSizing: "border-box",
  fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.label,
  fontWeight: theme.fontWeight.black,
  lineHeight: "24px",
  padding: `10px ${theme.space.inset}px`,
  textAlign: "center",
  textDecoration: "none",
};

const caption: CSSProperties = {
  color: theme.colors.secondaryText,
  fontFamily: theme.fontFamily,
  fontWeight: theme.fontWeight.regular,
  fontSize: theme.fontSize.caption,
  lineHeight: theme.lineHeight.caption,
  margin: `${theme.space.stack}px 0 0`,
};

const wordmark: CSSProperties = {
  color: theme.colors.text,
  fontFamily: theme.accentFontFamily,
  fontSize: theme.fontSize.accentTitle,
  fontWeight: theme.fontWeight.regular,
  lineHeight: theme.lineHeight.accentTitle,
  margin: `${theme.space.stack}px 0 0`,
};


