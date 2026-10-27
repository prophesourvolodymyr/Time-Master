"use client";

import { ArrowUpIcon } from "@phosphor-icons/react";
import { BorderSlide } from "@/components/motion/border-slide";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { IconButton } from "@/components/ui";
import { chapters, downloads, site } from "@/lib/site";
import { useFollowLink, type NavLink } from "./nav-links";

const buildYear = new Date().getFullYear();

const productLinks: readonly NavLink[] = [
  ...chapters.map((chapter) => ({ label: chapter.title, chapter: chapter.id })),
  { label: "Stats", target: "#stats" },
];

const heading = "mb-4 font-display text-[13px] font-black tracking-wide text-ink-3 uppercase";
const linkStyle = "font-display text-[17px] font-black text-ink-2 transition-colors hover:text-ink";

export function Footer() {
  const follow = useFollowLink();
  const { scrollTo } = useSmoothScroll();

  return (
    <footer id="footer" className="relative overflow-clip border-t border-line pt-16">
      <div className="mx-auto max-w-[1400px] px-5 md:px-8">
        <div className="grid gap-12 sm:grid-cols-2 lg:grid-cols-4">
          <nav aria-label="Product">
            <h2 className={heading}>Product</h2>
            <ul className="flex flex-col gap-3">
              {productLinks.map((link) => (
                <li key={link.label}>
                  <button type="button" className={linkStyle} onClick={() => follow(link)}>
                    {link.label}
                  </button>
                </li>
              ))}
            </ul>
          </nav>
          <nav aria-label="Get the app">
            <h2 className={heading}>Get the app</h2>
            <ul className="flex flex-col gap-3">
              {downloads.map((download) => (
                <li key={download.id}>
                  {download.href ? (
                    <a href={download.href} rel="noopener" className={linkStyle}>
                      {download.label}
                    </a>
                  ) : (
                    <span className="font-display text-[17px] font-black text-ink-3" aria-disabled="true">
                      {download.label} <span className="font-body text-[13px] font-normal">Coming soon</span>
                    </span>
                  )}
                </li>
              ))}
            </ul>
          </nav>
          {site.contactEmail ? (
            <div>
              <h2 className={heading}>Contact</h2>
              <a href={`mailto:${site.contactEmail}`} className={linkStyle}>
                {site.contactEmail}
              </a>
            </div>
          ) : null}
          <p className="max-w-[34ch] text-[14px] text-ink-2 lg:col-start-4">{site.promo.sentence}</p>
        </div>
      </div>
      <BorderSlide from="bottom" className="mt-16 select-none" innerClassName="flex justify-center">
        <p
          aria-hidden="true"
          className="bg-[linear-gradient(100deg,#7d776e_0%,#f4efe6_38%,#a9a196_55%,#fbf8f2_78%,#8c867c_100%)] bg-clip-text pb-[0.08em] font-ribbon text-[clamp(120px,30vw,460px)] leading-[0.82] text-transparent"
        >
          Tmax
        </p>
      </BorderSlide>
      <div className="mx-auto flex max-w-[1400px] items-center justify-between border-t border-line px-5 py-6 md:px-8">
        <p className="text-[13px] text-ink-3">© {buildYear} Tmax. All rights reserved.</p>
        <IconButton label="Back to the top" icon={<ArrowUpIcon size={20} weight="bold" />} onClick={() => scrollTo(0, { duration: 1.8 })} />
      </div>
    </footer>
  );
}
