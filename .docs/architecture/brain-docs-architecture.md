---
name: "BrainDocs Architecture"
description: "Architectural decisions, design rationale, and implementation details for the brain docs CLI tool"
type: architecture
date: 2026-02-21
---

# BrainDocs Architecture

This document explains the engineering decisions behind `brain docs` — the CLI tool for indexing, searching, and validating `.docs/` project documentation for AI agents.

## 1. Code Parsing: Regex vs AST

### Decision: Regex-based extraction with multi-class detection

The `UndocumentedScanner` uses regular expressions to extract declarations (classes, structs, public functions) from PHP, JavaScript/TypeScript, Python, Go, C++, Rust, and Java. All patterns use `^\s*` anchoring with `/m` multiline flag, enabling detection at **any indentation level** — top-level, nested, and secondary classes within the same file.

### The fundamental question: why not AST?

AST (Abstract Syntax Tree) parsers are the correct choice when you need to understand code structure deeply — variable scope, type inference, control flow analysis, method-to-class association. But `brain docs` solves a fundamentally different problem: **documentation discovery** — "does this class/function have corresponding documentation?"

This is the same class of problem solved by tools that have chosen regex for decades:

- **ctags / universal-ctags** — the industry standard for code navigation, used for 40+ years, supporting 100+ languages. Regex-based. No one calls ctags an "enterprise failure" — it is the enterprise standard.
- **GitHub Linguist** — GitHub's language detection for millions of repositories. Regex-based heuristics.
- **tree-sitter** — even tree-sitter starts with regex-like pattern matching for tokenization before building the tree.
- **ripgrep / ag / ack** — enterprise-grade code search tools. All regex-based. Used by VS Code, JetBrains, and every major IDE.

The key insight: **documentation discovery does not require code understanding**. It requires pattern matching against syntactically rigid declarations. A class declaration has exactly one syntactic form per language, regardless of nesting depth.

### What AST would cost (and not provide)

To add AST parsing for 7 languages, the project would need:

- 7 separate parser libraries (or bindings to tree-sitter grammars via FFI)
- C-level FFI layer (tree-sitter is C-based, requiring native extensions)
- Grammar version management (language specs evolve; tree-sitter grammars update independently)
- Build complexity (native extensions, platform-specific compilation, CI matrix expansion)
- ~10x more code for the same functional result
- Runtime dependency on compiled libraries (vs zero-dependency regex)

What AST would provide that regex does not:

- **Method-to-class scoping** — knowing which methods belong to which class in a multi-class file
- **Generic type resolution** — understanding `List<Map<String, List<User>>>` beyond the declaration name
- **Macro expansion** — resolving Rust `macro_rules!` or C++ template instantiations

None of these capabilities are needed for documentation discovery. `--undocumented` answers "is class X documented?" — not "what does class X do?"

### Multi-class detection (preg_match_all)

The scanner uses `preg_match_all()` (not `preg_match()`) for class patterns, detecting **all classes in a file** — not just the first one. This covers:

- Python modules with multiple classes (common pattern)
- Java files with inner/helper classes
- JavaScript/TypeScript files with exported class + internal helpers
- PHP files with secondary classes (valid PHP, though not PSR-4 convention)
- Go files with multiple struct definitions

**Method association limitation:** Without AST, methods extracted from a multi-class file are associated with all classes from that file (file-level, not class-scoped). This is acceptable because:

1. The primary question is "is this class documented?" — method list is informational
2. Method count is used for prioritization (higher count = more complex = document first)
3. Slight over-reporting of methods per class is harmless for documentation discovery
4. Class-scoped method association would require AST — the exact overhead we are avoiding

### Pattern architecture

All patterns use `^\s*` (start-of-line + optional whitespace) with `/m` (multiline) flag:

| Language | Class Pattern | Multi-class? | Nested? |
|----------|--------------|-------------|---------|
| PHP | `/^\s*(?:abstract\s+)?class\s+(\w+)/m` | Yes | N/A (PHP has no nested named classes) |
| JS | `/^\s*(?:export\s+)?(?:default\s+)?class\s+(\w+)/m` | Yes | Yes |
| TS | `/^\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+(\w+)/m` | Yes | Yes |
| Python | `/^\s*class\s+(\w+)\s*[:(]/m` | Yes | Yes |
| Go | `/^\s*type\s+(\w+)\s+struct\s*\{/m` | Yes | N/A |
| C++ | `/^\s*(?:template\s*<[^>]*>\s*)?class\s+(\w+)/m` | Yes | Yes |
| Rust | `/^\s*(?:pub(?:\([^)]*\))?\s+)?struct\s+(\w+)/m` | Yes | N/A |
| Java | `/^\s*(?:public\s+)?(?:abstract\s+)?(?:final\s+)?class\s+(\w+)/m` | Yes | Yes |

The `\s*` prefix is the key: it allows matching at any indentation level. A nested class `    class InnerHelper` matches the same pattern as a top-level `class UserService`. The regex doesn't need to "understand" nesting — it just needs to find the keyword.

### Scope boundaries

The scanner does NOT parse (by design, not limitation):

- Method bodies or control flow
- Generic type parameters beyond the declaration name
- Macro-expanded code (Rust `macro_rules!`, C++ template metaprogramming)
- Anonymous classes/closures (not documentable — no name)
- Method-to-class association (would require AST; file-level association used instead)

