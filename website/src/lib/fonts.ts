import localFont from "next/font/local";

export const manrope = localFont({
  src: "../fonts/Manrope-Regular.woff2",
  weight: "400",
  style: "normal",
  display: "swap",
  variable: "--ff-manrope",
});

export const inter = localFont({
  src: [
    { path: "../fonts/Inter-Black.woff2", weight: "900", style: "normal" },
    { path: "../fonts/Inter-BlackItalic.woff2", weight: "900", style: "italic" },
  ],
  display: "swap",
  variable: "--ff-inter",
});

export const ribbon = localFont({
  src: "../fonts/TimeMaster-Regular.woff2",
  weight: "400",
  style: "normal",
  display: "swap",
  preload: false,
  variable: "--ff-ribbon",
});

export const fontVariables = [manrope.variable, inter.variable, ribbon.variable].join(" ");
