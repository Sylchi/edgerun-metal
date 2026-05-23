import type { Metadata } from "next"
import Link from "next/link"
import { ArrowRight, Shield, Lock, Globe, Cpu } from "lucide-react"
import { TableOfContents, DocsPagination, CodeBlock } from "@/components/docs"
import { getDocBySlug } from "@/lib/docs-navigation"

export const metadata: Metadata = {
  title: "Introduction",
  description: "Welcome to EdgeRun - a decentralized runtime for user sovereignty",
}

export default function IntroductionPage() {
  const doc = getDocBySlug(["getting-started", "introduction"])

  return (
    <TableOfContents>
      <article className="prose prose-invert max-w-none">
        <h1 id="introduction">Introduction to EdgeRun</h1>
        
        <p className="lead text-xl text-muted-foreground">
          EdgeRun is a decentralized runtime built from scratch in Zig. It is designed to return 
          digital identity and compute sovereignty to users, eliminating the need for 
          centralized intermediaries.
        </p>

        <h2 id="why-edgerun">Why EdgeRun Exists</h2>
        
        <p>
          The modern web was built on a model of centralized trust. Every request you make, 
          every piece of data you store, every identity you create — all flow through 
          intermediaries who can observe, modify, and monetize your digital life.
        </p>

        <p>
          EdgeRun rejects this model entirely. Instead of secured pipes between trusted parties, 
          we build on <strong>sealed objects</strong> that travel through untrusted networks. 
          Instead of platform-governed resources, we enable <strong>user-governed compute</strong> 
          on your own hardware.
        </p>

        <div className="not-prose my-8 grid gap-4 sm:grid-cols-2">
          <div className="rounded-lg border border-border bg-card p-6">
            <Shield className="h-8 w-8 text-primary mb-4" />
            <h3 className="text-lg font-semibold text-foreground">Identity-Routed</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Work is addressed by cryptographic identity, not sessions on centralized servers.
            </p>
          </div>
          <div className="rounded-lg border border-border bg-card p-6">
            <Lock className="h-8 w-8 text-primary mb-4" />
            <h3 className="text-lg font-semibold text-foreground">End-to-End Encrypted</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Data is encrypted at the source. No intermediary can inspect or modify it.
            </p>
          </div>
          <div className="rounded-lg border border-border bg-card p-6">
            <Globe className="h-8 w-8 text-primary mb-4" />
            <h3 className="text-lg font-semibold text-foreground">Peer-to-Peer</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Direct connections between users. No surveillance chokepoints.
            </p>
          </div>
          <div className="rounded-lg border border-border bg-card p-6">
            <Cpu className="h-8 w-8 text-primary mb-4" />
            <h3 className="text-lg font-semibold text-foreground">Local Compute</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Run applications on your hardware. Your devices, your rules.
            </p>
          </div>
        </div>

        <h2 id="core-principles">Core Principles</h2>

        <p>
          EdgeRun is built on four fundamental architectural principles that distinguish it 
          from traditional web infrastructure:
        </p>

        <ol>
          <li>
            <strong>Identity-Routed Work</strong> — Every piece of work is cryptographically 
            addressed to a specific identity. There are no anonymous sessions or bearer tokens.
          </li>
          <li>
            <strong>Sealed Work Objects</strong> — Data is encrypted before it leaves your device 
            and remains sealed until it reaches its intended recipient.
          </li>
          <li>
            <strong>User-Governed Resources</strong> — You decide what runs on your hardware, 
            who can connect to you, and what data you share.
          </li>
          <li>
            <strong>Local Admission Policy</strong> — Each node enforces its own policies. 
            There are no remote gatekeepers or centralized censorship.
          </li>
        </ol>

        <h2 id="architecture-overview">Architecture Overview</h2>

        <p>
          EdgeRun consists of several modular components, each handling a specific aspect 
          of the runtime:
        </p>

        <CodeBlock
          code={`edgerun/
├── edgerun-metal      # Hardware abstraction, bare metal boot
├── edgerun-clock      # Distributed time synchronization
├── edgerun-crypto     # BLAKE3, Ed25519, X25519, AES-GCM
├── edgerun-identity   # Key derivation, identity management
├── edgerun-object     # Content-addressed storage
├── edgerun-admission  # Policy engine
├── edgerun-relay      # NAT traversal
├── edgerun-node       # Runtime orchestration
└── edgerun-ui-core    # GL-based UI rendering`}
          language="text"
          filename="Project Structure"
        />

        <p>
          Each component is written in Zig for maximum performance, minimal dependencies, 
          and compile-time safety guarantees.
        </p>

        <h2 id="getting-started">Getting Started</h2>

        <p>
          Ready to dive in? Start with the <Link href="/docs/getting-started/installation" className="text-primary hover:underline">installation guide</Link> to 
          set up your development environment, then follow the <Link href="/docs/getting-started/first-app" className="text-primary hover:underline">first app tutorial</Link> to 
          build your first EdgeRun application.
        </p>

        <div className="not-prose mt-8">
          <Link
            href="/docs/getting-started/installation"
            className="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
          >
            Continue to Installation
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </article>

      {doc && <DocsPagination prev={doc.prev} next={doc.next} />}
    </TableOfContents>
  )
}