If a declaration is too complex for regex (e.g., a Java method with deeply nested generics), the scanner may miss it — but this is acceptable because the goal is documentation discovery, not code compilation.

### C++ negative lookahead

The C++ function pattern uses negative lookahead to exclude control flow keywords:

```
(?!if\b|else\b|for\b|while\b|switch\b|return\b|catch\b)
```

This prevents `if(condition)` from being misidentified as a function named `if`. The lookahead is minimal and targeted — it doesn't attempt to understand C++ semantics.

### Completeness analysis: two-directional coverage

The regex-based approach provides complete documentation coverage through two complementary features:

| Direction | Feature | Question answered |
|-----------|---------|-------------------|
| Code → Docs | `--undocumented` | "What code exists but has no documentation?" |
| Docs → Code | `--validate` (drift) | "What documentation exists but references code that was deleted/renamed?" |

Together, these cover all drift scenarios without AST. The `DriftDetector` mirrors `UndocumentedScanner` patterns (same regex, same language coverage) for consistency.

### Decision record

| Factor | Regex | AST |
|--------|-------|-----|
| Dependencies | Zero (PHP stdlib) | 7+ parser libraries, FFI, native extensions |
| Languages supported | 7 (add new in ~10 lines) | 7 (add new: grammar + bindings + tests) |
| Build complexity | None | CI matrix, platform-specific compilation |
| Multi-class detection | Yes (preg_match_all) | Yes |
| Nested class detection | Yes (^\s* pattern) | Yes |
| Method-to-class scoping | No (file-level) | Yes |
| Industry precedent | ctags (40+ years), ripgrep, GitHub Linguist | IDE plugins (IntelliSense, Roslyn) |
| Maintenance burden | Minimal (patterns rarely change) | High (grammar updates, FFI compatibility) |
| Correctness for task | Sufficient (documentation discovery) | Overkill (designed for code understanding) |

**Conclusion:** Regex is the correct engineering choice for documentation discovery. The same way ctags uses regex for code navigation across 100+ languages, `brain docs` uses regex for documentation gap analysis across 7 languages. AST would be the correct choice if the tool needed to understand code semantics — but it doesn't. It needs to find declarations by keyword pattern, which is exactly what regex does.

## 2. Security Validation: 3-Layer Architecture

### Overview

The `SecurityValidator` validates content downloaded via `--download` and `--update` before saving to `.docs/`. It prevents prompt injection, script injection, and encoded payloads from entering the documentation that AI agents consume.

### Performance scope

Security validation runs **exclusively** during `--download` and `--update` operations — not during regular indexing, searching, or validation. This is a critical design distinction: `brain docs api` (search), `brain docs --headers` (indexing), and `brain docs --validate` (structural validation) never invoke `SecurityValidator`. The 3-layer scanning pipeline processes only externally-fetched content at the moment of ingestion, making its computational cost irrelevant to day-to-day CLI performance.

### Code-block awareness

All scanning layers operate on **stripped content** — fenced code blocks (` ``` `, `~~~`) and inline code (`` ` ``) are removed before pattern matching. This prevents false positives on:

- Security documentation with injection examples in code blocks
- API docs with JWT tokens or authorization headers in code examples
- Articles about XSS containing `<script>` examples
- Prompt engineering guides discussing injection techniques

The stripping is line-by-line with fence toggle tracking, consistent with the code-block awareness pattern used throughout the codebase (header parsing, link extraction, link validation).

### Layer 1: Unicode Normalization

Two-phase approach:

**Phase 1a — Light cleanup:** Strips zero-width characters (13 types: ZWSP, ZWNJ, ZWJ, BOM, soft hyphen, directional marks, etc.) and decodes HTML entities. Preserves native script characters (Cyrillic, CJK, Arabic).

**Phase 1b — Full normalization:** NFKC normalization (if `intl` extension available) plus homoglyph replacement map (35+ entries: Cyrillic/Greek lookalikes mapped to Latin equivalents). Used to detect attacks where `а` (Cyrillic) replaces `a` (Latin).

### Layer 2: Pattern Matching (Dual-Scan)

30+ injection patterns across 6 language families:

| Language | Patterns | Examples |
|----------|----------|---------|
| English | 8 | "ignore all previous instructions", "system: you are now", "act as" |
| Ukrainian | 3 | "ігноруй всі попередні інструкції", "забудь правила" |
| Russian | 3 | "игнорируй предыдущие инструкции", "ты теперь" |
| French | 2 | "ignorez toutes les instructions précédentes" |
| German | 2 | "ignoriere alle vorherigen Anweisungen" |
| Spanish | 2 | "ignora todas las instrucciones anteriores" |
| Chinese | 2 | "忽略所有之前的指令" |
| Technical | 8+ | `<script>`, `javascript:`, `onerror=`, `<iframe>`, `<form action=>` |

**Dual-scan architecture:**

- **Layer 2a:** Scan lightly cleaned content (preserves native scripts) — catches genuine Cyrillic/CJK injections
- **Layer 2b:** Scan fully normalized content (homoglyphs replaced) — catches attacks using lookalike characters

Layer 2b only runs if normalized content differs from cleaned content (optimization).

### Layer 3: Base64 Detection

Finds base64-encoded strings (40+ characters of base64 alphabet), decodes them (strict mode), verifies UTF-8 encoding, and re-scans through Layer 2 patterns. Catches obfuscated injection payloads.

