import type { Metadata } from "next"
import { Search } from "lucide-react"
import { SiteHeader, SiteFooter } from "@/components/shared"
import { AppCard, FeaturedAppCard, CategoryCard } from "@/components/apps"
import { getApps, getFeaturedApps, getAppsByCategory, getCategories, categoryLabels } from "@/lib/apps-data"
import { Input } from "@/components/ui/input"

export const metadata: Metadata = {
  title: "App Store",
  description: "Browse and install EdgeRun applications. All apps compile directly in your browser.",
}

export default function AppsPage() {
  const apps = getApps()
  const featuredApps = getFeaturedApps()
  const categories = getCategories()

  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <div className="mx-auto max-w-7xl px-4 py-16 lg:px-8">
          {/* Header */}
          <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
            <div className="max-w-2xl">
              <h1 className="text-4xl font-bold tracking-tight text-foreground">App Store</h1>
              <p className="mt-4 text-lg text-muted-foreground leading-relaxed">
                Browse EdgeRun applications. Every app compiles from source directly in your 
                browser — verify what you run.
              </p>
            </div>

            {/* Search */}
            <div className="relative w-full md:w-80">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                type="search"
                placeholder="Search apps..."
                className="pl-10"
              />
            </div>
          </div>

          {/* Featured apps */}
          {featuredApps.length > 0 && (
            <section className="mt-12">
              <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-6">
                Featured
              </h2>
              <div className="grid gap-6 md:grid-cols-2">
                {featuredApps.map((app) => (
                  <FeaturedAppCard key={app.id} app={app} />
                ))}
              </div>
            </section>
          )}

          {/* Categories */}
          <section className="mt-16">
            <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-6">
              Categories
            </h2>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {categories.map((category) => {
                const count = getAppsByCategory(category).length
                return (
                  <CategoryCard
                    key={category}
                    category={category}
                    label={categoryLabels[category]}
                    count={count}
                  />
                )
              })}
            </div>
          </section>

          {/* All apps */}
          <section className="mt-16">
            <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wider mb-6">
              All Apps
            </h2>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {apps.map((app) => (
                <AppCard key={app.id} app={app} />
              ))}
            </div>
          </section>
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}
