import type { EmailLinks, MarketingFooter } from "./email-message";

export const previewLinks = {
  assetBaseURL: "/static",
  actionURL: "http://localhost:3002/preview/workspace-preview",
  preview: true,
} satisfies EmailLinks;

export const previewMarketing = {
  postalAddress: "Design preview — sender postal address must be configured before delivery.",
  unsubscribeURL: "http://localhost:3002/preview/workspace-preview",
  preferencesURL: "http://localhost:3002/preview/workspace-preview",
} satisfies MarketingFooter;