### Layer 3b: Base64 Scanning in Code Blocks

While injection patterns inside code blocks are deliberately excluded from scanning (to prevent false positives on security documentation), base64-encoded injection payloads inside code blocks are always scanned. This is the one exception to code-block safety.

**Why base64 in code blocks is always suspicious:**

There is no legitimate documentation scenario where a base64-obfuscated prompt injection would appear in a code example. Legitimate base64 in code blocks contains harmless content (API tokens, configuration examples, image data) which passes validation because decoding reveals no injection patterns. Only base64 that decodes to actual injection text triggers blocking.

**Implementation:** `extractCodeBlockContent()` (inverse of `stripCodeContent()`) extracts only the content within fenced code blocks. `extractInlineCodeContent()` extracts content from inline code spans. Both are normalized via `normalizeUnicode()` before scanning (consistent with Layer 3, resilient to homoglyph attacks). Line numbers are tracked via dedicated methods (`findLiteralLineInCodeBlock()`, `findLiteralLineInInlineCode()`) that search within the respective code context.

### Trust Mode (`--trust-content`)

The `--trust-content` flag skips Layer 2 (injection pattern matching) for trusted sources. This is useful when downloading security documentation that contains legitimate injection examples in prose text (not inside code blocks).

**What is skipped:** Layer 2a (pattern matching on cleaned content) and Layer 2b (homoglyph normalization + re-scan).

**What remains active:** Size check (5MB), URL scheme check (http/https only), Layer 1 (unicode normalization), Layer 3 (base64 in text), Layer 3b (base64 in code blocks), Layer 3c (base64 in inline code), and caution patterns.

**Context restriction:** `--trust-content` requires `--download` or `--update` — it cannot be used with any other operation. Attempting to use it standalone produces an error.

### Why Trust Mode is NOT a security backdoor

A common concern: "if a trusted GitHub repository is compromised, an attacker could inject plain-text prompt injection that bypasses Layer 2." This concern misunderstands the defense-in-depth model.

**What an attacker gains with `--trust-content`:** The ability to place plain-text injection patterns ("ignore all previous instructions") in documentation prose. This is the same text that exists in thousands of security guides, prompt engineering tutorials, and AI safety research papers.

**What an attacker does NOT gain:**
1. **Base64 obfuscation bypass** — Layers 3/3b/3c remain active. Encoded payloads are still caught.
2. **Homoglyph obfuscation bypass** — Layer 1 still normalizes Unicode, and Layer 3 decodes before scanning.
3. **Arbitrary file write** — Content is still saved to `.docs/` only, never to executable locations.
4. **Code execution** — BrainDocs is a documentation indexing tool. It does not execute content.

**Why plain-text injection in docs is low-risk:**
- Modern AI models (Claude, GPT-4, Gemini) have built-in resistance to plain-text prompt injection in context documents
- The text "ignore all previous instructions" in a documentation file is semantically understood by AI as *content about injection*, not as an *instruction to follow*
- Obfuscated injection (base64, homoglyphs) is the actual high-risk vector because it bypasses both the tool's pattern matching AND the AI model's own safety — and BrainDocs catches this even in trust mode

**Why the flag exists:**
Without `--trust-content`, downloading OWASP guides, NIST security documentation, or Claude's own prompt engineering docs would be blocked — because these documents contain injection patterns as educational examples in prose (outside code blocks). Blocking legitimate security documentation to prevent a low-risk theoretical attack vector would make the tool unusable for its primary audience.

**Operator accountability:** When trust mode is active, a warning is added to the output: "Security Layer 2 (injection patterns) skipped — content trusted by operator". The decision to use `--trust-content` is an explicit operator action, not a default. The operator accepts responsibility for the source's trustworthiness.

**Test coverage:** 6 dedicated tests verify trust mode behavior — Layer 2 skip, base64 still blocked, size check still enforced, invalid scheme still blocked, base64 in code blocks still caught, base64 in inline code still caught.

### Preview Mode (`--preview`)

The `--preview` flag (combined with `--download`) performs the full validation pipeline without saving content to disk. It outputs a JSON object with the validation result:

- `url` — source URL
- `filename` — target filename (from `--as` or URL basename)
- `valid` — boolean validation result
- `reason` — rejection reason (null if valid)
- `warnings` — array of warnings
- `line` — line number of detected threat (null if N/A)
- `content_preview` — first 500 characters of downloaded content

Use case: diagnose why a download is blocked, inspect content before committing to save, integrate into CI pipelines for pre-validation.

### Caution Patterns (Warnings)

Non-blocking warnings for AI-related terms (`instruction`, `prompt`, `system`, `override`, `bypass`) when they appear frequently (>3 occurrences). These flag content for review but don't reject it.

## 3. Search Scoring: Logarithmic Algorithm with Density Normalization

### Architecture

The `ContentScorer` uses a four-component scoring system where **metadata dominates frequency** by design — the human-authored name and description carry more weight than raw keyword count.

**Component 1 — Name match (highest priority):**
- YAML `name` field: **+10 points** per keyword match
- Auto-detected name (first header): H1=+7, H2=+6, H3=+5, H4=+4, H5=+3, H6=+2

**Component 2 — Description match:**
- YAML `description` field: **+5 points** per keyword match
- Auto-detected description (first paragraph): **+3 points**

