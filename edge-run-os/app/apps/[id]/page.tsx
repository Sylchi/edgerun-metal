import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"
import {
  ArrowLeft,
  CheckCircle,
  Star,
  Download,
  Shield,
  HardDrive,
  Network,
  Mic,
  Camera,
  Clipboard,
  ExternalLink,
} from "lucide-react"
import { SiteHeader, SiteFooter } from "@/components/shared"
import { CompileButton } from "@/components/apps"
import { getApp, getApps, categoryLabels } from "@/lib/apps-data"
import { Badge } from "@/components/ui/badge"

type Props = {
  params: Promise<{ id: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const app = getApp(id)

  if (!app) {
    return { title: "App Not Found" }
  }

  return {
    title: app.name,
    description: app.shortDescription,
  }
}

export function generateStaticParams() {
  const apps = getApps()
  return apps.map((app) => ({ id: app.id }))
}

const permissionIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  network: Network,
  storage: HardDrive,
  microphone: Mic,
  camera: Camera,
  clipboard: Clipboard,
}

const permissionLabels: Record<string, string> = {
  network: "Network Access",
  storage: "Local Storage",
  microphone: "Microphone",
  camera: "Camera",
  clipboard: "Clipboard",
}

export default async function AppDetailPage({ params }: Props) {
  const { id } = await params
  const app = getApp(id)

  if (!app) {
    notFound()
  }

  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <div className="mx-auto max-w-4xl px-4 py-16 lg:px-8">
          {/* Back link */}
          <Link
            href="/apps"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors mb-8"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to App Store
          </Link>

          {/* Header */}
          <header className="flex flex-col gap-6 md:flex-row md:items-start md:gap-8">
            <div className="flex h-24 w-24 shrink-0 items-center justify-center rounded-2xl bg-primary/10">
              <Shield className="h-12 w-12 text-primary" />
            </div>

            <div className="flex-1">
              <div className="flex flex-wrap items-center gap-3">
                <h1 className="text-3xl font-bold text-foreground">{app.name}</h1>
                {app.verified && (
                  <Badge variant="secondary" className="gap-1">
                    <CheckCircle className="h-3.5 w-3.5" />
                    Verified
                  </Badge>
                )}
              </div>

              <p className="mt-2 text-muted-foreground">{app.developer}</p>

              <div className="mt-4 flex flex-wrap items-center gap-6 text-sm text-muted-foreground">
                <span className="flex items-center gap-1.5">
                  <Star className="h-4 w-4 fill-primary text-primary" />
                  {app.rating} rating
                </span>
                <span className="flex items-center gap-1.5">
                  <Download className="h-4 w-4" />
                  {app.downloads.toLocaleString()} downloads
                </span>
                <span>v{app.version}</span>
                <Badge variant="outline">{categoryLabels[app.category]}</Badge>
              </div>
            </div>
          </header>

          {/* Actions */}
          <div className="mt-8 p-6 rounded-xl border border-border bg-card">
            <CompileButton appId={app.id} sourceUrl={app.sourceUrl} />
          </div>

          {/* Description */}
          <section className="mt-12">
            <h2 className="text-lg font-semibold text-foreground mb-4">About</h2>
            <div className="prose prose-invert max-w-none">
              {app.description.split("\n\n").map((paragraph, i) => (
                <p key={i} className="text-muted-foreground leading-relaxed whitespace-pre-wrap">
                  {paragraph}
                </p>
              ))}
            </div>
          </section>

          {/* Technical details */}
          <section className="mt-12 grid gap-6 md:grid-cols-2">
            {/* Permissions */}
            <div className="rounded-xl border border-border bg-card p-6">
              <h2 className="text-lg font-semibold text-foreground mb-4">Permissions</h2>
              <div className="space-y-3">
                {app.permissions.map((permission) => {
                  const Icon = permissionIcons[permission] || Shield
                  return (
                    <div key={permission} className="flex items-center gap-3">
                      <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-muted">
                        <Icon className="h-4 w-4 text-muted-foreground" />
                      </div>
                      <span className="text-sm text-foreground">
                        {permissionLabels[permission] || permission}
                      </span>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Technical specs */}
            <div className="rounded-xl border border-border bg-card p-6">
              <h2 className="text-lg font-semibold text-foreground mb-4">Technical Details</h2>
              <dl className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">WASM Size</dt>
                  <dd className="font-medium text-foreground">{app.wasmSize}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Version</dt>
                  <dd className="font-medium text-foreground">{app.version}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Category</dt>
                  <dd className="font-medium text-foreground">{categoryLabels[app.category]}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-muted-foreground">Build Verified</dt>
                  <dd className="font-medium text-foreground">{app.verified ? "Yes" : "No"}</dd>
                </div>
                {app.sourceUrl && (
                  <div className="flex justify-between items-center">
                    <dt className="text-muted-foreground">Source Code</dt>
                    <dd>
                      <a
                        href={app.sourceUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 text-primary hover:underline"
                      >
                        GitHub
                        <ExternalLink className="h-3 w-3" />
                      </a>
                    </dd>
                  </div>
                )}
              </dl>
            </div>
          </section>

          {/* Build verification */}
          {app.verified && (
            <section className="mt-8">
              <div className="rounded-xl border border-primary/30 bg-primary/5 p-6">
                <div className="flex items-start gap-4">
                  <CheckCircle className="h-6 w-6 text-primary shrink-0 mt-0.5" />
                  <div>
                    <h3 className="font-semibold text-foreground">Build Verified</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      This app{"'"}s published WASM binary matches the build from the public source 
                      repository. You can verify this yourself by compiling from source.
                    </p>
                  </div>
                </div>
              </div>
            </section>
          )}
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}
