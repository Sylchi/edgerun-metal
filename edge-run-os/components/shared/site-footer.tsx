import Link from "next/link"
import { Terminal, Github, Twitter } from "lucide-react"

const footerLinks = {
  product: [
    { name: "Documentation", href: "/docs" },
    { name: "Blog", href: "/blog" },
    { name: "App Store", href: "/apps" },
    { name: "Roadmap", href: "/docs/roadmap" },
  ],
  resources: [
    { name: "Getting Started", href: "/docs/getting-started" },
    { name: "Architecture", href: "/docs/architecture" },
    { name: "Security Model", href: "/docs/security" },
    { name: "API Reference", href: "/docs/reference" },
  ],
  community: [
    { name: "GitHub", href: "https://github.com/edgerun" },
    { name: "Discord", href: "#" },
    { name: "Twitter", href: "#" },
    { name: "Contributing", href: "/docs/contributing" },
  ],
}

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card/50">
      <div className="mx-auto max-w-7xl px-4 py-12 lg:px-8">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary">
                <Terminal className="h-4 w-4 text-primary-foreground" />
              </div>
              <span className="text-lg font-semibold tracking-tight">EdgeRun</span>
            </Link>
            <p className="mt-4 text-sm text-muted-foreground leading-relaxed">
              A decentralized runtime for user sovereignty. Own your digital identity.
            </p>
            <div className="mt-4 flex gap-3">
              <a
                href="https://github.com/edgerun"
                target="_blank"
                rel="noopener noreferrer"
                className="text-muted-foreground hover:text-foreground transition-colors"
                aria-label="GitHub"
              >
                <Github className="h-5 w-5" />
              </a>
              <a
                href="#"
                className="text-muted-foreground hover:text-foreground transition-colors"
                aria-label="Twitter"
              >
                <Twitter className="h-5 w-5" />
              </a>
            </div>
          </div>

          {/* Links */}
          <div>
            <h3 className="text-sm font-semibold text-foreground">Product</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.product.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-foreground">Resources</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.resources.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3 className="text-sm font-semibold text-foreground">Community</h3>
            <ul className="mt-4 space-y-3">
              {footerLinks.community.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                    {...(link.href.startsWith("http")
                      ? { target: "_blank", rel: "noopener noreferrer" }
                      : {})}
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom */}
        <div className="mt-12 border-t border-border pt-8 flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-sm text-muted-foreground">
            Built for those who believe digital identity should be owned, not rented.
          </p>
          <p className="text-sm text-muted-foreground">
            Crafted with Zig. No middlemen.
          </p>
        </div>
      </div>
    </footer>
  )
}
