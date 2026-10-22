interface EmailFontsProps {
  assetBaseURL: string;
}

export function EmailFonts({ assetBaseURL }: EmailFontsProps) {
  const assets = assetBaseURL.replace(/\/+$/, "");

  return (
    <style>{`
      @font-face {
        font-family: "Inter";
        font-style: normal;
        font-weight: 400;
        mso-font-alt: "Arial";
        src: url(${JSON.stringify(`${assets}/Inter-Regular.ttf`)}) format("truetype");
      }
      @font-face {
        font-family: "Inter";
        font-style: normal;
        font-weight: 900;
        mso-font-alt: "Arial";
        src: url(${JSON.stringify(`${assets}/Inter-Black.ttf`)}) format("truetype");
      }
      @font-face {
        font-family: "TmaxRibbon";
        font-style: normal;
        font-weight: 400;
        mso-font-alt: "Arial";
        src: url(${JSON.stringify(`${assets}/TmaxRibbon-Regular.ttf`)}) format("truetype");
      }
    `}</style>
  );
}
