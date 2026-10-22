import type { CSSProperties } from "react";
import { Column, Heading, Img, Row, Section, Text } from "react-email";
import { EmailAction } from "./email-frame";
import { theme } from "../theme";

export function EmailWelcome({ assetBaseURL, actionURL }: { assetBaseURL: string; actionURL: string }) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <Section>
      <Row>
        <Column className="tmax-welcome-copy" width="55%" style={{ verticalAlign: "middle" }}>
          <Heading as="h1" style={headline}>Your time.<br />Your training.</Heading>
          <Text style={introduction}>Build a workout. Find a route. Make it yours.</Text>
          <EmailAction href={actionURL} iconSrc={`${assets}/arrow-up-right.png`} align="left">Get started</EmailAction>
        </Column>
        <Column className="tmax-welcome-art" width="45%" style={{ verticalAlign: "middle" }}>
          <Img src={`${assets}/welcome-athlete.png`} alt="The app's training character in orange and black sportswear"
            width={240} height={360} style={{ display: "block", width: "100%", maxWidth: 240, height: "auto", marginLeft: "auto" }} />
        </Column>
      </Row>
      <Text style={localFirst}>Train on-device. Sync your exercise library only if you choose.</Text>
    </Section>
  );
}

const headline: CSSProperties = {
  fontFamily: theme.headingFontFamily,
  fontWeight: theme.fontWeight.black,
  color: theme.colors.text,
  fontSize: 36,
  lineHeight: "40px",
  letterSpacing: "-1.2px",
  margin: "0 0 16px",
};
const introduction: CSSProperties = {
  fontFamily: theme.fontFamily,
  color: theme.colors.secondaryText,
  fontSize: theme.fontSize.body,
  lineHeight: "25px",
  maxWidth: 300,
  margin: "0 0 24px",
};
const localFirst: CSSProperties = {
  fontFamily: theme.fontFamily,
  color: theme.colors.secondaryText,
  fontSize: theme.fontSize.caption,
  lineHeight: "20px",
  borderTop: `1px solid ${theme.colors.border}`,
  paddingTop: theme.space.inset,
  margin: `${theme.space.section}px 0 0`,
};
