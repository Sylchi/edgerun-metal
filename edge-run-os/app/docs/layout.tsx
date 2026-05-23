import { SiteHeader, SiteFooter } from "@/components/shared"
import { DocsSidebar, DocsMobileNav } from "@/components/docs"

export default function DocsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <DocsMobileNav />
      <div className="mx-auto flex w-full max-w-7xl flex-1 px-4 lg:px-8">
        <DocsSidebar />
        <main className="min-w-0 flex-1 py-8 lg:pl-8">
          {children}
        </main>
      </div>
      <SiteFooter />
    </div>
  )
}
