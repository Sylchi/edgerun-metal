import { SiteHeader, SiteFooter } from "@/components/shared"
import {
  HeroSection,
  StatsSection,
  ProblemSection,
  PhilosophySection,
  ArchitectureSection,
  EnergySavingsSection,
  CTASection,
} from "@/components/landing"

export default function HomePage() {
  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <HeroSection />
        <StatsSection />
        <ProblemSection />
        <PhilosophySection />
        <ArchitectureSection />
        <EnergySavingsSection />
        <CTASection />
      </main>
      <SiteFooter />
    </div>
  )
}
