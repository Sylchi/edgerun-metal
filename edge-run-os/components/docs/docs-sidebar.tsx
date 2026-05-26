"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { ChevronRight } from "lucide-react"
import { cn } from "@/lib/utils"
import { docsNavigation, type DocSection } from "@/lib/docs-navigation"
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible"
import { ScrollArea } from "@/components/ui/scroll-area"

function NavItem({ item, level = 0 }: { item: DocSection; level?: number }) {
  const pathname = usePathname()
  const isActive = pathname === item.href
  const isParentActive = pathname.startsWith(item.href + "/")
  const hasChildren = item.items && item.items.length > 0

  if (hasChildren) {
    return (
      <Collapsible defaultOpen={isActive || isParentActive}>
        <CollapsibleTrigger className="group flex w-full items-center justify-between rounded-md px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground transition-colors">
          <span>{item.title}</span>
          <ChevronRight className="h-4 w-4 transition-transform group-data-[state=open]:rotate-90" />
        </CollapsibleTrigger>
        <CollapsibleContent>
          <div className="ml-3 border-l border-border pl-3 mt-1">
            {item.items!.map((child) => (
              <NavItem key={child.href} item={child} level={level + 1} />
            ))}
          </div>
        </CollapsibleContent>
      </Collapsible>
    )
  }

  return (
    <Link
      href={item.href}
      className={cn(
        "block rounded-md px-3 py-2 text-sm transition-colors",
        isActive
          ? "bg-primary/10 text-primary font-medium"
          : "text-muted-foreground hover:bg-muted hover:text-foreground"
      )}
    >
      {item.title}
    </Link>
  )
}

export function DocsSidebar() {
  return (
    <aside className="hidden w-64 shrink-0 lg:block">
      <div className="sticky top-16 h-[calc(100vh-4rem)]">
        <ScrollArea className="h-full py-6 pr-4">
          <nav className="space-y-1">
            {docsNavigation.map((section) => (
              <NavItem key={section.href} item={section} />
            ))}
          </nav>
        </ScrollArea>
      </div>
    </aside>
  )
}

export function DocsMobileNav() {
  const pathname = usePathname()
  
  // Find current section
  let currentSection = ""
  for (const section of docsNavigation) {
    if (pathname.startsWith(section.href)) {
      currentSection = section.title
      break
    }
  }

  return (
    <div className="lg:hidden border-b border-border bg-card/50 px-4 py-3">
      <Collapsible>
        <CollapsibleTrigger className="flex w-full items-center justify-between text-sm">
          <span className="font-medium">{currentSection || "Documentation"}</span>
          <ChevronRight className="h-4 w-4 transition-transform data-[state=open]:rotate-90" />
        </CollapsibleTrigger>
        <CollapsibleContent>
          <nav className="mt-4 space-y-1">
            {docsNavigation.map((section) => (
              <NavItem key={section.href} item={section} />
            ))}
          </nav>
        </CollapsibleContent>
      </Collapsible>
    </div>
  )
}
