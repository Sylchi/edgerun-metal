"use client"

import { useEffect, useState } from "react"

interface Stat {
  label: string
  value: number
  suffix: string
  decimals?: number
}

const STATS: Stat[] = [
  { label: "Active Nodes", value: 12847, suffix: "" },
  { label: "Mesh Bandwidth", value: 847.3, suffix: " TB/s", decimals: 1 },
  { label: "Messages Today", value: 2.4, suffix: "M", decimals: 1 },
  { label: "Zero Accounts Created", value: 0, suffix: "" },
]

function AnimatedNumber({ 
  value, 
  decimals = 0,
  duration = 2000 
}: { 
  value: number
  decimals?: number
  duration?: number 
}) {
  const [display, setDisplay] = useState(0)

  useEffect(() => {
    const start = performance.now()
    const startValue = 0

    function update(now: number) {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      const current = startValue + (value - startValue) * eased
      
      setDisplay(current)

      if (progress < 1) {
        requestAnimationFrame(update)
      }
    }

    requestAnimationFrame(update)
  }, [value, duration])

  return <>{decimals > 0 ? display.toFixed(decimals) : Math.floor(display).toLocaleString()}</>
}

export function LiveStats() {
  const [stats, setStats] = useState(STATS)

  // Simulate live updates
  useEffect(() => {
    const interval = setInterval(() => {
      setStats(prev => prev.map(stat => {
        if (stat.label === "Zero Accounts Created") return stat
        const variance = stat.value * 0.001
        return {
          ...stat,
          value: stat.value + (Math.random() - 0.5) * variance
        }
      }))
    }, 3000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8">
      {stats.map((stat) => (
        <div key={stat.label} className="text-center md:text-left">
          <div className="font-mono text-2xl md:text-3xl font-bold text-foreground">
            <AnimatedNumber value={stat.value} decimals={stat.decimals} />
            <span className="text-primary">{stat.suffix}</span>
          </div>
          <div className="text-sm text-muted-foreground mt-1">
            {stat.label}
          </div>
        </div>
      ))}
    </div>
  )
}

// Traffic concentration visualization
export function TrafficConcentration() {
  const companies = [
    { name: "Cloudflare", percent: 19.5, color: "bg-orange-500" },
    { name: "Google", percent: 15.2, color: "bg-blue-500" },
    { name: "Fastly", percent: 8.3, color: "bg-red-500" },
    { name: "Amazon", percent: 7.8, color: "bg-yellow-500" },
    { name: "Akamai", percent: 6.1, color: "bg-cyan-500" },
    { name: "Others", percent: 43.1, color: "bg-muted" },
  ]

  const [animated, setAnimated] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setAnimated(true), 500)
    return () => clearTimeout(timer)
  }, [])

  return (
    <div className="space-y-4">
      <div className="text-sm text-muted-foreground mb-4">
        Global web traffic through top 5 companies
      </div>
      
      {/* Stacked bar */}
      <div className="h-8 rounded-sm overflow-hidden flex">
        {companies.map((company, i) => (
          <div
            key={company.name}
            className={`${company.color} transition-all duration-1000 ease-out flex items-center justify-center`}
            style={{ 
              width: animated ? `${company.percent}%` : "0%",
              transitionDelay: `${i * 100}ms`
            }}
          >
            {company.percent > 10 && (
              <span className="text-xs font-mono text-black/70 font-medium">
                {company.percent}%
              </span>
            )}
          </div>
        ))}
      </div>

      {/* Legend */}
      <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs">
        {companies.slice(0, -1).map((company) => (
          <div key={company.name} className="flex items-center gap-1.5">
            <div className={`w-2 h-2 rounded-sm ${company.color}`} />
            <span className="text-muted-foreground">{company.name}</span>
            <span className="font-mono text-foreground">{company.percent}%</span>
          </div>
        ))}
      </div>

      <div className="text-xs text-muted-foreground pt-2 border-t border-border">
        <span className="text-primary font-semibold">56.9%</span> of internet traffic 
        flows through just 5 companies. Your data. Their servers.
      </div>
    </div>
  )
}