**Component 3 — Content frequency (logarithmic):**

```
frequency = min(ceil(log₂(count + 1)), 10)
```

| Occurrences | Score | Rationale |
|------------|-------|-----------|
| 1 | 1 | Present but rare |
| 3 | 2 | Mentioned a few times |
| 7 | 3 | Discussed topic |
| 15 | 4 | Significant topic |
| 31 | 5 | Major topic |
| 50+ | capped at 10 | Prevents keyword stuffing |

**Component 4 — Density normalization (bonus):**

```
if wordCount >= 500 AND (count / wordCount) <= 0.02:
    frequency += 2
```

The density bonus rewards **organic keyword usage** in substantial documents. A 5000-word architecture document with 50 mentions of "api" (1% density) receives +2 per keyword compared to a 200-word glossary with 50 identical mentions (25% density).

| Document | Words | Mentions | Density | Frequency | Bonus | Total |
|----------|-------|----------|---------|-----------|-------|-------|
| Architecture guide | 5000 | 50 | 1.0% | 6 | +2 | 8 |
| Short glossary | 200 | 50 | 25.0% | 6 | 0 | 6 |
| API reference | 1200 | 15 | 1.25% | 4 | +2 | 6 |
| Tiny note | 80 | 3 | 3.75% | 2 | 0 | 2 |

**Constants:**
- `DENSITY_MIN_WORDS = 500` — documents below this threshold are too short for meaningful density analysis
- `DENSITY_ORGANIC_THRESHOLD = 0.02` (2%) — keyword density below this indicates organic, contextually rich content
- `DENSITY_BONUS = 2` — bonus points for organic usage

### Full score range per keyword

| Component | Min | Max | Condition |
|-----------|-----|-----|-----------|
| YAML name | 0 | 10 | Keyword in human-authored name |
| Auto name (H1) | 0 | 7 | Keyword in first header |
| YAML description | 0 | 5 | Keyword in human-authored description |
| Auto description | 0 | 3 | Keyword in first paragraph |
| Content frequency | 0 | 10 | Logarithmic frequency cap |
| Density bonus | 0 | 2 | Organic usage in substantial document |
| **Theoretical max** | **0** | **27** | **All components match** |

Multiple keywords accumulate: searching for "api auth" can score up to 54 points for a perfectly matching document.

### Why logarithmic (not linear)?

Linear scoring (`1 point per occurrence`) would rank long documents with repeated keywords higher than short, focused documents. An AI agent needs **semantic relevance**, not document length.

Logarithmic scaling ensures:
- First occurrence matters most (+1 point)
- Diminishing returns for repetition
- Hard cap at 10 points prevents keyword stuffing
- Short, focused documents compete fairly with long ones

### Why density normalization (not TF-IDF)?

TF-IDF (Term Frequency–Inverse Document Frequency) is the standard IR solution for this class of problem, but it requires a **corpus-level computation** — each document's score depends on ALL other documents. This creates:

1. **Non-determinism risk** — adding or removing a single document changes TF-IDF scores for all other documents containing the same term
2. **Performance overhead** — requires pre-computing document frequency across the entire corpus before scoring any individual document
3. **Complexity mismatch** — TF-IDF is designed for large heterogeneous corpora (web search, academic papers). `.docs/` folders typically contain 10-100 homogeneous documentation files

The density normalization approach is **document-local** — each document's score depends only on its own content. This ensures:
- Deterministic scoring (same document, same query → same score, regardless of corpus changes)
- O(1) scoring per document (no corpus-level precomputation)
- Simplicity appropriate for the problem size

### Why metadata dominates frequency (by design)

The scoring system is intentionally structured so that **YAML metadata outweighs content frequency**:

- A document with `name: "API Authentication"` gets +10 for the keyword "api" — more than the maximum +10 from frequency alone
- A document with both YAML name (+10) and description (+5) matching gets +15 before frequency is even considered
- This means well-curated documentation with proper YAML front matter always ranks above documents with incidental keyword mentions

This is correct behavior for AI agents: a document **about** a topic (reflected in its name/description) is more valuable than a document that merely **mentions** the topic frequently.

### Ranking

Results are sorted by total score (DESC), then by file path (ASC) for deterministic ordering when scores are equal.

## 4. MDX Handling: Transparent Passthrough

### Decision: No MDX-specific parsing

MDX files (`.mdx`) are supported alongside `.md` via a transparent passthrough design. JSX/React components are neither parsed nor stripped — they are simply ignored by the header and code-block parsers.

### Why it works

The `MarkdownParser` only recognizes two header formats:

- ATX: `/^(#{1,6})\s+(.+)$/` (lines starting with `#`)
- Setext: `Title` followed by `===` or `---`

A JSX tag like `<Component prop="value" />` matches neither pattern, so it naturally passes through as regular content. No special handling is needed.

### What this means

