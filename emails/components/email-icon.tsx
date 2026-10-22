import type { CSSProperties } from "react";
import { Img, Section, Text } from "react-email";
import { theme } from "../theme";

interface EmailIconProps {
  src: string;
  label: string;
  detail: string;
}

export function EmailIcon({ src, label, detail }: EmailIconProps) {
  return (
    <Section style={{ textAlign: "center" }}>
      <table role="presentation" align="center" width="56" cellPadding="0" cellSpacing="0" style={iconSurface}>
        <tbody>
          <tr>
            <td align="center" height="54" style={{ verticalAlign: "middle" }}>
              <Img src={src} alt="" aria-hidden="true" width={28} height={28} style={icon} />
            </td>
          </tr>
        </tbody>
      </table>
      <Text style={capabilityLabel}>{label}</Text>
      <Text style={capabilityDetail}>{detail}</Text>
    </Section>
  );
}

const iconSurface: CSSProperties = {
  backgroundColor: theme.colors.raisedSurface,
  border: `1px solid ${theme.colors.border}`,
  borderCollapse: "separate",
  borderRadius: theme.radius.button,
  margin: "0 auto",
};

const icon: CSSProperties = {
  display: "block",
  margin: "0 auto",
};

const capabilityLabel: CSSProperties = {
  color: theme.colors.text,
  fontFamily: theme.headingFontFamily,
  fontSize: theme.fontSize.rowTitle,
  fontWeight: theme.fontWeight.black,
  lineHeight: theme.lineHeight.rowTitle,
  margin: `${theme.space.stack}px 0 2px`,
};

const capabilityDetail: CSSProperties = {
  color: theme.colors.secondaryText,
  fontFamily: theme.fontFamily,
  fontSize: theme.fontSize.caption,
  fontWeight: theme.fontWeight.regular,
  lineHeight: theme.lineHeight.caption,
  margin: 0,
};
