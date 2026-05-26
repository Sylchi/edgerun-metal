"use client"

import { useState } from "react"
import { Check, Loader2, Download, ExternalLink, AlertCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Progress } from "@/components/ui/progress"
import { cn } from "@/lib/utils"

type CompilationStep = "idle" | "fetching" | "compiling" | "verifying" | "installing" | "complete" | "error"

const stepLabels: Record<CompilationStep, string> = {
  idle: "Compile & Install",
  fetching: "Fetching source...",
  compiling: "Compiling to WebAssembly...",
  verifying: "Verifying build hash...",
  installing: "Installing to runtime...",
  complete: "Installed",
  error: "Compilation failed",
}

const stepProgress: Record<CompilationStep, number> = {
  idle: 0,
  fetching: 20,
  compiling: 50,
  verifying: 75,
  installing: 90,
  complete: 100,
  error: 0,
}

export function CompileButton({ appId, sourceUrl }: { appId: string; sourceUrl?: string }) {
  const [step, setStep] = useState<CompilationStep>("idle")
  const [logs, setLogs] = useState<string[]>([])
  const [showLogs, setShowLogs] = useState(false)

  const handleCompile = async () => {
    if (!sourceUrl) return

    setStep("fetching")
    setLogs(["Starting compilation process..."])
    
    // Simulate compilation steps
    await new Promise((r) => setTimeout(r, 1500))
    setLogs((prev) => [...prev, `Fetching source from ${sourceUrl}...`])
    setLogs((prev) => [...prev, "Source fetched successfully (2.4 MB)"])
    
    setStep("compiling")
    await new Promise((r) => setTimeout(r, 2000))
    setLogs((prev) => [...prev, "Compiling Zig source to WebAssembly..."])
    setLogs((prev) => [...prev, "Optimizing for size (-Oz)..."])
    setLogs((prev) => [...prev, "Compilation complete (1.8 MB WASM)"])
    
    setStep("verifying")
    await new Promise((r) => setTimeout(r, 1000))
    setLogs((prev) => [...prev, "Computing build hash..."])
    setLogs((prev) => [...prev, "Hash: blake3:a3f2c89d7e1b4f6a..."])
    setLogs((prev) => [...prev, "Verifying against published hash..."])
    setLogs((prev) => [...prev, "Build verified successfully"])
    
    setStep("installing")
    await new Promise((r) => setTimeout(r, 1000))
    setLogs((prev) => [...prev, "Installing to EdgeRun runtime..."])
    setLogs((prev) => [...prev, "Registering permissions..."])
    setLogs((prev) => [...prev, "Installation complete"])
    
    setStep("complete")
  }

  const isProcessing = step !== "idle" && step !== "complete" && step !== "error"

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Button
          size="lg"
          disabled={isProcessing || step === "complete" || !sourceUrl}
          onClick={handleCompile}
          className={cn(
            "gap-2 min-w-[180px]",
            step === "complete" && "bg-primary/20 text-primary hover:bg-primary/30"
          )}
        >
          {step === "idle" && <Download className="h-4 w-4" />}
          {isProcessing && <Loader2 className="h-4 w-4 animate-spin" />}
          {step === "complete" && <Check className="h-4 w-4" />}
          {step === "error" && <AlertCircle className="h-4 w-4" />}
          {stepLabels[step]}
        </Button>

        {sourceUrl && (
          <Button variant="outline" size="lg" asChild>
            <a href={sourceUrl} target="_blank" rel="noopener noreferrer" className="gap-2">
              <ExternalLink className="h-4 w-4" />
              View Source
            </a>
          </Button>
        )}
      </div>

      {/* Progress bar */}
      {isProcessing && (
        <div className="space-y-2">
          <Progress value={stepProgress[step]} className="h-2" />
          <p className="text-sm text-muted-foreground">{stepLabels[step]}</p>
        </div>
      )}

      {/* Build logs */}
      {logs.length > 0 && (
        <div>
          <button
            onClick={() => setShowLogs(!showLogs)}
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            {showLogs ? "Hide" : "Show"} build logs
          </button>
          
          {showLogs && (
            <div className="mt-2 rounded-lg border border-border bg-[#0a0a0a] p-4 max-h-48 overflow-y-auto">
              <pre className="text-xs font-mono text-muted-foreground">
                {logs.map((log, i) => (
                  <div key={i} className="py-0.5">
                    <span className="text-muted-foreground/50">[{String(i + 1).padStart(2, "0")}]</span>{" "}
                    {log}
                  </div>
                ))}
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
