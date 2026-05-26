import type { Metadata } from "next"
import { SiteHeader, SiteFooter } from "@/components/shared"
import { BlogCard, FeaturedBlogCard } from "@/components/blog"
import { getBlogPosts, getFeaturedPosts, getAllTags } from "@/lib/blog-data"

export const metadata: Metadata = {
  title: "Blog",
  description: "Technical deep dives, benchmarks, and updates from the EdgeRun team",
}

export default function BlogPage() {
  const posts = getBlogPosts()
  const featuredPosts = getFeaturedPosts()
  const tags = getAllTags()

  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <div className="mx-auto max-w-7xl px-4 py-16 lg:px-8">
          {/* Header */}
          <div className="max-w-2xl">
            <h1 className="text-4xl font-bold tracking-tight text-foreground">Blog</h1>
            <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
              Technical deep dives, performance benchmarks, and updates from the EdgeRun team. 
              All code samples link directly to their git commits.
            </p>
          </div>

          {/* Tags */}
          <div className="mt-8 flex flex-wrap gap-2">
            <span className="text-sm text-muted-foreground mr-2">Filter by:</span>
            {tags.map((tag) => (
              <button
                key={tag}
                className="rounded-full border border-border bg-card px-3 py-1 text-sm text-muted-foreground hover:border-primary/50 hover:text-foreground transition-colors"
              >
                {tag}
              </button>
            ))}
          </div>

          {/* Featured posts */}
          {featuredPosts.length > 0 && (
            <section className="mt-12">
              <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-6">
                Featured
              </h2>
              <div className="grid gap-6">
                {featuredPosts.map((post) => (
                  <FeaturedBlogCard key={post.slug} post={post} />
                ))}
              </div>
            </section>
          )}

          {/* All posts */}
          <section className="mt-16">
            <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-6">
              All Posts
            </h2>
            <div className="grid gap-6 md:grid-cols-2">
              {posts.map((post) => (
                <BlogCard key={post.slug} post={post} />
              ))}
            </div>
          </section>
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}
