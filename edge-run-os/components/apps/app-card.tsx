import Link from "next/link"
import {
  MessageSquare,
  Lock,
  FileText,
  Code,
  Video,
  Share2,
  Wallet,
  Play,
  Shield,
  Briefcase,
  Settings,
  CheckCircle,
  Star,
  Download,
} from "lucide-react"
import type { App } from "@/lib/apps-data"
import { cn } from "@/lib/utils"

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  MessageSquare,
  Lock,
  FileText,
  Code,
  Video,
  Share2,
  Wallet,
  Play,
  Shield,
  Briefcase,
  Settings,
}

function AppIcon({ icon, className }: { icon: string; className?: string }) {
  const IconComponent = iconMap[icon] || Settings
  return <IconComponent className={className} />
}

export function AppCard({ app }: { app: App }) {
  return (
    <Link
      href={`/apps/${app.id}`}
      className="group relative flex flex-col rounded-xl border border-border bg-card p-5 transition-all hover:border-primary/30 hover:bg-card/80"
    >
      <div className="flex items-start gap-4">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-primary/10">
          <AppIcon icon={app.icon} className="h-7 w-7 text-primary" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h3 className="font-semibold text-foreground truncate group-hover:text-primary transition-colors">
              {app.name}
            </h3>
            {app.verified && (
              <CheckCircle className="h-4 w-4 text-primary shrink-0" />
            )}
          </div>
          <p className="text-sm text-muted-foreground truncate">{app.developer}</p>
        </div>
      </div>

      <p className="mt-4 text-sm text-muted-foreground line-clamp-2 leading-relaxed">
        {app.shortDescription}
      </p>

      <div className="mt-4 flex items-center justify-between text-xs text-muted-foreground">
        <div className="flex items-center gap-3">
          <span className="flex items-center gap-1">
            <Star className="h-3.5 w-3.5 fill-primary text-primary" />
            {app.rating}
          </span>
          <span className="flex items-center gap-1">
            <Download className="h-3.5 w-3.5" />
            {app.downloads.toLocaleString()}
          </span>
        </div>
        <span className="text-muted-foreground/70">{app.wasmSize}</span>
      </div>
    </Link>
  )
}

export function FeaturedAppCard({ app }: { app: App }) {
  return (
    <Link
      href={`/apps/${app.id}`}
      className="group relative flex flex-col overflow-hidden rounded-xl border border-primary/30 bg-gradient-to-br from-primary/10 via-card to-card p-6 transition-all hover:border-primary/50"
    >
      {app.featured && (
        <div className="absolute right-4 top-4 rounded-full bg-primary/20 px-3 py-1 text-xs font-medium text-primary">
          Featured
        </div>
      )}

      <div className="flex items-start gap-4">
        <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-xl bg-primary/20">
          <AppIcon icon={app.icon} className="h-8 w-8 text-primary" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h3 className="text-xl font-semibold text-foreground group-hover:text-primary transition-colors">
              {app.name}
            </h3>
            {app.verified && (
              <CheckCircle className="h-5 w-5 text-primary shrink-0" />
            )}
          </div>
          <p className="text-sm text-muted-foreground">{app.developer}</p>
        </div>
      </div>

      <p className="mt-4 text-muted-foreground leading-relaxed line-clamp-2">
        {app.shortDescription}
      </p>

      <div className="mt-6 flex items-center justify-between text-sm text-muted-foreground">
        <div className="flex items-center gap-4">
          <span className="flex items-center gap-1.5">
            <Star className="h-4 w-4 fill-primary text-primary" />
            {app.rating}
          </span>
          <span className="flex items-center gap-1.5">
            <Download className="h-4 w-4" />
            {app.downloads.toLocaleString()}
          </span>
        </div>
        <span>{app.wasmSize}</span>
      </div>
    </Link>
  )
}

export function CategoryCard({
  category,
  label,
  count,
}: {
  category: string
  label: string
  count: number
}) {
  const icons: Record<string, React.ComponentType<{ className?: string }>> = {
    communication: MessageSquare,
    productivity: Briefcase,
    "developer-tools": Code,
    security: Shield,
    media: Play,
    finance: Wallet,
    utilities: Settings,
  }
  const Icon = icons[category] || Settings

  return (
    <Link
      href={`/apps?category=${category}`}
      className="group flex items-center gap-4 rounded-lg border border-border bg-card p-4 transition-all hover:border-primary/30 hover:bg-card/80"
    >
      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted">
        <Icon className="h-5 w-5 text-muted-foreground group-hover:text-primary transition-colors" />
      </div>
      <div>
        <h3 className="font-medium text-foreground group-hover:text-primary transition-colors">
          {label}
        </h3>
        <p className="text-sm text-muted-foreground">{count} apps</p>
      </div>
    </Link>
  )
}
