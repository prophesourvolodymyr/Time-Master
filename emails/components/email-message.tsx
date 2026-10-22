import type { CSSProperties, ReactNode } from "react";
import { Column, Heading, Img, Link, Row, Section, Text } from "react-email";
import { EmailAction, EmailCaption, EmailCard, EmailFrame } from "./email-frame";
import { EmailIcon } from "./email-icon";
import { theme } from "../theme";

export interface EmailLinks {
  assetBaseURL: string;
  actionURL: string;
  preview?: boolean;
}

export interface MarketingFooter {
  postalAddress: string;
  unsubscribeURL: string;
  preferencesURL: string;
}

interface EmailMessageProps extends EmailLinks {
  category: string;
  headerDetail: string;
  previewText: string;
  icon: string;
  title: string;
  intro: string;
  actionLabel: string;
  children?: ReactNode;
  visual?: ReactNode;
  note?: string;
  marketing?: MarketingFooter;
}

export function EmailMessage({ assetBaseURL, actionURL, preview, category, headerDetail, previewText,
  icon, title, intro, actionLabel, children, visual, note, marketing }: EmailMessageProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailFrame assetBaseURL={assetBaseURL} previewText={previewText} header={{ category, detail: headerDetail }}>
      <EmailCard>
        {visual ?? <EmailSymbol assetBaseURL={assetBaseURL} name={icon} />}
        <Heading as="h1" style={heading}>{title}</Heading>
        <Text style={introduction}>{intro}</Text>
        {children}
        <EmailAction href={actionURL} iconSrc={`${assets}/arrow-up-right.png`}>{actionLabel}</EmailAction>
        {note ? <Section style={{ textAlign: "center" }}><EmailCaption>{note}</EmailCaption></Section> : null}
      </EmailCard>
      {marketing ? (
        <Section style={footer}>
          <Text style={footerText}>You chose to receive these emails from Tmax.</Text>
          <Text style={footerText}>
            <Link href={marketing.preferencesURL} style={footerLink}>Email preferences</Link>
            {" · "}<Link href={marketing.unsubscribeURL} style={footerLink}>Unsubscribe</Link>
          </Text>
          <Text style={footerText}>{marketing.postalAddress}</Text>
        </Section>
      ) : null}
      {preview ? <Section style={{ textAlign: "center" }}>
        <EmailCaption>Design preview · Sample content · Not sent</EmailCaption>
      </Section> : null}
    </EmailFrame>
  );
}

export function EmailSymbol({ assetBaseURL, name }: { assetBaseURL: string; name: string }) {
  return (
    <Section style={{ marginBottom: theme.space.section }}>
      <table role="presentation" align="center" width="88" cellPadding="0" cellSpacing="0" style={symbolSurface}>
        <tbody><tr><td align="center" height="86" style={{ verticalAlign: "middle" }}>
          <Img src={`${assetBaseURL.replace(/\/+$/, "")}/${name}.png`} alt="" aria-hidden="true"
            width={40} height={40} style={{ display: "block", margin: "0 auto" }} />
        </td></tr></tbody>
      </table>
    </Section>
  );
}

export function EmailFacts({ items }: { items: readonly { label: string; value: string }[] }) {
  return <Section style={contentSection}>
    {items.map(({ label, value }) => <Row key={label} style={{ borderBottom: `1px solid ${theme.colors.border}` }}>
      <Column style={{ ...smallText, padding: "10px 8px 10px 0", width: "40%", verticalAlign: "top" }}>{label}</Column>
      <Column style={{ ...strongText, padding: "10px 0", textAlign: "right", verticalAlign: "top", wordBreak: "break-word" }}>{value}</Column>
    </Row>)}
  </Section>;
}

export function EmailFeatures({ assetBaseURL, items }: {
  assetBaseURL: string;
  items: readonly { icon: string; label: string; detail: string }[];
}) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return <Section style={contentSection}><Row style={{ tableLayout: "fixed" }}>
    {items.map(({ icon, label, detail }) => <Column key={label} width={`${100 / items.length}%`} style={{ verticalAlign: "top", textAlign: "center", padding: "0 2px", wordBreak: "break-word" }}>
      <EmailIcon src={`${assets}/${icon}.png`} label={label} detail={detail} />
    </Column>)}
  </Row></Section>;
}

