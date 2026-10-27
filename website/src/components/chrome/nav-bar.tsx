"use client";

import { useRef, useState, type MouseEvent } from "react";
import { DownloadSimpleIcon, ListIcon } from "@phosphor-icons/react";
import { ActionButton, GlassSurface, IconButton } from "@/components/ui";
import { useChapter } from "@/components/providers/chapter";
import { useIsImmersive } from "@/components/providers/immersive";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { ScrollTrigger, useGSAP } from "@/lib/gsap";
import { MobileMenu } from "./mobile-menu";
import { navLinks, useFollowLink } from "./nav-links";
import { TmaxMark } from "./tmax-mark";
import styles from "./nav-bar.module.css";

export function NavBar() {
  const headerRef = useRef<HTMLElement>(null);
  const [scrolled, setScrolled] = useState(false);
  const [section, setSection] = useState<"chapter" | "stats" | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const immersive = useIsImmersive();
  const { chapter } = useChapter();
  const follow = useFollowLink();
  const { scrollTo } = useSmoothScroll();

  useGSAP(
    () => {
      ScrollTrigger.create({ start: 32, end: "max", onToggle: (self) => setScrolled(self.isActive) });
      for (const id of ["chapter", "stats"] as const) {
        ScrollTrigger.create({
          trigger: `#${id}`,
          start: "top center",
          end: "bottom center",
          onToggle: (self) => setSection((current) => (self.isActive ? id : current === id ? null : current)),
        });
      }
    },
    { scope: headerRef },
  );

  const goHome = (event: MouseEvent<HTMLAnchorElement>) => {
    event.preventDefault();
    scrollTo(0, { duration: 1.6 });
  };

  return (
    <>
      <a href="#main" className={styles.skip}>
        Skip to content
      </a>
      <header
        ref={headerRef}
        className={styles.header}
        data-scrolled={scrolled || undefined}
        data-hidden={(immersive && !menuOpen) || undefined}
      >
        <GlassSurface className={styles.backdrop} />
        <nav aria-label="Primary" className="relative mx-auto flex h-full max-w-[1400px] items-center justify-between px-5 md:px-8">
          <a href="#top" onClick={goHome} aria-label="Tmax, back to the top" className="rounded-chip p-1 text-ink">
            <TmaxMark className="h-7 w-auto" />
          </a>
          <div className="hidden items-center gap-8 md:flex">
            <ul className="flex items-center gap-7">
              {navLinks.map((link) => (
                <li key={link.label}>
                  <button type="button" className={styles.link} aria-current={("chapter" in link ? section === "chapter" && chapter === link.chapter : section === "stats") || undefined} onClick={() => follow(link)}>
                    {link.label}
                  </button>
                </li>
              ))}
            </ul>
            <ActionButton prominent font="text" icon={<DownloadSimpleIcon weight="bold" />} onClick={() => scrollTo("#choose", { duration: 1.6 })}>
              Install
            </ActionButton>
          </div>
          <IconButton className="md:hidden" label="Open menu" icon={<ListIcon size={22} weight="bold" />} onClick={() => setMenuOpen(true)} />
        </nav>
      </header>
      <MobileMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        onNavigate={(link) => {
          setMenuOpen(false);
          follow(link);
        }}
      />
    </>
  );
}
