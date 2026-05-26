import type { Metadata } from "next"
import { TableOfContents, DocsPagination, CodeBlock } from "@/components/docs"
import { getDocBySlug } from "@/lib/docs-navigation"
import { AlertTriangle, Shield, Eye, Server, Globe } from "lucide-react"

export const metadata: Metadata = {
  title: "Web Architecture Problems",
  description: "Understanding the security and privacy issues with current web architecture",
}

export default function WebProblemsPage() {
  const doc = getDocBySlug(["security", "web-problems"])

  return (
    <TableOfContents>
      <article className="prose prose-invert max-w-none">
        <h1 id="web-architecture-problems">Web Architecture Problems</h1>
        
        <p className="lead text-xl text-muted-foreground">
          The modern web was designed for document sharing, not for secure, private communication. 
          Its architecture has fundamental issues that cannot be fixed with patches — they require 
          a completely different approach.
        </p>

        <div className="not-prose my-8 rounded-lg border border-destructive/50 bg-destructive/10 p-6">
          <div className="flex items-start gap-4">
            <AlertTriangle className="h-6 w-6 text-destructive shrink-0 mt-0.5" />
            <div>
              <h3 className="text-lg font-semibold text-foreground">This is not theoretical</h3>
              <p className="mt-2 text-sm text-muted-foreground">
                These problems are actively exploited today. Government surveillance programs, 
                corporate data harvesting, and targeted attacks all rely on these architectural weaknesses.
              </p>
            </div>
          </div>
        </div>

        <h2 id="tls-termination">TLS Termination: The Illusion of Privacy</h2>

        <p>
          When you visit a website over HTTPS, your browser establishes an encrypted connection. 
          But that encryption only protects the data in transit — it says nothing about what 
          happens at either end.
        </p>

        <div className="not-prose my-8 rounded-lg border border-border bg-card p-6">
          <div className="flex items-center gap-4 mb-4">
            <Eye className="h-6 w-6 text-primary" />
            <h3 className="text-lg font-semibold text-foreground">The TLS Termination Problem</h3>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex items-center gap-3">
              <span className="font-mono text-primary">You</span>
              <span className="flex-1 h-px bg-border" />
              <span className="font-mono text-destructive">CDN</span>
              <span className="flex-1 h-px bg-border" />
              <span className="font-mono text-destructive">Load Balancer</span>
              <span className="flex-1 h-px bg-border" />
              <span className="font-mono text-muted-foreground">Origin</span>
            </div>
            <p className="text-muted-foreground">
              At every red point, your data is decrypted, inspected, and re-encrypted. 
              Each intermediary sees everything in plaintext.
            </p>
          </div>
        </div>

        <p>
          Modern web infrastructure almost always involves TLS termination at multiple points:
        </p>

        <ul>
          <li>
            <strong>CDNs (Cloudflare, Akamai, Fastly)</strong> — Decrypt your traffic to cache 
            content, apply WAF rules, and route requests.
          </li>
          <li>
            <strong>Load Balancers</strong> — Decrypt to inspect headers and route to 
            appropriate backend servers.
          </li>
          <li>
            <strong>API Gateways</strong> — Decrypt to apply rate limiting, authentication, 
            and logging.
          </li>
          <li>
            <strong>Reverse Proxies</strong> — Decrypt for SSL offloading and request modification.
          </li>
        </ul>

        <CodeBlock
          code={`# Typical request flow showing TLS termination points
Client → [TLS] → Cloudflare (decrypts, inspects, re-encrypts)
              → [TLS] → AWS ALB (decrypts, routes)
                     → [TLS/plain] → Application Server

# At each arrow, data is fully visible to that service.
# "End-to-end" encryption? Only if you ignore the middle.`}
          language="text"
          filename="TLS Termination Chain"
        />

        <h2 id="dns-centralization">DNS Centralization: The Address Book Problem</h2>

        <p>
          Before your browser can connect to any server, it needs to resolve the domain name 
          to an IP address. This lookup goes through the Domain Name System — and reveals 
          every site you visit.
        </p>

        <div className="not-prose my-8 grid gap-4 sm:grid-cols-3">
          <div className="rounded-lg border border-border bg-card p-4 text-center">
            <div className="text-3xl font-bold text-primary">~70%</div>
            <div className="text-sm text-muted-foreground mt-1">of DNS queries go through Google or Cloudflare</div>
          </div>
          <div className="rounded-lg border border-border bg-card p-4 text-center">
            <div className="text-3xl font-bold text-primary">100%</div>
            <div className="text-sm text-muted-foreground mt-1">of your browsing history visible to DNS provider</div>
          </div>
          <div className="rounded-lg border border-border bg-card p-4 text-center">
            <div className="text-3xl font-bold text-primary">Unencrypted</div>
            <div className="text-sm text-muted-foreground mt-1">Traditional DNS sends queries in plaintext</div>
          </div>
        </div>

        <p>
          Even with DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT), you are still trusting a 
          centralized resolver with your complete browsing history. The encryption only 
          hides the queries from your ISP — the resolver sees everything.
        </p>

        <h2 id="certificate-authority">Certificate Authority: Trust by Decree</h2>

        <p>
          TLS security depends on Certificate Authorities (CAs) to verify that the server 
          you are connecting to is who it claims to be. But this creates a massive trust problem:
        </p>

        <ul>
          <li>Your browser trusts <strong>hundreds of CAs</strong> by default</li>
          <li>Any trusted CA can issue a certificate for <strong>any domain</strong></li>
          <li>CAs have been <strong>compromised</strong>, <strong>coerced</strong>, and <strong>tricked</strong> into issuing fraudulent certificates</li>
          <li>Government-controlled CAs exist and can perform <strong>legal man-in-the-middle attacks</strong></li>
        </ul>

        <CodeBlock
          code={`# DigiNotar (2011): Compromised, issued fraudulent Google certs
# Symantec (2017): Mis-issued 30,000+ certificates
# Kazakhstan (2019): Government-mandated root CA for MITM
# TrustCor (2022): Links to US intelligence contractors

# Your "secure" connection is only as trustworthy as 
# the weakest CA in your browser's trust store.`}
          language="text"
          filename="CA Incidents"
        />

        <h2 id="traffic-concentration">Traffic Concentration: Single Points of Failure</h2>

        <p>
          The web has evolved into a system where a tiny number of companies handle the 
          majority of all traffic. This creates both surveillance chokepoints and 
          catastrophic failure modes.
        </p>

        <div className="not-prose my-8 overflow-hidden rounded-lg border border-border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-card">
                <th className="px-4 py-3 text-left font-semibold">Company</th>
                <th className="px-4 py-3 text-left font-semibold">Control Point</th>
                <th className="px-4 py-3 text-left font-semibold">Traffic Share</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-border">
                <td className="px-4 py-3 font-medium">Google</td>
                <td className="px-4 py-3 text-muted-foreground">Search, DNS, Chrome, Android, Cloud</td>
                <td className="px-4 py-3 text-primary">~40%</td>
              </tr>
              <tr className="border-b border-border">
                <td className="px-4 py-3 font-medium">Cloudflare</td>
                <td className="px-4 py-3 text-muted-foreground">CDN, DNS, DDoS, Zero Trust</td>
                <td className="px-4 py-3 text-primary">~20%</td>
              </tr>
              <tr className="border-b border-border">
                <td className="px-4 py-3 font-medium">Amazon AWS</td>
                <td className="px-4 py-3 text-muted-foreground">Cloud hosting, CDN, DNS</td>
                <td className="px-4 py-3 text-primary">~33%</td>
              </tr>
              <tr>
                <td className="px-4 py-3 font-medium">Meta</td>
                <td className="px-4 py-3 text-muted-foreground">Social, Messaging, WhatsApp</td>
                <td className="px-4 py-3 text-primary">~15%</td>
              </tr>
            </tbody>
          </table>
        </div>

        <p>
          When Cloudflare has an outage, significant portions of the internet become 
          unreachable. When AWS goes down, businesses worldwide grind to a halt. This 
          is not resilience — it is architectural fragility.
        </p>

        <h2 id="edgerun-solution">How EdgeRun Solves This</h2>

        <p>
          EdgeRun addresses each of these problems at the architectural level:
        </p>

        <div className="not-prose my-8 space-y-4">
          <div className="flex items-start gap-4 rounded-lg border border-primary/30 bg-primary/5 p-4">
            <Shield className="h-5 w-5 text-primary shrink-0 mt-0.5" />
            <div>
              <h4 className="font-semibold text-foreground">No TLS Termination</h4>
              <p className="text-sm text-muted-foreground mt-1">
                Data is encrypted with the recipient{"'"}s public key before leaving your device. 
                It remains sealed through any network path until the recipient decrypts it.
              </p>
            </div>
          </div>
          
          <div className="flex items-start gap-4 rounded-lg border border-primary/30 bg-primary/5 p-4">
            <Globe className="h-5 w-5 text-primary shrink-0 mt-0.5" />
            <div>
              <h4 className="font-semibold text-foreground">No DNS</h4>
              <p className="text-sm text-muted-foreground mt-1">
                Identities are cryptographic keys. You connect directly to a public key, 
                not to a domain name that must be resolved through centralized servers.
              </p>
            </div>
          </div>
          
          <div className="flex items-start gap-4 rounded-lg border border-primary/30 bg-primary/5 p-4">
            <Server className="h-5 w-5 text-primary shrink-0 mt-0.5" />
            <div>
              <h4 className="font-semibold text-foreground">No Certificate Authorities</h4>
              <p className="text-sm text-muted-foreground mt-1">
                Identity verification is direct. You verify keys through trust-on-first-use, 
                key signing, or out-of-band verification — not by trusting third parties.
              </p>
            </div>
          </div>
          
          <div className="flex items-start gap-4 rounded-lg border border-primary/30 bg-primary/5 p-4">
            <Shield className="h-5 w-5 text-primary shrink-0 mt-0.5" />
            <div>
              <h4 className="font-semibold text-foreground">No Traffic Concentration</h4>
              <p className="text-sm text-muted-foreground mt-1">
                Peer-to-peer connections mean no single company sees or handles all traffic. 
                The network is resilient by design.
              </p>
            </div>
          </div>
        </div>

        <p>
          Learn more about EdgeRun{"'"}s security model in the <a href="/docs/security/encryption" className="text-primary hover:underline">E2E Encryption</a> and 
          <a href="/docs/security/threat-model" className="text-primary hover:underline"> Threat Model</a> documentation.
        </p>
      </article>

      {doc && <DocsPagination prev={doc.prev} next={doc.next} />}
    </TableOfContents>
  )
}
