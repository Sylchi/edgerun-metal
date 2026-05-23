"use client"

import { useState } from "react"
import Link from "next/link"
import { Check, Copy, ExternalLink, GitCommit } from "lucide-react"
import { cn } from "@/lib/utils"

type GitCodeBlockProps = {
  code: string
  language?: string
  filename?: string
  repo?: string
  path?: string
  commit?: string
  lines?: string
  showLineNumbers?: boolean
  highlightLines?: number[]
}

export function GitCodeBlock({
  code,
  language = "zig",
  filename,
  repo = "edgerun/edgerun",
  path,
  commit,
  lines,
  showLineNumbers = true,
  highlightLines = [],
}: GitCodeBlockProps) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const codeLines = code.split("\n")
  
  // Build GitHub URL
  const githubUrl = commit && path
    ? `https://github.com/${repo}/blob/${commit}/${path}${lines ? `#${lines}` : ""}`
    : null

  return (
    <div className="group relative my-6 overflow-hidden rounded-lg border border-border bg-[#0a0a0a]">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border bg-card/50 px-4 py-2">
        <div className="flex items-center gap-3">
          {filename && (
            <span className="text-xs font-mono text-muted-foreground">{filename}</span>
          )}
          {commit && (
            <div className="flex items-center gap-1.5 rounded-full bg-muted px-2 py-0.5">
              <GitCommit className="h-3 w-3 text-muted-foreground" />
              <span className="text-xs font-mono text-muted-foreground">
                {commit.slice(0, 7)}
              </span>
            </div>
          )}
        </div>
        <div className="flex items-center gap-2">
          {githubUrl && (
            <a
              href={githubUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 rounded-md bg-muted/50 px-2 py-1 text-xs text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            >
              <ExternalLink className="h-3 w-3" />
              View on GitHub
            </a>
          )}
          <span className="text-xs text-muted-foreground">{language}</span>
        </div>
      </div>

      {/* Copy button */}
      <button
        onClick={handleCopy}
        className="absolute right-3 top-12 rounded-md bg-muted/50 p-2 text-muted-foreground opacity-0 transition-opacity hover:bg-muted hover:text-foreground group-hover:opacity-100"
        aria-label="Copy code"
      >
        {copied ? <Check className="h-4 w-4 text-primary" /> : <Copy className="h-4 w-4" />}
      </button>

      {/* Code */}
      <div className="overflow-x-auto p-4">
        <pre className="text-sm leading-relaxed">
          <code className={`language-${language}`}>
            {codeLines.map((line, index) => (
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

// Benchmark visualization component
type BenchmarkData = {
  name: string
  value: number
  unit: string
}

type BenchmarkChartProps = {
  title: string
  data: BenchmarkData[]
  methodology?: string
  environment?: {
    cpu?: string
    memory?: string
    os?: string
    compiler?: string
  }
}

export function BenchmarkChart({
  title,
  data,
  methodology,
  environment,
}: BenchmarkChartProps) {
  const maxValue = Math.max(...data.map((d) => d.value))

  return (
    <div className="my-8 rounded-lg border border-border bg-card overflow-hidden">
      <div className="border-b border-border bg-muted/30 px-6 py-4">
        <h3 className="text-lg font-semibold text-foreground">{title}</h3>
        {methodology && (
          <Link
            href={methodology}
            className="text-sm text-primary hover:underline inline-flex items-center gap-1 mt-1"
          >
            View methodology
            <ExternalLink className="h-3 w-3" />
          </Link>
        )}
      </div>

      {/* Bar chart */}
      <div className="p-6 space-y-4">
        {data.map((item) => (
          <div key={item.name}>
            <div className="flex items-center justify-between text-sm mb-1">
              <span className="font-medium text-foreground">{item.name}</span>
              <span className="text-muted-foreground">
                {item.value.toLocaleString()} {item.unit}
              </span>
            </div>
            <div className="h-3 rounded-full bg-muted overflow-hidden">
              <div
                className="h-full rounded-full bg-primary transition-all duration-500"
                style={{ width: `${(item.value / maxValue) * 100}%` }}
              />
            </div>
          </div>
        ))}
      </div>

      {/* Environment specs */}
      {environment && (
        <div className="border-t border-border bg-muted/20 px-6 py-4">
          <p className="text-xs font-medium text-muted-foreground mb-2">Test Environment</p>
          <div className="grid grid-cols-2 gap-2 text-xs">
            {environment.cpu && (
              <div>
                <span className="text-muted-foreground">CPU:</span>{" "}
                <span className="text-foreground">{environment.cpu}</span>
              </div>
            )}
            {environment.memory && (
              <div>
                <span className="text-muted-foreground">Memory:</span>{" "}
                <span className="text-foreground">{environment.memory}</span>
              </div>
            )}
            {environment.os && (
              <div>
                <span className="text-muted-foreground">OS:</span>{" "}
                <span className="text-foreground">{environment.os}</span>
              </div>
            )}
            {environment.compiler && (
              <div>
                <span className="text-muted-foreground">Compiler:</span>{" "}
                <span className="text-foreground">{environment.compiler}</span>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// Methodology section component
type MethodologySectionProps = {
  title?: string
  children: React.ReactNode
  reproducibility?: {
    repo: string
    branch: string
    command: string
  }
}

export function MethodologySection({
  title = "Benchmark Methodology",
  children,
  reproducibility,
}: MethodologySectionProps) {
  return (
    <div className="my-8 rounded-lg border border-border bg-card/50 overflow-hidden">
      <div className="border-b border-border bg-muted/30 px-6 py-3">
        <h3 className="text-sm font-semibold text-foreground">{title}</h3>
      </div>
      <div className="p-6 text-sm text-muted-foreground prose prose-sm prose-invert max-w-none">
        {children}
      </div>
      {reproducibility && (
        <div className="border-t border-border bg-muted/20 px-6 py-4">
          <p className="text-xs font-medium text-muted-foreground mb-2">Reproduce These Results</p>
          <pre className="text-xs bg-background/50 p-3 rounded overflow-x-auto">
            <code>{`git clone https://github.com/${reproducibility.repo}.git
cd ${reproducibility.repo.split("/")[1]}
git checkout ${reproducibility.branch}
${reproducibility.command}`}</code>
          </pre>
        </div>
      )}
    </div>
  )
}
