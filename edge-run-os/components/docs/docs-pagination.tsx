import Link from "next/link"
import { ArrowLeft, ArrowRight } from "lucide-react"

type Props = {
  prev?: { title: string; href: string }
  next?: { title: string; href: string }
}

export function DocsPagination({ prev, next }: Props) {
  return (
    <div className="mt-16 flex items-center justify-between border-t border-border pt-8">
      {prev ? (
        <Link
          href={prev.href}
          className="group flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          <ArrowLeft className="h-4 w-4 transition-transform group-hover:-translate-x-1" />
          <div>
            <div className="text-xs text-muted-foreground">Previous</div>
            <div className="font-medium text-foreground">{prev.title}</div>
          </div>
        </Link>
      ) : (
        <div />
      )}

      {next ? (
        <Link
          href={next.href}
          className="group flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors text-right"
        >
          <div>
            <div className="text-xs text-muted-foreground">Next</div>
            <div className="font-medium text-foreground">{next.title}</div>
          </div>
          <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
        </Link>
      ) : (
        <div />
      )}
    </div>
  )
}
