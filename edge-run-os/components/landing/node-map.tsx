"use client"

import { useEffect, useRef, useState, useCallback } from "react"

interface Node {
  id: string
  x: number
  y: number
  lat: number
  lng: number
  online: boolean
  pulsePhase: number
  lastChange: number
}

// Major population centers weighted by internet penetration
const CITY_COORDS = [
  // North America
  { lat: 40.7, lng: -74, weight: 3 },   // NYC
  { lat: 34, lng: -118.2, weight: 2 },  // LA
  { lat: 37.8, lng: -122.4, weight: 2 }, // SF
  { lat: 51.5, lng: -0.1, weight: 3 },  // London
  { lat: 48.9, lng: 2.3, weight: 2 },   // Paris
  { lat: 52.5, lng: 13.4, weight: 2 },  // Berlin
  { lat: 35.7, lng: 139.7, weight: 3 }, // Tokyo
  { lat: 37.6, lng: 127, weight: 2 },   // Seoul
  { lat: 22.3, lng: 114.2, weight: 2 }, // Hong Kong
  { lat: 1.3, lng: 103.8, weight: 2 },  // Singapore
  { lat: -33.9, lng: 151.2, weight: 1 }, // Sydney
  { lat: 55.8, lng: 37.6, weight: 2 },  // Moscow
  { lat: 19.4, lng: -99.1, weight: 1 }, // Mexico City
  { lat: -23.5, lng: -46.6, weight: 1 }, // Sao Paulo
  { lat: 28.6, lng: 77.2, weight: 2 },  // Delhi
  { lat: 31.2, lng: 121.5, weight: 2 }, // Shanghai
  { lat: 39.9, lng: 116.4, weight: 2 }, // Beijing
  { lat: 25, lng: 121.5, weight: 1 },   // Taipei
  { lat: 59.3, lng: 18.1, weight: 1 },  // Stockholm
  { lat: 52.4, lng: 4.9, weight: 1 },   // Amsterdam
  { lat: 43.7, lng: -79.4, weight: 1 }, // Toronto
  { lat: 47.6, lng: -122.3, weight: 1 }, // Seattle
  { lat: 41.9, lng: -87.6, weight: 1 }, // Chicago
  { lat: 50.1, lng: 8.7, weight: 1 },   // Frankfurt
  { lat: 45.5, lng: 9.2, weight: 1 },   // Milan
]

function generateNodeNearCity(): { lat: number; lng: number } {
  const city = CITY_COORDS[Math.floor(Math.random() * CITY_COORDS.length)]
  // Add some randomness around the city (roughly 500km radius)
  const latOffset = (Math.random() - 0.5) * 8
  const lngOffset = (Math.random() - 0.5) * 8
  return {
    lat: Math.max(-60, Math.min(70, city.lat + latOffset)),
    lng: city.lng + lngOffset,
  }
}

function latLngToXY(lat: number, lng: number, width: number, height: number) {
  // Simple equirectangular projection
  const x = ((lng + 180) / 360) * width
  const y = ((90 - lat) / 140) * height - height * 0.1
  return { x, y }
}

