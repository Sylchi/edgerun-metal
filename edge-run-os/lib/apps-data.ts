export type App = {
  id: string
  name: string
  developer: string
  description: string
  shortDescription: string
  icon: string
  category: AppCategory
  version: string
  wasmSize: string
  permissions: string[]
  verified: boolean
  featured?: boolean
  downloads: number
  rating: number
  sourceUrl?: string
  screenshots?: string[]
}

export type AppCategory =
  | "communication"
  | "productivity"
  | "developer-tools"
  | "security"
  | "media"
  | "finance"
  | "utilities"

export const categoryLabels: Record<AppCategory, string> = {
  communication: "Communication",
  productivity: "Productivity",
  "developer-tools": "Developer Tools",
  security: "Security",
  media: "Media",
  finance: "Finance",
  utilities: "Utilities",
}

export const categoryIcons: Record<AppCategory, string> = {
  communication: "MessageSquare",
  productivity: "Briefcase",
  "developer-tools": "Code",
  security: "Shield",
  media: "Play",
  finance: "Wallet",
  utilities: "Settings",
}

// Sample apps data
export const apps: App[] = [
  {
    id: "edgerun-messenger",
    name: "EdgeRun Messenger",
    developer: "EdgeRun Team",
    description: `A fully encrypted peer-to-peer messaging application. Messages are sealed before they leave your device and can only be decrypted by the intended recipient. No servers ever see your conversations.

Features:
- End-to-end encryption with forward secrecy
- Group chats with cryptographic membership
- Voice messages with Opus codec
- File sharing up to 100MB
- Offline message queuing via relay nodes

Built on edgerun-crypto for maximum security.`,
    shortDescription: "E2E encrypted peer-to-peer messaging",
    icon: "MessageSquare",
    category: "communication",
    version: "1.2.0",
    wasmSize: "2.4 MB",
    permissions: ["network", "storage", "microphone"],
    verified: true,
    featured: true,
    downloads: 12500,
    rating: 4.8,
    sourceUrl: "https://github.com/edgerun/messenger",
  },
  {
    id: "edgerun-vault",
    name: "EdgeRun Vault",
    developer: "EdgeRun Team",
    description: `Secure password and secrets management that never leaves your device. Your vault is encrypted with keys derived from your master password using Argon2id.

Features:
- Zero-knowledge architecture
- TOTP authenticator built-in
- Secure password generator
- Cross-device sync via encrypted objects
- Auto-fill for web apps`,
    shortDescription: "Zero-knowledge password manager",
    icon: "Lock",
    category: "security",
    version: "2.0.1",
    wasmSize: "1.8 MB",
    permissions: ["storage", "clipboard"],
    verified: true,
    featured: true,
    downloads: 8900,
    rating: 4.9,
    sourceUrl: "https://github.com/edgerun/vault",
  },
  {
    id: "edgerun-notes",
    name: "EdgeRun Notes",
    developer: "EdgeRun Team",
    description: `Markdown-powered note-taking with real-time sync. Notes are stored as encrypted objects and synced across your devices.

Features:
- Full markdown support with preview
- Folder organization
- Full-text search (local)
- Tags and backlinks
- Export to PDF/HTML`,
    shortDescription: "Encrypted markdown notes",
    icon: "FileText",
    category: "productivity",
    version: "1.5.0",
    wasmSize: "1.2 MB",
    permissions: ["storage"],
    verified: true,
    downloads: 6700,
    rating: 4.6,
  },
  {
    id: "code-editor",
    name: "Code Editor",
    developer: "Community",
    description: `A lightweight code editor for EdgeRun app development. Supports Zig, C, and common web languages.

Features:
- Syntax highlighting for 20+ languages
- LSP support via WebAssembly
- Git integration
- Multiple tabs and split views
- Customizable themes`,
    shortDescription: "Lightweight code editor for EdgeRun development",
    icon: "Code",
    category: "developer-tools",
    version: "0.9.0",
    wasmSize: "4.5 MB",
    permissions: ["storage", "network"],
    verified: false,
    downloads: 3200,
    rating: 4.2,
    sourceUrl: "https://github.com/community/edgerun-code",
  },
  {
    id: "peer-call",
    name: "PeerCall",
    developer: "Community",
    description: `Video calling over EdgeRun's P2P network. Direct connections mean no servers routing your video.

Features:
- 1080p video calls
- Screen sharing
- Up to 8 participants
- End-to-end encrypted
- No account required`,
    shortDescription: "P2P video calls",
    icon: "Video",
    category: "communication",
    version: "1.0.0",
    wasmSize: "6.2 MB",
    permissions: ["network", "camera", "microphone"],
    verified: true,
    downloads: 4500,
    rating: 4.4,
  },
  {
    id: "file-share",
    name: "FileShare",
    developer: "Community",
    description: `Share files directly between devices without any server storage. Files are chunked, encrypted, and streamed peer-to-peer.

Features:
- No file size limits
- Resume interrupted transfers
- QR code sharing
- Batch uploads
- Progress tracking`,
    shortDescription: "Direct P2P file transfers",
    icon: "Share2",
    category: "utilities",
    version: "1.1.0",
    wasmSize: "0.8 MB",
    permissions: ["network", "storage"],
    verified: true,
    downloads: 7800,
    rating: 4.7,
  },
  {
    id: "wallet",
    name: "EdgeWallet",
    developer: "Community",
    description: `Cryptocurrency wallet with support for multiple chains. Your keys never leave your device.

Features:
- Multi-chain support (BTC, ETH, SOL)
- Hardware wallet integration
- Transaction history
- Address book
- QR code scanning`,
    shortDescription: "Multi-chain crypto wallet",
    icon: "Wallet",
    category: "finance",
    version: "0.8.0",
    wasmSize: "3.1 MB",
    permissions: ["storage", "camera"],
    verified: false,
    downloads: 2100,
    rating: 4.0,
    sourceUrl: "https://github.com/community/edgewallet",
  },
  {
    id: "media-player",
    name: "MediaPlayer",
    developer: "Community",
    description: `Local media player for audio and video. Supports common formats via FFmpeg compiled to WASM.

Features:
- MP4, WebM, MKV, MP3, FLAC support
- Playlist management
- Subtitle support
- Equalizer
- Chromecast support`,
    shortDescription: "Local audio/video player",
    icon: "Play",
    category: "media",
    version: "1.3.0",
    wasmSize: "8.4 MB",
    permissions: ["storage"],
    verified: true,
    downloads: 5600,
    rating: 4.5,
  },
]

export function getApp(id: string): App | undefined {
  return apps.find((app) => app.id === id)
}

export function getApps(): App[] {
  return apps
}

export function getFeaturedApps(): App[] {
  return apps.filter((app) => app.featured)
}

export function getAppsByCategory(category: AppCategory): App[] {
  return apps.filter((app) => app.category === category)
}

export function getCategories(): AppCategory[] {
  return Object.keys(categoryLabels) as AppCategory[]
}
