export type BlogPost = {
  slug: string
  title: string
  description: string
  date: string
  author: {
    name: string
    avatar?: string
  }
  tags: string[]
  readingTime: string
  featured?: boolean
}

// Sample blog posts data - in production, this would come from MDX files or a CMS
export const blogPosts: BlogPost[] = [
  {
    slug: "blake3-performance-analysis",
    title: "BLAKE3 Performance Analysis: Why We Chose It for EdgeRun",
    description: "A deep dive into cryptographic hash function benchmarks and why BLAKE3 outperforms SHA-256 and SHA-3 for our use cases.",
    date: "2026-05-15",
    author: { name: "EdgeRun Team" },
    tags: ["crypto", "performance", "benchmarks"],
    readingTime: "12 min read",
    featured: true,
  },
  {
    slug: "identity-routing-explained",
    title: "Identity Routing: The Foundation of Decentralized Addressing",
    description: "How cryptographic identities replace domain names and enable truly peer-to-peer communication.",
    date: "2026-05-10",
    author: { name: "EdgeRun Team" },
    tags: ["architecture", "identity", "networking"],
    readingTime: "8 min read",
  },
  {
    slug: "zig-for-systems-programming",
    title: "Why Zig? A Systems Programmer's Perspective",
    description: "Our experience building EdgeRun in Zig - the benefits, challenges, and lessons learned.",
    date: "2026-05-05",
    author: { name: "EdgeRun Team" },
    tags: ["zig", "engineering", "systems"],
    readingTime: "10 min read",
  },
  {
    slug: "edgerun-metal-boot-process",
    title: "Booting from Bare Metal: The edgerun-metal Journey",
    description: "How we built a minimal bootloader that takes you from BIOS to a running EdgeRun node.",
    date: "2026-04-28",
    author: { name: "EdgeRun Team" },
    tags: ["metal", "boot", "low-level"],
    readingTime: "15 min read",
  },
  {
    slug: "admission-policies-deep-dive",
    title: "Admission Policies: Local Control Over Remote Access",
    description: "Understanding EdgeRun's policy engine and how nodes decide what work to accept.",
    date: "2026-04-20",
    author: { name: "EdgeRun Team" },
    tags: ["security", "policies", "architecture"],
    readingTime: "9 min read",
  },
]

export function getBlogPost(slug: string): BlogPost | undefined {
  return blogPosts.find((post) => post.slug === slug)
}

export function getBlogPosts(): BlogPost[] {
  return blogPosts.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
}

export function getFeaturedPosts(): BlogPost[] {
  return blogPosts.filter((post) => post.featured)
}

export function getPostsByTag(tag: string): BlogPost[] {
  return blogPosts.filter((post) => post.tags.includes(tag))
}

export function getAllTags(): string[] {
  const tags = new Set<string>()
  blogPosts.forEach((post) => post.tags.forEach((tag) => tags.add(tag)))
  return Array.from(tags).sort()
}
