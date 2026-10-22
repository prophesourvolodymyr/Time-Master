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
        <Column style={{ verticalAlign: "middle" }}>
          <Img src={`${assets}/brand-mark.png`} alt="Tmax" width={48} height={32}
            style={{ display: "block", height: "auto" }} />
        </Column>
        <Column style={{ textAlign: "right", verticalAlign: "middle" }}>
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
const categoryStyle: CSSProperties = {
  fontFamily: theme.fontFamily,
  color: theme.colors.text,
  fontSize: theme.fontSize.caption,
  fontWeight: theme.fontWeight.regular,
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
