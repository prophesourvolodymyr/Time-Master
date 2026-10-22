import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { theme } from "../theme";

export interface EmailHeaderInfo {
  category: string;
  detail: string;
}

export function EmailHeader({ assetBaseURL, category, detail }: EmailHeaderInfo & { assetBaseURL: string }) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <Section style={header}>
      <Row>
        <Column width="44" style={{ verticalAlign: "middle" }}>
          <Img src={`${assets}/tmax-logo.png`} alt="Tmax" width={44} height={44}
            style={{ display: "block", borderRadius: 12 }} />
        </Column>
        <Column style={{ paddingLeft: theme.space.stack, verticalAlign: "middle" }}>
          <Text style={wordmark}>Tmax</Text>
        </Column>
        <Column style={{ textAlign: "right", verticalAlign: "middle", width: "45%" }}>
          <Text style={categoryStyle}>{category}</Text>
          <Text style={detailStyle}>{detail}</Text>
        </Column>
      </Row>
    </Section>
  );
}

const header: CSSProperties = {
  borderBottom: `1px solid ${theme.colors.border}`,
  paddingBottom: theme.space.inset,
  marginBottom: theme.space.section,
};
const wordmark: CSSProperties = {
  fontFamily: theme.accentFontFamily,
  color: theme.colors.text,
  fontSize: 31,
  fontWeight: theme.fontWeight.regular,
  lineHeight: "38px",
  margin: 0,
};
const categoryStyle: CSSProperties = {
  fontFamily: theme.headingFontFamily,
  color: theme.colors.text,
  fontSize: theme.fontSize.caption,
  fontWeight: theme.fontWeight.black,
  lineHeight: "18px",
  margin: 0,
};
const detailStyle: CSSProperties = {
  fontFamily: theme.fontFamily,
  color: theme.colors.secondaryText,
  fontSize: theme.fontSize.micro,
  lineHeight: "17px",
  margin: "2px 0 0",
};
