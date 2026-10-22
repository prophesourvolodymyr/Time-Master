import type { CSSProperties, ReactNode } from "react";
import { Body, Button, Column, Container, Head, Html, Img, Preview, Row, Section, Text } from "react-email";
import { theme } from "../theme";
import { EmailFonts } from "./email-fonts";

interface EmailFrameProps {
  previewText: string;
  assetBaseURL: string;
  children: ReactNode;
}

interface EmailActionProps {
  href: string;
  iconSrc?: string;
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
        <style>{`
          .tmax-email-action:focus {
            outline: 2px solid #E6D1C1;
            outline-offset: 3px;
          }
          @media (prefers-contrast: more) {
            .tmax-email-action {
              border-color: #BC8157 !important;
              background-image: none !important;
            }
          }
          @media (prefers-reduced-transparency: reduce) {
            .tmax-email-action {
              background-image: none !important;
            }
          }
        `}</style>
      </Head>
      <Preview>{previewText}</Preview>
      <Body style={body}>
        <Container style={container}>
          <Section style={{ marginBottom: theme.space.section, textAlign: "center" }}>
            <Img src={`${assets}/tmax-logo.png`} alt="Tmax app logo" width={64} height={64}
              style={{ display: "block", margin: "0 auto", maxWidth: "100%", height: "auto", borderRadius: theme.radius.button }} />
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

export function EmailAction({ href, iconSrc, children }: EmailActionProps) {
  return (
    <Section style={{ textAlign: "center" }}>
      <Button href={href} className="tmax-email-action" style={action}>
        <span style={{ lineHeight: "24px", verticalAlign: "middle" }}>{children}</span>
        {iconSrc ? (
          <Img
            src={iconSrc}
            alt=""
            aria-hidden="true"
            width={20}
            height={20}
            style={{ display: "inline-block", marginLeft: theme.space.small, verticalAlign: "middle" }}
          />
        ) : null}
      </Button>
    </Section>
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
  width: "100%",
};

const action: CSSProperties = {
  backgroundColor: "#9C4608",
  backgroundImage: "linear-gradient(180deg, rgba(255,255,255,0.06) 0%, rgba(255,255,255,0.02) 44%, rgba(0,0,0,0.07) 100%)",
  border: "1px solid #AE6734",
  borderRadius: theme.radius.button,
  boxShadow: "inset 0 1px 0 rgba(255,255,255,0.12), inset 0 -1px 0 rgba(0,0,0,0.14), 0 2px 4px rgba(0,0,0,0.18)",
  color: theme.colors.text,
  display: "inline-block",
  boxSizing: "border-box",
  fontFamily: theme.headingFontFamily,
  fontSize: theme.fontSize.label,
  fontWeight: theme.fontWeight.black,
  lineHeight: "24px",
  minHeight: 52,
  padding: `13px ${theme.space.inset}px`,
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


