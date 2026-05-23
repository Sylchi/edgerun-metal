"use client"

import { useEffect, useState, useRef } from "react"
import { cn } from "@/lib/utils"

interface BootLine {
  text: string
  type: "info" | "success" | "warn" | "system"
  delay: number
}

const BOOT_SEQUENCE: BootLine[] = [
  { text: "EdgeRun v0.4.2-alpha", type: "system", delay: 0 },
  { text: "initializing wasm runtime...", type: "info", delay: 200 },
  { text: "✓ runtime loaded (2.1mb)", type: "success", delay: 600 },
  { text: "generating node keypair...", type: "info", delay: 800 },
  { text: "✓ ed25519 keypair ready", type: "success", delay: 1200 },
  { text: "bootstrapping DHT...", type: "info", delay: 1400 },
  { text: "  → found 847 peers", type: "info", delay: 2000 },
  { text: "  → connected to 12 nodes", type: "info", delay: 2400 },
  { text: "✓ mesh network active", type: "success", delay: 2800 },
  { text: "starting encrypted relay...", type: "info", delay: 3000 },
  { text: "✓ e2e relay ready", type: "success", delay: 3400 },
  { text: "", type: "system", delay: 3600 },
  { text: "your node is live", type: "system", delay: 3800 },
]

export function BootSequence({ onComplete }: { onComplete?: () => void }) {
  const [visibleLines, setVisibleLines] = useState<number>(0)
  const [nodeId, setNodeId] = useState<string>("")
  const [showCursor, setShowCursor] = useState(true)
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    // Generate a fake node ID
    const chars = "abcdef0123456789"
    let id = ""
    for (let i = 0; i < 16; i++) {
      id += chars[Math.floor(Math.random() * chars.length)]
    }
    setNodeId(id)
  }, [])

  useEffect(() => {
    BOOT_SEQUENCE.forEach((line, index) => {
      setTimeout(() => {
        setVisibleLines(index + 1)
        if (index === BOOT_SEQUENCE.length - 1) {
          setTimeout(() => {
            onComplete?.()
          }, 500)
        }
      }, line.delay)
    })
  }, [onComplete])

  useEffect(() => {
    const interval = setInterval(() => {
      setShowCursor(prev => !prev)
    }, 530)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight
    }
  }, [visibleLines])

  return (
    <div 
      ref={containerRef}
      className="font-mono text-sm leading-relaxed overflow-hidden"
    >
      <div className="text-muted-foreground mb-2">$ edgerun start</div>
      {BOOT_SEQUENCE.slice(0, visibleLines).map((line, i) => (
        <div
          key={i}
          className={cn(
            "transition-opacity duration-200",
            line.type === "success" && "text-primary",
            line.type === "warn" && "text-yellow-500",
            line.type === "info" && "text-muted-foreground",
            line.type === "system" && "text-foreground font-semibold"
          )}
        >
          {line.text}
        </div>
      ))}
      {visibleLines >= BOOT_SEQUENCE.length && (
        <div className="mt-4 space-y-2">
          <div className="flex items-center gap-2">
            <span className="text-muted-foreground">node:</span>
            <span className="text-primary font-semibold tracking-wider">
              {nodeId}
            </span>
            <button 
              className="text-xs text-muted-foreground hover:text-foreground transition-colors"
              onClick={() => navigator.clipboard.writeText(nodeId)}
            >
              [copy]
            </button>
          </div>
          <div className="text-muted-foreground text-xs">
            share this id to connect with others — no account needed
          </div>
        </div>
      )}
      {visibleLines < BOOT_SEQUENCE.length && (
        <span className={cn(
          "inline-block w-2 h-4 bg-primary ml-0.5 translate-y-0.5",
          showCursor ? "opacity-100" : "opacity-0"
        )} />
      )}
    </div>
  )
}

export function BootSequenceCompact() {
  const [phase, setPhase] = useState<"booting" | "ready">("booting")
  const [nodeId, setNodeId] = useState("")
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    const chars = "abcdef0123456789"
    let id = ""
    for (let i = 0; i < 12; i++) {
      id += chars[Math.floor(Math.random() * chars.length)]
    }
    setNodeId(id)

    const interval = setInterval(() => {
      setProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval)
          setPhase("ready")
          return 100
        }
        return prev + Math.random() * 15 + 5
      })
    }, 150)

    return () => clearInterval(interval)
  }, [])

  if (phase === "booting") {
    return (
      <div className="flex items-center gap-3 font-mono text-sm">
        <div className="w-2 h-2 rounded-full bg-yellow-500 animate-pulse" />
        <span className="text-muted-foreground">starting node...</span>
        <span className="text-primary">{Math.min(100, Math.floor(progress))}%</span>
      </div>
    )
  }

  return (
    <div className="flex items-center gap-3 font-mono text-sm">
      <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
      <span className="text-muted-foreground">your node:</span>
      <span className="text-primary font-semibold">{nodeId}</span>
    </div>
  )
}
