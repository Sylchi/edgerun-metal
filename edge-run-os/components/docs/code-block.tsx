"use client"

import { useState } from "react"
import { Check, Copy } from "lucide-react"
import { cn } from "@/lib/utils"

type Props = {
  code: string
  language?: string
  filename?: string
  showLineNumbers?: boolean
  highlightLines?: number[]
}

export function CodeBlock({
  code,
  language = "text",
  filename,
  showLineNumbers = true,
  highlightLines = [],
}: Props) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const lines = code.split("\n")

  return (
    <div className="group relative my-6 overflow-hidden rounded-lg border border-border bg-[#0a0a0a]">
      {/* Header */}
      {filename && (
        <div className="flex items-center justify-between border-b border-border bg-card/50 px-4 py-2">
          <span className="text-xs font-mono text-muted-foreground">{filename}</span>
          <span className="text-xs text-muted-foreground">{language}</span>
        </div>
      )}

      {/* Copy button */}
      <button
        onClick={handleCopy}
        className="absolute right-3 top-3 rounded-md bg-muted/50 p-2 text-muted-foreground opacity-0 transition-opacity hover:bg-muted hover:text-foreground group-hover:opacity-100"
        aria-label="Copy code"
      >
        {copied ? <Check className="h-4 w-4 text-primary" /> : <Copy className="h-4 w-4" />}
      </button>

      {/* Code */}
      <div className="overflow-x-auto p-4">
        <pre className="text-sm leading-relaxed">
          <code className={`language-${language}`}>
            {lines.map((line, index) => (
              <div
                key={index}
                className={cn(
                  "flex",
                  highlightLines.includes(index + 1) && "bg-primary/10 -mx-4 px-4"
                )}
              >
                {showLineNumbers && (
                  <span className="mr-4 inline-block w-8 select-none text-right text-muted-foreground/50">
                    {index + 1}
                  </span>
                )}
                <span className="flex-1">{line || " "}</span>
              </div>
            ))}
          </code>
        </pre>
      </div>
    </div>
  )
}

// Specialized version for Zig code
export function ZigCodeBlock(props: Omit<Props, "language">) {
  return <CodeBlock {...props} language="zig" />
}
