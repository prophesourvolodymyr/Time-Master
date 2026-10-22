import type { CSSProperties } from "react";
import { Column, Img, Row, Section, Text } from "react-email";
import { EmailMessage, EmailSteps, type EmailLinks, type MarketingFooter } from "../../components/email-message";
import { previewLinks, previewMarketing } from "../../components/email-preview";
import { theme } from "../../theme";

interface LibraryOrganizationLessonProps extends EmailLinks {
  marketing: MarketingFooter;
  subscriptionContext: string;
}

export default function LibraryOrganizationLesson({ assetBaseURL, actionURL, preview, marketing, subscriptionContext }: LibraryOrganizationLessonProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");
  return (
    <EmailMessage
      assetBaseURL={assetBaseURL}
      actionURL={actionURL}
      preview={preview}
      marketing={marketing}
      category="Short lesson"
      headerDetail="Library organization"
      previewText="A simple hierarchy makes your exercise library easier to navigate."
      icon="folder"
      title="Give each exercise a home."
      intro="Start with a useful group, then add a level only when it helps. Clear names do the rest."
      actionLabel="Explore library organization"
      note={subscriptionContext}
      visual={
        <Section style={{ backgroundColor: theme.colors.raisedSurface, border: `1px solid ${theme.colors.border}`, borderRadius: theme.radius.card, marginBottom: theme.space.section, padding: theme.space.inset }}>
          <Text style={{ color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "0 0 12px" }}>A simple library structure</Text>
          <Row>
            <Column width="36" style={iconCell}><Img src={`${assets}/folder.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} /></Column>
            <Column><Text style={label}>Folder</Text><Text style={detail}>One clear group.</Text></Column>
          </Row>
          <Section style={{ borderLeft: `1px solid ${theme.colors.border}`, marginLeft: 12, paddingLeft: 20, marginTop: 12 }}>
            <Row>
              <Column width="36" style={iconCell}><Img src={`${assets}/folder.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} /></Column>
              <Column><Text style={label}>Subfolder</Text><Text style={detail}>A useful second level.</Text></Column>
            </Row>
            <Section style={{ borderLeft: "1px solid #484038", marginLeft: 12, paddingLeft: 20, marginTop: 12 }}>
              <Row>
                <Column width="36" style={iconCell}><Img src={`${assets}/file-text.png`} alt="" aria-hidden="true" width={24} height={24} style={{ display: "block" }} /></Column>
                <Column><Text style={label}>Exercise page</Text><Text style={detail}>The item you’ll recognize in a workout.</Text></Column>
              </Row>
            </Section>
          </Section>
        </Section>
      }
    >
      <EmailSteps assetBaseURL={assetBaseURL} items={[
        { icon: "folder", label: "Group by how you search", detail: "Choose names that match how you search: equipment, movement or routine." },
        { icon: "file-text", label: "Keep the names useful", detail: "Give each exercise page a clear name. Use subfolders when a group becomes hard to scan." },
      ]} />
    </EmailMessage>
  );
}

LibraryOrganizationLesson.PreviewProps = {
  ...previewLinks,
  marketing: previewMarketing,
  subscriptionContext: "Sample preference: short lessons enabled.",
} satisfies LibraryOrganizationLessonProps;

const iconCell: CSSProperties = { verticalAlign: "top", paddingTop: 3 };
const label: CSSProperties = { color: theme.colors.text, fontFamily: theme.headingFontFamily, fontWeight: theme.fontWeight.black, fontSize: theme.fontSize.secondary, lineHeight: 1.5, margin: 0 };
const detail: CSSProperties = { color: theme.colors.secondaryText, fontFamily: theme.fontFamily, fontSize: theme.fontSize.caption, lineHeight: 1.5, margin: "3px 0 0" };
