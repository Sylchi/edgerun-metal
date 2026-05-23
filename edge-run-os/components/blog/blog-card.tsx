import Link from "next/link"
import { Calendar, Clock, Tag } from "lucide-react"
import type { BlogPost } from "@/lib/blog-data"

export function BlogCard({ post }: { post: BlogPost }) {
  return (
    <article className="group relative rounded-xl border border-border bg-card p-6 transition-all hover:border-primary/30 hover:bg-card/80">
      <div className="flex flex-wrap gap-2 mb-4">
        {post.tags.slice(0, 3).map((tag) => (
          <span
            key={tag}
            className="inline-flex items-center gap-1 rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium text-muted-foreground"
          >
            <Tag className="h-3 w-3" />
            {tag}
          </span>
        ))}
      </div>

      <h2 className="text-xl font-semibold text-foreground group-hover:text-primary transition-colors">
        <Link href={`/blog/${post.slug}`} className="after:absolute after:inset-0">
          {post.title}
        </Link>
      </h2>

      <p className="mt-3 text-muted-foreground leading-relaxed line-clamp-2">
        {post.description}
      </p>

      <div className="mt-4 flex items-center gap-4 text-sm text-muted-foreground">
        <div className="flex items-center gap-1.5">
          <Calendar className="h-4 w-4" />
          <time dateTime={post.date}>
            {new Date(post.date).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            })}
          </time>
        </div>
        <div className="flex items-center gap-1.5">
          <Clock className="h-4 w-4" />
          <span>{post.readingTime}</span>
        </div>
      </div>
    </article>
  )
}

export function FeaturedBlogCard({ post }: { post: BlogPost }) {
  return (
    <article className="group relative overflow-hidden rounded-xl border border-primary/30 bg-gradient-to-br from-primary/10 via-card to-card p-8 transition-all hover:border-primary/50">
      <div className="absolute right-4 top-4 rounded-full bg-primary/20 px-3 py-1 text-xs font-medium text-primary">
        Featured
      </div>

      <div className="flex flex-wrap gap-2 mb-4">
        {post.tags.map((tag) => (
          <span
            key={tag}
            className="inline-flex items-center gap-1 rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium text-muted-foreground"
          >
            <Tag className="h-3 w-3" />
            {tag}
          </span>
        ))}
      </div>

      <h2 className="text-2xl font-bold text-foreground group-hover:text-primary transition-colors">
        <Link href={`/blog/${post.slug}`} className="after:absolute after:inset-0">
          {post.title}
        </Link>
      </h2>

      <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
        {post.description}
      </p>

      <div className="mt-6 flex items-center gap-4 text-sm text-muted-foreground">
        <div className="flex items-center gap-1.5">
          <Calendar className="h-4 w-4" />
          <time dateTime={post.date}>
            {new Date(post.date).toLocaleDateString("en-US", {
              month: "long",
              day: "numeric",
              year: "numeric",
            })}
          </time>
        </div>
        <div className="flex items-center gap-1.5">
          <Clock className="h-4 w-4" />
          <span>{post.readingTime}</span>
        </div>
      </div>
    </article>
  )
}
