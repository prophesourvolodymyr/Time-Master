import { Footer } from "@/components/chrome/footer";
import { NavBar } from "@/components/chrome/nav-bar";
import { ChoiceSection } from "@/sections/choice";
import { FilmSection } from "@/sections/film";
import { StatsSection } from "@/sections/stats";

export default function Home() {
  return (
    <>
      <NavBar />
      <main id="main">
        <FilmSection />
        <ChoiceSection />
        <StatsSection />
      </main>
      <Footer />
    </>
  );
}
