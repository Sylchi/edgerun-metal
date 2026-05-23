"use client"

import Link from "next/link"
import { ArrowRight, Shield, Lock, Users, Globe, Terminal } from "lucide-react"
import { Button } from "@/components/ui/button"
import { NodeMap } from "./node-map"
import { BootSequence } from "./boot-sequence"
import { LiveStats, TrafficConcentration } from "./live-stats"
import { useState } from "react"

export function HeroSection() {
  const [bootComplete, setBootComplete] = useState(false)

  return (
    <section className="relative min-h-screen overflow-hidden">
      {/* Animated node map background */}
      <div className="absolute inset-0">
        <NodeMap />
      </div>

      {/* Gradient overlays */}
      <div className="absolute inset-0 bg-gradient-to-t from-background via-background/80 to-transparent" />
      <div className="absolute inset-0 bg-gradient-to-r from-background/90 via-transparent to-background/90" />

      {/* Content */}
      <div className="relative mx-auto max-w-7xl px-4 py-16 lg:px-8 lg:py-24">
        <div className="grid gap-12 lg:grid-cols-2 lg:gap-16 items-center min-h-[80vh]">
          {/* Left: Terminal with boot sequence */}
          <div className="order-2 lg:order-1">
            <div className="rounded-lg border border-border bg-card/95 backdrop-blur-sm overflow-hidden shadow-2xl">
              {/* Terminal header */}
              <div className="flex items-center gap-2 px-4 py-3 bg-muted/50 border-b border-border">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-500/80" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500/80" />
                  <div className="w-3 h-3 rounded-full bg-green-500/80" />
                </div>
                <span className="ml-2 text-xs text-muted-foreground font-mono">edgerun — node</span>
              </div>
              {/* Terminal content */}
              <div className="p-6 min-h-[300px]">
                <BootSequence onComplete={() => setBootComplete(true)} />
              </div>
            </div>
            
            {/* Connection hint */}
            {bootComplete && (
              <div className="mt-4 text-center lg:text-left animate-in fade-in slide-in-from-bottom-2 duration-500">
                <p className="text-sm text-muted-foreground">
                  Your node is running. Share your ID to connect with others — 
                  <span className="text-primary"> no account needed</span>.
                </p>
              </div>
            )}
          </div>

          {/* Right: Hero text */}
          <div className="order-1 lg:order-2 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-4 py-1.5 mb-6">
              <Terminal className="h-3.5 w-3.5 text-primary" />
              <span className="text-sm font-medium text-primary">Written in Zig. Zero dependencies.</span>
            </div>

            <h1 className="text-4xl font-bold tracking-tight text-foreground sm:text-5xl lg:text-6xl">
              Your Node is{" "}
              <span className="text-primary text-glow">Already Running</span>
            </h1>

            <p className="mt-6 text-lg text-muted-foreground leading-relaxed max-w-xl">
              No signup. No account. No middlemen. EdgeRun starts a node in your browser 
              the moment you arrive. Share your ID, connect directly, communicate privately.
            </p>

            <div className="mt-8 flex flex-col items-center lg:items-start gap-4 sm:flex-row">
              <Button size="lg" className="gap-2 glow-primary" asChild>
                <Link href="/docs">
                  Read the Docs
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <Button size="lg" variant="outline" asChild>
                <Link href="/apps">
                  Browse Apps
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

export function StatsSection() {
  return (
    <section className="border-t border-border bg-card/30">
      <div className="mx-auto max-w-7xl px-4 py-16 lg:px-8">
        <LiveStats />
      </div>
    </section>
  )
}

export function ProblemSection() {
  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-7xl px-4 py-24 lg:px-8">
        <div className="grid gap-16 lg:grid-cols-2 items-start">
          {/* Left: The problem */}
          <div>
            <div className="inline-block rounded bg-destructive/10 px-3 py-1 text-xs font-medium text-destructive mb-4">
              THE PROBLEM
            </div>
            <h2 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              {"The Web's"}
              <br />
              <span className="text-muted-foreground">Centralization Crisis</span>
            </h2>
            <p className="mt-4 text-muted-foreground leading-relaxed">
              Every message, every file, every connection — routed through corporate servers 
              that decrypt, inspect, and monetize your data. {"\"End-to-end encryption\""} means 
              nothing when the {"\"ends\""} are controlled by platforms.
            </p>
            
            <div className="mt-8 space-y-4">
              <div className="flex gap-4 items-start">
                <div className="flex-shrink-0 w-8 h-8 rounded-full bg-destructive/10 flex items-center justify-center">
                  <span className="text-destructive text-sm font-bold">1</span>
                </div>
                <div>
                  <h3 className="font-semibold text-foreground">TLS Termination</h3>
                  <p className="text-sm text-muted-foreground">
                    Every CDN, every load balancer decrypts your traffic. Your {"\"secure\""} 
                    connection is broken at every hop.
                  </p>
                </div>
              </div>
              <div className="flex gap-4 items-start">
                <div className="flex-shrink-0 w-8 h-8 rounded-full bg-destructive/10 flex items-center justify-center">
                  <span className="text-destructive text-sm font-bold">2</span>
                </div>
                <div>
                  <h3 className="font-semibold text-foreground">Identity Silos</h3>
                  <p className="text-sm text-muted-foreground">
                    Your identity exists at the pleasure of platforms. Banned? Deplatformed? 
                    Your digital life disappears.
                  </p>
                </div>
              </div>
              <div className="flex gap-4 items-start">
                <div className="flex-shrink-0 w-8 h-8 rounded-full bg-destructive/10 flex items-center justify-center">
                  <span className="text-destructive text-sm font-bold">3</span>
                </div>
                <div>
                  <h3 className="font-semibold text-foreground">Surveillance by Default</h3>
                  <p className="text-sm text-muted-foreground">
                    Metadata is data. Who you talk to, when, how often — all logged, analyzed, 
                    sold to the highest bidder.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Right: Traffic concentration viz */}
          <div className="rounded-xl border border-border bg-card p-8">
            <TrafficConcentration />
          </div>
        </div>
      </div>
    </section>
  )
}

