export type DocSection = {
  title: string
  href: string
  items?: DocSection[]
}

export const docsNavigation: DocSection[] = [
  {
    title: "Getting Started",
    href: "/docs/getting-started",
    items: [
      { title: "Introduction", href: "/docs/getting-started/introduction" },
      { title: "Installation", href: "/docs/getting-started/installation" },
      { title: "Your First App", href: "/docs/getting-started/first-app" },
    ],
  },
  {
    title: "Architecture",
    href: "/docs/architecture",
    items: [
      { title: "Overview", href: "/docs/architecture/overview" },
      { title: "Identity Routing", href: "/docs/architecture/identity-routing" },
      { title: "Object Model", href: "/docs/architecture/object-model" },
      { title: "Admission System", href: "/docs/architecture/admission" },
      { title: "Storage", href: "/docs/architecture/storage" },
      { title: "Cryptographic Primitives", href: "/docs/architecture/crypto" },
    ],
  },
  {
    title: "Security",
    href: "/docs/security",
    items: [
      { title: "Threat Model", href: "/docs/security/threat-model" },
      { title: "Web Architecture Problems", href: "/docs/security/web-problems" },
      { title: "E2E Encryption", href: "/docs/security/encryption" },
      { title: "TPM Attestation", href: "/docs/security/tpm" },
    ],
  },
  {
    title: "Runtime",
    href: "/docs/runtime",
    items: [
      { title: "Metal Boot Process", href: "/docs/runtime/metal" },
      { title: "Wasm Execution", href: "/docs/runtime/wasm" },
      { title: "UI Rendering", href: "/docs/runtime/ui" },
    ],
  },
  {
    title: "SDK",
    href: "/docs/sdk",
    items: [
      { title: "Node API", href: "/docs/sdk/node-api" },
      { title: "Building Apps", href: "/docs/sdk/building-apps" },
      { title: "Manifest Format", href: "/docs/sdk/manifest" },
    ],
  },
  {
    title: "Reference",
    href: "/docs/reference",
    items: [
      { title: "API", href: "/docs/reference/api" },
      { title: "CLI", href: "/docs/reference/cli" },
      { title: "Configuration", href: "/docs/reference/configuration" },
    ],
  },
]

export function getDocBySlug(slug: string[]): { 
  title: string
  section: string
  prev?: { title: string; href: string }
  next?: { title: string; href: string }
} | null {
  const href = `/docs/${slug.join("/")}`
  
  // Flatten all items with their section context
  const allItems: { title: string; href: string; section: string }[] = []
  
  for (const section of docsNavigation) {
    if (section.href === href) {
      allItems.push({ title: section.title, href: section.href, section: section.title })
    }
    if (section.items) {
      for (const item of section.items) {
        allItems.push({ title: item.title, href: item.href, section: section.title })
      }
    }
  }
  
  const currentIndex = allItems.findIndex(item => item.href === href)
  if (currentIndex === -1) return null
  
  const current = allItems[currentIndex]
  const prev = currentIndex > 0 ? allItems[currentIndex - 1] : undefined
  const next = currentIndex < allItems.length - 1 ? allItems[currentIndex + 1] : undefined
  
  return {
    title: current.title,
    section: current.section,
    prev: prev ? { title: prev.title, href: prev.href } : undefined,
    next: next ? { title: next.title, href: next.href } : undefined,
  }
}