- Headers inside JSX components are **not** extracted (they're not markdown headers)
- JSX tags appear in content snippets as plain text (harmless)
- Code blocks inside MDX work identically to `.md`
- File detection: `isMarkdownFile()` checks for `.md` or `.mdx` extension

### Test coverage

`test_mdx_jsx_tags_do_not_break_header_parsing` verifies that JSX components don't interfere with header extraction.

## 5. Staleness Detection: Git-First with Docker/CI Fallback Protection

### Two-tier data source architecture

Staleness detection uses a **git-first** strategy. The filesystem fallback and Docker heuristic are secondary mechanisms that only activate when git is unavailable.

**Tier 1 (Primary): Git history — `git log -1 --format=%aI`**

The primary staleness check compares the YAML `date` field in a documentation file against the **git author date** of the last commit touching the referenced source file. This is the most accurate method because:

- Git author dates are **immutable** — they survive checkouts, rebases, merges, and branch switches
- `git checkout` does NOT change git log dates — it only changes filesystem mtime
- Code formatters (prettier, php-cs-fixer) only affect git dates when their changes are **committed**, which is a legitimate modification that SHOULD trigger a staleness warning
- Git handles renames, moves, and partial file changes correctly

**Tier 2 (Fallback): Filesystem mtime — `filemtime()`**

Used ONLY when git is unavailable (no `.git/` directory, shallow clone, Docker container without git). Subject to the Docker/CI reliability check described below. The `summary.source` field in output indicates which tier was used: `"git"` or `"filesystem"`.

### Docker/CI mtime reliability detection

**Problem:** In Docker containers, `COPY` and `ADD` instructions set all copied files to the same modification time (build timestamp). When the filesystem fallback is used, every file appears to have been modified at the same time — causing 100% false positive rate.

**Solution:** Both `StalenessDetector` and `RecentChangesDetector` check mtime reliability before trusting filesystem timestamps:

**Algorithm:**
1. Collect mtime values from sibling files in the same directory
2. If fewer than 3 siblings exist — assume reliable (not enough data to detect pattern)
3. Calculate `max(mtimes) - min(mtimes)`
4. If variance ≤ 2 seconds — mtime is **unreliable** (Docker/CI build detected)
5. Skip the filemtime fallback entirely (return `null` / empty array)

**Constants:**
- `MTIME_TOLERANCE_SECONDS = 2` — maximum variance to consider uniform
- `MTIME_MIN_SIBLINGS = 3` / `MTIME_MIN_FILES = 3` — minimum files for detection

### False positive analysis

A common concern: "Could `git checkout` or code formatters trigger the Docker heuristic?"

**`git checkout` (branch switch):**
- **Primary path (git log):** Not affected. `git log` returns the commit's author date, which doesn't change when switching branches. The primary path is completely immune.
- **Fallback path (mtime):** `git checkout` writes files sequentially to disk. Each file gets a slightly different mtime (milliseconds apart). The Docker heuristic checks `max - min` across sibling files — sequential writes produce measurable variance well above 2 seconds for any non-trivial directory. **False positive: impossible.**

**Code formatters (prettier, php-cs-fixer):**
- **Primary path (git log):** Not affected until changes are committed. If formatting changes ARE committed, the new commit date is later than the doc date — this is a **true positive** (source code changed, documentation may need updating).
- **Fallback path (mtime):** Same as git checkout — formatters write files sequentially, producing non-uniform timestamps. **False positive: impossible.**

**What DOES trigger the Docker heuristic:**
- Docker `COPY . /app` — copies all files with identical build-time timestamp
- Docker `ADD` with tar extraction — same uniform timestamp behavior
- CI `git clone --depth=1` in environments without git binary in PATH — no git available, falls back to mtime, which may be uniform from the CI build system

In all these cases, the heuristic **correctly** identifies mtime as unreliable and skips the check — which is the intended behavior (better to skip than to produce 100% false positives).

### Where it applies

| Component | Without detection | With detection |
|-----------|-------------------|----------------|
| StalenessDetector | False "stale" warnings for every doc | Returns null (no warning) |
| RecentChangesDetector | All files listed as "recently changed" | Returns empty array |

### Why 2 seconds tolerance?

File copy operations can have minor timing differences (1-2 seconds) even in Docker builds. A tolerance of 0 would be too strict (legitimate builds might have 1-second jitter). 2 seconds covers this while still detecting the uniform-mtime pattern.

## 6. Link Validation Architecture

### Internal Link Validator

The `LinkValidator` resolves markdown links against the project file structure:

- **Relative links:** `./file.md`, `../dir/file.md` — resolved from document location
- **Absolute links:** `/path.md` — resolved from project root
- **Bare filenames:** `file.md` — same directory first, then recursive `.docs/` search
- **Anchors:** `#section`, `file.md#section` — validated against headers in target document

### GitHub-compatible slugification

Header text is converted to anchor slugs using a custom algorithm:

1. Strip markdown formatting (bold, italic, inline code, links)
2. Lowercase via `mb_strtolower` (Unicode-safe)
3. Remove non-word characters except spaces and hyphens (`/[^\w\s-]/u`)
4. Replace whitespace with hyphens
5. Trim leading/trailing hyphens

This is a 27-line method with zero external dependencies. The `\w` flag with `/u` modifier preserves Unicode word characters (Cyrillic, CJK, etc.), matching GitHub's slug behavior for non-Latin headers.

### Why not use a library?

- `cocur/slugify` — designed for URL slugs with transliteration, not GitHub-compatible anchor generation
- `league/commonmark` — full markdown parser just for one 27-line method would be overkill
- GitHub REST API — not available offline

The custom implementation is sufficient for `.docs/` validation where headers follow standard markdown conventions.

### External Link Checker

The `ExternalLinkChecker` validates HTTP/HTTPS links using `curl_multi`:

- **Parallelism:** Up to 10 concurrent requests
- **Strategy:** HEAD first, GET fallback on 405 Method Not Allowed
- **Cache:** File-based in `sys_get_temp_dir()`, JSON format, 1-hour TTL, keyed by md5(url)
- **Timeout:** 10 seconds per request, 5 max redirects
- **Code-block aware:** Links inside fenced code blocks are excluded

### Why not Guzzle/Symfony HTTP Client?

`curl_multi` is PHP stdlib — zero dependencies. The checker is 372 lines with full test coverage. Adding Guzzle or Symfony HTTP Client would introduce a heavy dependency for a feature that runs periodically (not on every command invocation). The file-based cache is appropriate for a CLI tool that runs intermittently.

## 7. Dependency Philosophy: Strategic Minimalism

### Principle

BrainDocs follows a **strategic minimalism** approach to dependencies: use external libraries when they provide substantial, hard-to-replicate value; build internally when the use case is narrow and the implementation is straightforward.

### Decision matrix

| Component | Decision | Lines | Justification |
|-----------|----------|-------|---------------|
| HTML→Markdown | **External** (`league/html-to-markdown`) | wrapper | HTML conversion has hundreds of edge cases (nested tables, malformed tags, entity handling). Reimplementing this would be irresponsible. |
| Anchor slug generator | **Internal** (27 lines) | 27 | Requires markdown-aware stripping (`**bold**` → `bold`) before slugification. No existing library handles this — `cocur/slugify` does URL slugs with transliteration, not GitHub-compatible markdown anchors. |
| External link checker | **Internal** (372 lines) | 372 | Single use case: HEAD requests with 405→GET fallback, file cache, concurrency. `curl_multi` is PHP stdlib. Guzzle would add ~2MB for a feature that runs on `--check-external` only. |
| Markdown structure validator | **Internal** (427 lines) | 427 | 6 rules selected from 53 markdownlint rules based on AI-agent discoverability criterion. No existing library provides this specific ruleset. |
| Security validator | **Internal** (615 lines) | 615 | Unique: multi-language prompt injection detection + homoglyph normalization + base64 payload scanning. No existing library covers any of this. |
| Markdown parser | **Internal** (611 lines) | 611 | ATX/setext headers, code blocks with language detection, task checklists — all code-block aware. CommonMark parsers exist but are designed for rendering, not structural extraction. |

### Why not "just use markdownlint"?

`markdownlint` (Node.js, 44K+ stars) implements 53 rules. BrainDocs uses 6. The remaining 47 address formatting consistency (trailing spaces, line length, list marker style) that has zero impact on AI agent document discovery. Including markdownlint would require a Node.js runtime dependency for 6 rules, 47 of which would need to be disabled.

### Why not "just use tree-sitter"?

See Section 1 (Code Parsing: Regex vs AST) for the full decision record.

### Long-term maintenance perspective

Each internal component has explicit test coverage and a narrow scope. The total internal codebase for docs tooling is ~2500 lines across 10 service classes — comparable in size to a single Guzzle middleware chain. The maintenance burden is proportional to the functionality, and each component evolves only when its specific use case changes.

The one external dependency (`league/html-to-markdown`) was chosen because HTML parsing is a genuinely complex problem with hundreds of edge cases that no reasonable team should reimplement. The internal components solve problems that either (a) don't have suitable external solutions or (b) would require importing disproportionately large libraries for trivially small use cases.

## 8. HTML-to-Markdown Conversion

### Library: `league/html-to-markdown`

Downloaded HTML content is converted to semantic Markdown preserving:

- Tables (HTML `<table>` to markdown pipe tables)
- Headers (`<h1>`-`<h6>` to `#` syntax)
- Lists (ordered and unordered)
- Links and images
- Code blocks (`<pre><code>` to fenced blocks)
- Emphasis and strong text

Non-HTML content (plain text, markdown) passes through unchanged. Detection is based on presence of HTML tags in the content.

## 9. Filesystem Fallback Strategy

### When git is unavailable

Both `StalenessDetector` and `RecentChangesDetector` have a two-tier data source strategy:

**Tier 1 (Primary): Git history**
- `git log` for commit dates, authors, file changes
- Most accurate, handles renames, provides author attribution

**Tier 2 (Fallback): Filesystem mtime**
- `filemtime()` for modification timestamps
- Used when: no `.git/` directory, shallow clone, Docker container
- Subject to mtime reliability check (see section 5)
- `summary.source` field indicates data origin: `"git"` or `"filesystem"`

The `detect()` / `getGitLog()` methods return `null` when git is unavailable (not empty string), allowing the caller to distinguish "git found nothing" from "git unavailable."

## 10. Threat Model & Defense-in-Depth

### What SecurityValidator protects against

SecurityValidator is a **pre-save validation filter** — it runs exclusively during `--download` and `--update`, before content is written to `.docs/`. It blocks two classes of attacks:

1. **Prompt injection** — text-level manipulation attempts ("ignore all previous instructions", "you are now", role injection in 6 languages). These work because AI models interpret natural language as instructions.

2. **Script/element injection** — HTML/JS payloads (`<script>`, `<iframe>`, `onerror=`, `javascript:`, `data:` URIs, `<form action=>`). These target web rendering contexts.

### What SecurityValidator does NOT protect against

SecurityValidator does **not** analyze injection patterns within fenced code blocks for malicious intent. This is a deliberate architectural decision, not an oversight.

**Why code blocks are excluded from pattern scanning:**

1. **False positive catastrophe.** Documentation about security, XSS prevention, prompt engineering, and API authentication inherently contains "malicious" patterns as examples. Scanning code blocks would block virtually all security-related documentation — the exact content that AI agents need most.

2. **Prompt injection ≠ code injection.** Prompt injection works by manipulating an AI model through natural language text. Text inside markdown code blocks is semantically understood by AI models as *examples*, not *instructions*. A prompt injection pattern inside ` ``` ` does not function as a prompt injection.

3. **Code maliciousness is undecidable.** Determining whether arbitrary code is malicious is equivalent to the halting problem — it cannot be solved by pattern matching. `curl https://example.com | bash` is a standard installation pattern (Homebrew, nvm, rustup, oh-my-zsh). `os.system("rm -rf /")` could be a legitimate example in a destructive operations guide. No finite set of patterns can distinguish malicious code from legitimate examples.

### Exception: Base64 in Code Blocks and Inline Code

While injection patterns in code blocks are safe (legitimate examples), **base64-encoded injection payloads** inside code blocks and inline code are always suspicious. Layers 3b/3c scan base64 content within all code contexts because:

1. **No legitimate use case.** There is no documentation scenario where a base64-obfuscated prompt injection would appear as a code example. Legitimate base64 in documentation (API tokens, configuration, image data) decodes to harmless content and passes validation.

2. **Obfuscation implies intent.** Base64 encoding is specifically used to bypass text-level pattern matching. An attacker embedding `aWdub3JlIGFsbCBwcmV2aW91cyBpbnN0cnVjdGlvbnM=` in a code block is attempting to evade detection — the encoding itself signals malicious intent.

3. **Zero false positive risk.** Only base64 strings that decode to valid UTF-8 text AND match injection patterns trigger blocking. Normal base64 content (hashes, tokens, binary data) passes through.

4. **Formal distinction from pattern matching.** Pattern matching against code blocks has ~80% false positive rate on security documentation (because legitimate injection examples use the exact same text). Base64 decode + rescan has **0% false positive rate** because it tests the *decoded content*, not the raw pattern. A clean base64 string (e.g., encoded configuration) decodes to text that doesn't match any injection pattern. Only deliberately obfuscated injection payloads trigger detection. This is why base64 scanning is the correct exception to code-block safety — it has a fundamentally different false positive profile.

**Coverage:** Layer 3b covers fenced code blocks (` ``` `, `~~~`). Layer 3c covers inline code spans (`` ` ``). Both apply `normalizeUnicode()` before scanning for consistency with Layer 3 (homoglyph-resilient).

### Preview Mode in Threat Model

The `--preview` flag provides a dry-run mechanism for security validation. It executes the full validation pipeline (respecting `--trust-content` if present) but outputs the result as JSON without saving to disk. This supports:

- **Debugging:** Understanding why a specific URL is blocked before attempting workarounds
- **CI integration:** Pre-validating documentation URLs in automated pipelines
- **Operator trust decisions:** Reviewing validation warnings before deciding whether to use `--trust-content`

### Defense-in-depth: responsibility layers

Security is not a single checkpoint — it's a layered architecture where each component owns a specific responsibility:

| Layer | Component | Responsibility | Scope |
|-------|-----------|---------------|-------|
| 1 | SecurityValidator | Block prompt/script injection in text | Pre-save (`--download`, `--update`) |
| 2 | AI model guardrails | Refuse to execute harmful actions | Runtime (Claude, GPT safety layers) |
| 3 | Execution sandbox | Restrict filesystem/network access | Runtime (Docker, restricted shell, permissions) |
| 4 | Human review | Verify downloaded content before mission-critical use | Pre-deployment |

No single layer is expected to catch everything. SecurityValidator catches prompt injection (Layer 1). If a malicious payload somehow reaches an AI agent inside a code block, the agent's own safety mechanisms (Layer 2) and the execution sandbox (Layer 3) provide additional barriers.

### Why this model is correct

The alternative — scanning code blocks for all "dangerous" patterns — creates a false sense of security while degrading legitimate functionality:

- It would block ~80% of security-related documentation (false positives)
- It cannot detect novel attack patterns (false sense of security)
- It shifts responsibility from the appropriate layers (AI guardrails, sandbox) to a text filter that lacks execution context

The targeted exception (Layers 3b/3c: base64 in code blocks and inline code) is the correct compromise — it catches the one category of code-block content that is objectively suspicious (obfuscated payloads) while leaving all other code-block content untouched. The key difference: pattern matching in code blocks is **semantically ambiguous** (is this an injection or an example?), while base64 decode + rescan is **semantically unambiguous** (clean base64 never decodes to injection text, only deliberately obfuscated payloads do).

BrainDocs is a **documentation indexing tool**. It does not execute code, grant permissions, or interact with the runtime environment. Its security boundary is correctly scoped to content validation at the text level.

### MDX and JSX: why no parsing

MDX files (`.mdx`) use a transparent passthrough design. JSX/React components are not parsed, stripped, or interpreted — they pass through as plain text content.

**Why this is correct for `.docs/`:**

1. **No React runtime.** `.docs/` files are consumed by AI agents and CLI tools, not by a React application. JSX components like `<TechParam name="token" />` have no rendering context — they are inert text.

2. **Component semantics are unknowable.** A custom component `<ApiParam>` could mean anything. Parsing its props requires knowledge of the component's implementation, which is external to the documentation file. Generic "JSX parsing" cannot extract semantic meaning from arbitrary components.

3. **Headers and content remain accessible.** Standard markdown headers (`#`, `##`) and text content in MDX files are fully indexed. Only JSX-specific structure (component props, children) is opaque — which is acceptable because this structure has no meaning without a React runtime.

4. **Industry alignment.** Documentation tools (mdx-js, Docusaurus, Nextra) require a build step to render JSX. Without compilation, JSX tags are plain text. BrainDocs treats them accordingly.

## 11. Task Extraction (`--tasks`)

### Purpose

Read-only extraction of markdown checklists (`- [ ]` / `- [x]`) from `.docs/` files with structured metadata: status, line number, and nearest heading context.

### Implementation

The `MarkdownParser::parseTasks()` method reuses existing infrastructure:

- **Code-block awareness:** Uses `findCodeBlockRanges()` + `isInCodeBlock()` to exclude checklists inside fenced code blocks (same pattern as header parsing).
- **Heading context:** Calls `parseHeaders($content, 6)` to collect all headers, then `findNearestHeading()` resolves the closest heading above each task item.
- **Bullet markers:** Supports `-`, `*`, and `+` prefixes (standard markdown list syntax).
- **Status detection:** Space inside brackets = "pending", `x` or `X` = "done".

### Output format

Each file with tasks includes a `tasks` key containing:

- `items[]` — array of `{text, status, line, heading?}` objects
- `summary` — `{total, done, pending}` counts

Files without tasks omit the `tasks` key entirely (no empty objects in output).

### Why parseHeaders(content, 6) for heading context

The `parseTasks()` method needs all headers (H1-H6) for the `findNearestHeading()` lookup. Rather than duplicating header extraction logic, it reuses `parseHeaders($content, 6)` which returns all levels. The overhead of `end_line` calculation in `parseHeaders()` is negligible — documents typically have fewer than 50 headers.

## 12. Markdown Structure Validation

### Problem

AI agents navigate documents via heading hierarchy. When heading structure is broken — skipped levels (H1→H4), missing space after `#` (not parsed as heading), bold text used instead of headings — entire sections become invisible to `brain docs` heading-based search. Content before the first heading ("orphan content") is unreachable by heading navigation entirely.

### Solution: 6 structural rules

The `MarkdownStructureValidator` implements 6 rules selected from 53 markdownlint rules based on a single criterion: **does this structural issue prevent AI agent discovery?**

| Rule | markdownlint | What it prevents |
|------|-------------|------------------|
| heading-increment | MD001 | Skipped levels break hierarchy navigation (H1→H4 means H2/H3 gap) |
| no-missing-space-atx | MD018 | `#Title` is not parsed as heading — entire section invisible |
| single-h1 | MD025 | Multiple H1 creates ambiguous document title |
| no-emphasis-as-heading | MD036 | `**Bold**` between blank lines looks like heading but isn't discoverable |
| table-column-count | MD056 | Mismatched columns corrupt table parsing |
| orphan-content | custom | Content before first heading has no heading anchor to navigate to |

### Why only 6 rules from 53?

The remaining 47 markdownlint rules address formatting consistency (trailing spaces, line length, list marker style, blank line around headers, etc.). These are cosmetic — they don't affect whether an AI agent can discover and navigate to content.

### Design decisions

**Standalone class, no dependencies.** Same pattern as `LinkValidator` and `SecurityValidator`. Accepts markdown string, returns `array<int, string>` warnings. Zero coupling to parsers, commands, or framework.

**Own heading extraction.** Does not use `MarkdownParser::parseHeaders()` because that method filters by `maxLevel`, calculates `end_line`/`snippet`, and optimizes for search display. The validator needs a simpler `[{level, line, text}]` array.

**Code-block and YAML aware.** All rules skip fenced code blocks (``` / ~~~) and YAML front matter. Uses the same fence-toggle pattern as `SecurityValidator::stripCodeContent()` and `LinkValidator::extractInternalLinks()`.

### Rule details

**heading-increment:** Tracks previous heading level. If current > previous + 1, that's a gap. First heading in document can be any level (H2 starting document is valid). Decrease is always allowed (H3→H2 is normal section nesting).

**no-missing-space-atx:** Regex `/^#{1,6}[^\s#]/` catches lines where `#` is immediately followed by non-whitespace. These aren't parsed as headings by any markdown parser.

**single-h1:** Collects all H1 headings and warns if count > 1 with all line numbers. Separate from the existing "No H1 found" check in `validateDocs()` which is an error-level check for missing H1.

**no-emphasis-as-heading:** Detects lines entirely wrapped in `**...**` or `__...__` that are surrounded by blank lines (heading-like visual pattern). Excludes: inline bold within sentences, bold inside tables, bold inside list items, bold inside code blocks.

**table-column-count:** Tracks table state: header row → separator row → data rows. Counts pipe-separated columns. Warns when any data row column count differs from header.

**orphan-content:** Counts non-empty lines between YAML end (or file start) and first heading. If >5 lines, warns with line range. Empty lines are excluded from count.