export function PhilosophySection() {
  const principles = [
    {
      icon: Shield,
      title: "Identity-Routed Work",
      description: "Work is addressed by cryptographic identity. No trusted sessions. No central servers.",
      code: "send(peer_id, encrypted_payload)",
    },
    {
      icon: Lock,
      title: "Sealed Work Objects",
      description: "Data is encrypted at the source. No intermediary can read or modify it.",
      code: "seal(data, recipient_pubkey)",
    },
    {
      icon: Users,
      title: "User-Governed Resources",
      description: "Your devices, your rules. No platform decides what you run or who you connect with.",
      code: "policy.admit(request) -> bool",
    },
    {
      icon: Globe,
      title: "Local Admission Policy",
      description: "Each node decides what to accept. No remote gatekeepers. No censorship.",
      code: "node.set_policy(my_rules)",
    },
  ]

  return (
    <section className="border-t border-border bg-card/30">
      <div className="mx-auto max-w-7xl px-4 py-24 lg:px-8">
        <div className="text-center mb-16">
          <div className="inline-block rounded bg-primary/10 px-3 py-1 text-xs font-medium text-primary mb-4">
            ARCHITECTURE
          </div>
          <h2 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
            Principles, Not Features
          </h2>
          <p className="mt-4 text-lg text-muted-foreground max-w-2xl mx-auto">
            These are not optional. They are architectural guarantees enforced by code.
          </p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          {principles.map((principle) => (
            <div
              key={principle.title}
              className="group relative rounded-xl border border-border bg-background p-6 transition-all hover:border-primary/30"
            >
              <div className="flex items-start gap-4">
                <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-lg bg-primary/10">
                  <principle.icon className="h-5 w-5 text-primary" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-foreground">
                    {principle.title}
                  </h3>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {principle.description}
                  </p>
                  <code className="mt-3 block text-xs font-mono text-primary/80 bg-primary/5 px-2 py-1 rounded">
                    {principle.code}
                  </code>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export function ArchitectureSection() {
  const components = [
    { name: "edgerun-metal", description: "Bare metal bootloader", layer: "hardware" },
    { name: "edgerun-clock", description: "Distributed time sync", layer: "system" },
    { name: "edgerun-crypto", description: "BLAKE3, Ed25519, X25519", layer: "core" },
    { name: "edgerun-identity", description: "Key derivation & management", layer: "core" },
    { name: "edgerun-object", description: "Content-addressed storage", layer: "data" },
    { name: "edgerun-admission", description: "Policy engine", layer: "network" },
    { name: "edgerun-relay", description: "NAT traversal & relay", layer: "network" },
    { name: "edgerun-node", description: "Runtime orchestration", layer: "runtime" },
  ]

  const layerColors: Record<string, string> = {
    hardware: "text-orange-400",
    system: "text-yellow-400",
    core: "text-primary",
    data: "text-blue-400",
    network: "text-cyan-400",
    runtime: "text-violet-400",
  }

  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-7xl px-4 py-24 lg:px-8">
        <div className="grid gap-12 lg:grid-cols-5 lg:gap-16">
          <div className="lg:col-span-2">
            <div className="inline-block rounded bg-primary/10 px-3 py-1 text-xs font-medium text-primary mb-4">
              STACK
            </div>
            <h2 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              Pure Zig.
              <br />
              <span className="text-muted-foreground">Zero Dependencies.</span>
            </h2>
            <p className="mt-4 text-muted-foreground leading-relaxed">
              Every component written from scratch. No inherited vulnerabilities. 
              No black boxes. Compiles to WebAssembly for browser, native for desktop.
            </p>
            <div className="mt-8">
              <Button variant="outline" asChild>
                <Link href="/docs/architecture">
                  Explore Architecture
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
            </div>
          </div>

          <div className="lg:col-span-3 space-y-2">
            {components.map((component, index) => (
              <Link
                key={component.name}
                href={`/docs/architecture/${component.name.replace("edgerun-", "")}`}
                className="group flex items-center gap-4 rounded-lg border border-border bg-card p-4 transition-all hover:border-primary/30 hover:bg-card/80"
              >
                <div className="flex-shrink-0 w-6 text-right font-mono text-xs text-muted-foreground">
                  {String(index + 1).padStart(2, "0")}
                </div>
                <div className="flex-1 min-w-0">
                  <span className={`font-mono text-sm ${layerColors[component.layer]}`}>
                    {component.name}
                  </span>
                </div>
                <div className="text-sm text-muted-foreground hidden sm:block">
                  {component.description}
                </div>
                <ArrowRight className="h-4 w-4 text-muted-foreground opacity-0 transition-all group-hover:opacity-100" />
              </Link>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

export function EnergySavingsSection() {
  const scenarios = [
    { adoption: "10%", savings: "50", unit: "TWh/yr", equivalent: "Belgium" },
    { adoption: "30%", savings: "150", unit: "TWh/yr", equivalent: "NL + DK" },
    { adoption: "50%", savings: "250", unit: "TWh/yr", equivalent: "UK" },
  ]

  return (
    <section className="border-t border-border bg-card/30">
      <div className="mx-auto max-w-7xl px-4 py-24 lg:px-8">
        <div className="grid gap-12 lg:grid-cols-2 items-center">
          <div>
            <div className="inline-block rounded bg-primary/10 px-3 py-1 text-xs font-medium text-primary mb-4">
              IMPACT
            </div>
            <h2 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              {"What If We Didn't Need"}
              <br />
              <span className="text-muted-foreground">All Those Data Centers?</span>
            </h2>
            <p className="mt-4 text-muted-foreground leading-relaxed">
              Global data centers consume 500+ TWh annually. Edge computing on 
              consumer devices could dramatically reduce this footprint while 
              improving privacy and resilience.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-4">
            {scenarios.map((scenario) => (
              <div 
                key={scenario.adoption}
                className="rounded-xl border border-border bg-background p-6 text-center"
              >
                <div className="text-3xl font-bold text-primary">{scenario.adoption}</div>
                <div className="text-xs text-muted-foreground mt-1">adoption</div>
                <div className="mt-4 pt-4 border-t border-border">
                  <div className="text-xl font-semibold text-foreground">{scenario.savings}</div>
                  <div className="text-xs text-muted-foreground">{scenario.unit}</div>
                </div>
                <div className="mt-2 text-xs text-muted-foreground">
                  = {scenario.equivalent}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

export function CTASection() {
  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-7xl px-4 py-24 lg:px-8">
        <div className="relative overflow-hidden rounded-2xl border border-primary/30 bg-card">
          {/* Grid background */}
          <div className="absolute inset-0 bg-grid-fine opacity-20" />
          
          {/* Glow effect */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-96 h-96 bg-primary/20 rounded-full blur-3xl" />
          
          <div className="relative px-8 py-16 sm:px-12 lg:px-16 text-center">
            <h2 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl">
              Cut Out the Middlemen
            </h2>
            <p className="mt-4 text-lg text-muted-foreground max-w-xl mx-auto">
              Start with the docs. Explore the architecture. Build apps that respect users.
            </p>
            <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row">
              <Button size="lg" className="gap-2 glow-primary" asChild>
                <Link href="/docs/getting-started/introduction">
                  Get Started
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </Button>
              <Button size="lg" variant="outline" asChild>
                <Link href="/apps">
                  Browse Apps
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