export function EmailStats({ items }: { items: readonly { label: string; value: string; unit?: string }[] }) {
  return <Section style={contentSection}><Row style={{ tableLayout: "fixed" }}>
    {items.map(({ label, value, unit }) => <Column key={label} width={`${100 / items.length}%`} style={{ textAlign: "center", padding: "12px 3px", verticalAlign: "top", wordBreak: "break-word" }}>
      <Text style={{ ...strongText, fontSize: 28, lineHeight: "34px", margin: 0 }}>{value}</Text>
      {unit ? <Text style={{ ...smallText, margin: "2px 0" }}>{unit}</Text> : null}
      <Text style={{ ...smallText, margin: "4px 0 0" }}>{label}</Text>
    </Column>)}
  </Row></Section>;
}

export function EmailProgress({ label, value, fraction }: { label: string; value: string; fraction: number }) {
  const percent = Math.round(Math.min(1, Math.max(0, fraction)) * 100);
  return <Section style={contentSection}>
    <Row><Column style={smallText}>{label}</Column><Column style={{ ...strongText, textAlign: "right" }}>{value}</Column></Row>
    <table role="presentation" width="100%" cellPadding="0" cellSpacing="0" style={{ marginTop: 10, backgroundColor: theme.colors.raisedSurface, borderRadius: 4 }}>
      <tbody><tr><td height="8" style={{ width: `${percent}%`, backgroundColor: percent ? theme.colors.accent : "transparent", borderRadius: 4 }} />
        {percent < 100 ? <td height="8" style={{ width: `${100 - percent}%` }} /> : null}</tr></tbody>
    </table>
  </Section>;
}

export function EmailSteps({ assetBaseURL, items }: {
  assetBaseURL: string;
  items: readonly { icon: string; label: string; detail: string }[];
}) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return <Section style={contentSection}>
    {items.map(({ icon, label, detail }) => <Row key={label}>
      <Column width="36" style={{ verticalAlign: "top", padding: "10px 8px 10px 0" }}>
        <Img src={`${assets}/${icon}.png`} width={24} height={24} alt="" aria-hidden="true" style={{ display: "block" }} />
      </Column>
      <Column style={{ padding: "8px 0" }}><Text style={{ ...strongText, margin: "0 0 3px" }}>{label}</Text>
        <Text style={{ ...smallText, margin: 0 }}>{detail}</Text></Column>
    </Row>)}
  </Section>;
}

export function EmailNotice({ title, children }: { title: string; children: ReactNode }) {
  return <Section style={{ ...contentSection, backgroundColor: theme.colors.raisedSurface, borderRadius: 12 }}>
    <Row><Column style={{ padding: 12 }}>
      <Text style={{ ...strongText, margin: "0 0 4px" }}>{title}</Text>
      <Text style={{ ...smallText, margin: 0 }}>{children}</Text>
    </Column></Row>
  </Section>;
}

const heading: CSSProperties = {
  fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black,
  fontSize: theme.fontSize.display, lineHeight: theme.lineHeight.title,
  color: theme.colors.text, textAlign: "center", margin: "0 0 12px",
};
const introduction: CSSProperties = {
  fontFamily: theme.fontFamily, fontSize: theme.fontSize.secondary, lineHeight: "22px",
  color: theme.colors.secondaryText, textAlign: "center", margin: "0 0 24px",
};
const symbolSurface: CSSProperties = {
  backgroundColor: theme.colors.raisedSurface, border: "1px solid #484038", borderCollapse: "separate",
  borderRadius: 26, backgroundImage: "linear-gradient(145deg,rgba(255,106,0,0.16),rgba(255,106,0,0))",
};
const contentSection: CSSProperties = { margin: "0 0 24px" };
const smallText: CSSProperties = {
  fontFamily: theme.fontFamily, fontWeight: theme.fontWeight.regular,
  fontSize: theme.fontSize.caption, lineHeight: "19px", color: theme.colors.secondaryText,
};
const strongText: CSSProperties = {
  fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black,
  fontSize: theme.fontSize.secondary, lineHeight: "21px", color: theme.colors.text,
};
const footer: CSSProperties = { marginTop: 16, textAlign: "center" };
const footerText: CSSProperties = { ...smallText, fontSize: 11, lineHeight: "18px", margin: "4px 0" };
const footerLink: CSSProperties = { color: theme.colors.secondaryText, textDecoration: "underline" };
