import type { Metadata } from "next"
import Link from "next/link"
import { notFound } from "next/navigation"
import { ArrowLeft, Calendar, Clock, Tag, ExternalLink } from "lucide-react"
import { SiteHeader, SiteFooter } from "@/components/shared"
import { GitCodeBlock, BenchmarkChart, MethodologySection } from "@/components/blog"
import { getBlogPost, getBlogPosts } from "@/lib/blog-data"

type Props = {
  params: Promise<{ slug: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const post = getBlogPost(slug)
  
  if (!post) {
    return { title: "Post Not Found" }
  }

  return {
    title: post.title,
    description: post.description,
  }
}

export function generateStaticParams() {
  const posts = getBlogPosts()
  return posts.map((post) => ({ slug: post.slug }))
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params
  const post = getBlogPost(slug)

  if (!post) {
    notFound()
  }

  // Example content for the featured post - in production this would come from MDX
  const isBlake3Post = slug === "blake3-performance-analysis"

  return (
    <div className="flex min-h-screen flex-col">
      <SiteHeader />
      <main className="flex-1">
        <article className="mx-auto max-w-4xl px-4 py-16 lg:px-8">
          {/* Back link */}
          <Link
            href="/blog"
            className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors mb-8"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Blog
          </Link>

          {/* Header */}
          <header className="mb-12">
            <div className="flex flex-wrap gap-2 mb-4">
              {post.tags.map((tag) => (
                <span
                  key={tag}
                  className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-3 py-1 text-sm font-medium text-primary"
                >
                  <Tag className="h-3 w-3" />
                  {tag}
                </span>
              ))}
            </div>

            <h1 className="text-3xl font-bold tracking-tight text-foreground sm:text-4xl lg:text-5xl text-balance">
              {post.title}
            </h1>

            <p className="mt-6 text-xl text-muted-foreground leading-relaxed">
              {post.description}
            </p>

            <div className="mt-8 flex items-center gap-6 text-sm text-muted-foreground border-t border-border pt-6">
              <div className="flex items-center gap-2">
                <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center">
                  <span className="text-xs font-semibold text-primary">
                    {post.author.name.charAt(0)}
                  </span>
                </div>
                <span className="font-medium text-foreground">{post.author.name}</span>
              </div>
              <div className="flex items-center gap-1.5">
                <Calendar className="h-4 w-4" />
                <time dateTime={post.date}>
                  {new Date(post.date).toLocaleDateString("en-US", {
                    month: "long",
                    day: "numeric",
                    year: "numeric",
                  })}
                </time>
              </div>
              <div className="flex items-center gap-1.5">
                <Clock className="h-4 w-4" />
                <span>{post.readingTime}</span>
              </div>
            </div>
          </header>

          {/* Content - Example for BLAKE3 post */}
          {isBlake3Post ? (
            <div className="prose prose-invert max-w-none">
              <p>
                When building a system like EdgeRun, cryptographic hash functions are foundational. 
                They are used for content addressing, integrity verification, key derivation, and 
                countless other operations. Choosing the right hash function is critical for both 
                security and performance.
              </p>

              <h2 id="why-blake3">Why BLAKE3?</h2>
              
              <p>
                After extensive benchmarking and analysis, we chose BLAKE3 as EdgeRun{"'"}s primary 
                hash function. Here{"'"}s why:
              </p>

              <ul>
                <li><strong>Speed</strong>: BLAKE3 is significantly faster than SHA-256 and SHA-3</li>
                <li><strong>Parallelism</strong>: Built-in tree hashing enables SIMD and multi-threaded operation</li>
                <li><strong>Security</strong>: Based on the well-analyzed BLAKE2 design with improved margins</li>
                <li><strong>Simplicity</strong>: Single algorithm works as hash, MAC, KDF, and XOF</li>
              </ul>

              <h2 id="benchmark-results">Benchmark Results</h2>

              <p>
                We benchmarked BLAKE3 against SHA-256 and SHA-3-256 on typical EdgeRun workloads. 
                All tests were run on identical hardware with the same input data.
              </p>

              <BenchmarkChart
                title="Hash Throughput (1MB blocks)"
                data={[
                  { name: "BLAKE3 (SIMD)", value: 12500, unit: "MB/s" },
                  { name: "BLAKE3 (scalar)", value: 3200, unit: "MB/s" },
                  { name: "SHA-256 (hw accel)", value: 2100, unit: "MB/s" },
                  { name: "SHA-3-256", value: 850, unit: "MB/s" },
                ]}
                methodology="/docs/benchmarks/methodology"
                environment={{
                  cpu: "AMD Ryzen 9 5950X",
                  memory: "64GB DDR4-3600",
                  os: "EdgeRun Metal v0.1",
                  compiler: "Zig 0.13.0",
                }}
              />

              <p>
                BLAKE3 with SIMD instructions achieves nearly 6x the throughput of hardware-accelerated 
                SHA-256 and 15x that of SHA-3. Even without SIMD, scalar BLAKE3 outperforms SHA-256.
              </p>

              <h2 id="implementation">Implementation Details</h2>

              <p>
                Our BLAKE3 implementation in <code>edgerun-crypto</code> uses Zig{"'"}s comptime 
                features for optimal codegen. Here{"'"}s the core compression function:
              </p>

              <GitCodeBlock
                code={`const std = @import("std");

pub const BLAKE3 = struct {
    const BLOCK_LEN = 64;
    const CHUNK_LEN = 1024;
    const OUT_LEN = 32;
    
    // Initialization vector (first 8 words of fractional parts of sqrt(primes))
    const IV = [8]u32{
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    };
    
    state: [8]u32,
    chunk_state: ChunkState,
    cv_stack: [54][32]u8,
    cv_stack_len: u8,
    
    pub fn init() BLAKE3 {
        return .{
            .state = IV,
            .chunk_state = ChunkState.init(IV, 0, 0),
            .cv_stack = undefined,
            .cv_stack_len = 0,
        };
    }
    
    pub fn update(self: *BLAKE3, input: []const u8) void {
        // Process input in chunks, building Merkle tree
        var offset: usize = 0;
        while (offset < input.len) {
            if (self.chunk_state.len() == CHUNK_LEN) {
                const chunk_cv = self.chunk_state.output().chaining_value();
                self.push_cv(chunk_cv);
                self.chunk_state = ChunkState.init(
                    self.state,
                    self.chunk_state.chunk_counter + 1,
                    0
                );
            }
            const want = CHUNK_LEN - self.chunk_state.len();
            const take = @min(want, input.len - offset);
            self.chunk_state.update(input[offset..][0..take]);
            offset += take;
        }
    }
    
    pub fn final(self: *BLAKE3) [OUT_LEN]u8 {
        // Finalize the hash
        var output = self.chunk_state.output();
        var parent_nodes_remaining = self.cv_stack_len;
        while (parent_nodes_remaining > 0) {
            parent_nodes_remaining -= 1;
            output = parent_output(
                self.cv_stack[parent_nodes_remaining],
                output.chaining_value(),
                self.state,
                0
            );
        }
        return output.root_hash();
    }
};`}
                language="zig"
                filename="edgerun-crypto/src/blake3.zig"
                repo="edgerun/edgerun"
                path="edgerun-crypto/src/blake3.zig"
                commit="a3f2c89"
                lines="L1-L65"
                highlightLines={[15, 16, 17, 18]}
              />

              <p>
                The highlighted lines show the Merkle tree IV initialization. This enables 
                unlimited parallelism for large inputs.
              </p>

              <MethodologySection
                title="Benchmark Methodology"
                reproducibility={{
                  repo: "edgerun/edgerun",
                  branch: "benchmarks/blake3-v1",
                  command: "zig build bench -- --hash-throughput",
                }}
              >
                <p>
                  All benchmarks were run 100 times with results averaged. Input data was 
                  pre-allocated to eliminate allocation overhead. Cache was warmed with 3 
                  preliminary runs before measurement.
                </p>
                <p>
                  SIMD benchmarks used AVX-512 where available, falling back to AVX2. 
                  SHA-256 used Intel SHA extensions. All code was compiled with 
                  <code>-O ReleaseFast</code>.
                </p>
              </MethodologySection>

              <h2 id="conclusion">Conclusion</h2>

              <p>
                BLAKE3{"'"}s combination of speed, parallelism, and security makes it the ideal 
                choice for EdgeRun. Its unified design simplifies our codebase while providing 
                superior performance across all use cases.
              </p>

              <p>
                For more details on our cryptographic stack, see the{" "}
                <Link href="/docs/architecture/crypto" className="text-primary hover:underline">
                  Cryptographic Primitives
                </Link>{" "}
                documentation.
              </p>
            </div>
          ) : (
            <div className="prose prose-invert max-w-none">
              <p>
                This is a placeholder for the blog post content. In production, this would be 
                rendered from MDX files with support for custom components like GitCodeBlock, 
                BenchmarkChart, and MethodologySection.
              </p>
              <p>
                The blog system is designed to pull content directly from git repositories, 
                with code samples linking to specific commits for reproducibility and verification.
              </p>
            </div>
          )}
        </article>
      </main>
      <SiteFooter />
    </div>
  )
}