export function NodeMap() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [nodes, setNodes] = useState<Node[]>([])
  const [stats, setStats] = useState({ online: 0, total: 0, bandwidth: 0 })
  const animationRef = useRef<number>()
  const lastFrameRef = useRef<number>(0)

  // Initialize nodes
  useEffect(() => {
    const initialNodes: Node[] = []
    for (let i = 0; i < 150; i++) {
      const { lat, lng } = generateNodeNearCity()
      initialNodes.push({
        id: `node-${i}`,
        x: 0,
        y: 0,
        lat,
        lng,
        online: Math.random() > 0.3,
        pulsePhase: Math.random() * Math.PI * 2,
        lastChange: Date.now() - Math.random() * 10000,
      })
    }
    setNodes(initialNodes)
  }, [])

  // Update stats
  useEffect(() => {
    const online = nodes.filter(n => n.online).length
    setStats({
      online,
      total: nodes.length,
      bandwidth: online * 12.4 + Math.random() * 50,
    })
  }, [nodes])

  // Randomly toggle nodes
  useEffect(() => {
    const interval = setInterval(() => {
      setNodes(prev => {
        const newNodes = [...prev]
        // Toggle 1-3 random nodes
        const toggleCount = Math.floor(Math.random() * 3) + 1
        for (let i = 0; i < toggleCount; i++) {
          const idx = Math.floor(Math.random() * newNodes.length)
          newNodes[idx] = {
            ...newNodes[idx],
            online: !newNodes[idx].online,
            lastChange: Date.now(),
          }
        }
        return newNodes
      })
    }, 800)
    return () => clearInterval(interval)
  }, [])

  const draw = useCallback((timestamp: number) => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext("2d")
    if (!ctx) return

    const rect = canvas.getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1
    
    if (canvas.width !== rect.width * dpr || canvas.height !== rect.height * dpr) {
      canvas.width = rect.width * dpr
      canvas.height = rect.height * dpr
      ctx.scale(dpr, dpr)
    }

    const width = rect.width
    const height = rect.height

    // Clear with slight trail effect
    ctx.fillStyle = "rgba(10, 10, 10, 0.15)"
    ctx.fillRect(0, 0, width, height)

    // Draw dot grid for continents (simplified)
    ctx.fillStyle = "rgba(255, 255, 255, 0.03)"
    const gridSize = 12
    for (let x = 0; x < width; x += gridSize) {
      for (let y = 0; y < height; y += gridSize) {
        // Simple land mask approximation
        const lng = (x / width) * 360 - 180
        const lat = 90 - (y / height) * 140
        if (isLand(lat, lng)) {
          ctx.beginPath()
          ctx.arc(x, y, 1, 0, Math.PI * 2)
          ctx.fill()
        }
      }
    }

    // Draw connections between nearby online nodes
    const onlineNodes = nodes.filter(n => n.online).map(n => ({
      ...n,
      ...latLngToXY(n.lat, n.lng, width, height)
    }))

    ctx.strokeStyle = "rgba(74, 222, 128, 0.08)"
    ctx.lineWidth = 0.5
    for (let i = 0; i < onlineNodes.length; i++) {
      for (let j = i + 1; j < onlineNodes.length; j++) {
        const dx = onlineNodes[i].x - onlineNodes[j].x
        const dy = onlineNodes[i].y - onlineNodes[j].y
        const dist = Math.sqrt(dx * dx + dy * dy)
        if (dist < 100) {
          ctx.beginPath()
          ctx.moveTo(onlineNodes[i].x, onlineNodes[i].y)
          ctx.lineTo(onlineNodes[j].x, onlineNodes[j].y)
          ctx.stroke()
        }
      }
    }

    // Draw nodes
    const now = Date.now()
    nodes.forEach(node => {
      const { x, y } = latLngToXY(node.lat, node.lng, width, height)
      const timeSinceChange = now - node.lastChange
      const recentlyChanged = timeSinceChange < 2000
      
      if (node.online) {
        // Pulsing glow for online nodes
        const pulse = Math.sin(timestamp / 1000 + node.pulsePhase) * 0.3 + 0.7
        const baseAlpha = recentlyChanged ? 1 : 0.8
        
        // Outer glow
        const gradient = ctx.createRadialGradient(x, y, 0, x, y, 8 * pulse)
        gradient.addColorStop(0, `rgba(74, 222, 128, ${baseAlpha * 0.6})`)
        gradient.addColorStop(1, "rgba(74, 222, 128, 0)")
        ctx.fillStyle = gradient
        ctx.beginPath()
        ctx.arc(x, y, 8 * pulse, 0, Math.PI * 2)
        ctx.fill()

        // Core dot
        ctx.fillStyle = `rgba(74, 222, 128, ${baseAlpha})`
        ctx.beginPath()
        ctx.arc(x, y, 2, 0, Math.PI * 2)
        ctx.fill()

        // Ripple effect for recently changed
        if (recentlyChanged) {
          const rippleProgress = timeSinceChange / 2000
          const rippleRadius = rippleProgress * 30
          const rippleAlpha = (1 - rippleProgress) * 0.5
          ctx.strokeStyle = `rgba(74, 222, 128, ${rippleAlpha})`
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.arc(x, y, rippleRadius, 0, Math.PI * 2)
          ctx.stroke()
        }
      } else {
        // Dim dot for offline nodes
        ctx.fillStyle = "rgba(255, 255, 255, 0.1)"
        ctx.beginPath()
        ctx.arc(x, y, 1.5, 0, Math.PI * 2)
        ctx.fill()

        // Fade out effect for recently disconnected
        if (recentlyChanged) {
          const fadeProgress = timeSinceChange / 2000
          const fadeAlpha = (1 - fadeProgress) * 0.4
          ctx.fillStyle = `rgba(239, 68, 68, ${fadeAlpha})`
          ctx.beginPath()
          ctx.arc(x, y, 3 * (1 - fadeProgress), 0, Math.PI * 2)
          ctx.fill()
        }
      }
    })

    animationRef.current = requestAnimationFrame(draw)
  }, [nodes])

  useEffect(() => {
    animationRef.current = requestAnimationFrame(draw)
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current)
      }
    }
  }, [draw])

  return (
    <div className="relative w-full h-full">
      <canvas
        ref={canvasRef}
        className="w-full h-full"
        style={{ background: "transparent" }}
      />
      {/* Live stats overlay */}
      <div className="absolute bottom-4 left-4 font-mono text-xs space-y-1">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-primary animate-pulse" />
          <span className="text-primary">{stats.online}</span>
          <span className="text-muted-foreground">nodes online</span>
        </div>
        <div className="text-muted-foreground">
          {stats.bandwidth.toFixed(1)} TB/s mesh bandwidth
        </div>
      </div>
    </div>
  )
}

// Very simplified land detection
function isLand(lat: number, lng: number): boolean {
  // North America
  if (lat > 25 && lat < 70 && lng > -130 && lng < -60) return true
  // South America
  if (lat > -55 && lat < 10 && lng > -80 && lng < -35) return true
  // Europe
  if (lat > 35 && lat < 70 && lng > -10 && lng < 40) return true
  // Africa
  if (lat > -35 && lat < 35 && lng > -20 && lng < 50) return true
  // Asia
  if (lat > 10 && lat < 70 && lng > 40 && lng < 145) return true
  // Australia
  if (lat > -45 && lat < -10 && lng > 110 && lng < 155) return true
  // Japan/Korea
  if (lat > 30 && lat < 45 && lng > 125 && lng < 145) return true
  return false
}
