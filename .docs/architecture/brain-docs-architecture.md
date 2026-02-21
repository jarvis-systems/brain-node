---
name: "BrainDocs Architecture"
description: "Architectural decisions, design rationale, and implementation details for the brain docs CLI tool"
type: architecture
date: 2026-02-22
---

# BrainDocs Architecture

This document explains the engineering decisions behind `brain docs` — the CLI tool for indexing, searching, and validating `.docs/` project documentation for AI agents.

## 1. Code Parsing: Regex vs AST

### Decision: Regex-based extraction for all 7 languages

The `UndocumentedScanner` uses regular expressions to extract top-level declarations (classes, structs, public functions) from PHP, JavaScript/TypeScript, Python, Go, C++, Rust, and Java.

### Why not AST parsers?

AST (Abstract Syntax Tree) parsers are the correct choice when you need to understand code structure deeply — variable scope, type inference, control flow analysis. But `brain docs --undocumented` has a fundamentally different goal: **find top-level public API declarations** and check if documentation exists for them.

This is the same class of problem solved by:

- **ctags / universal-ctags** — the industry standard for code navigation, used for 40+ years. Regex-based. Supports 100+ languages.
- **GitHub Linguist** — GitHub's language detection. Regex-based heuristics.
- **tree-sitter** grammars — even tree-sitter starts with regex-like pattern matching for tokenization.

The patterns we extract are syntactically rigid:

| Language | Class Pattern | What it matches |
|----------|--------------|-----------------|
| PHP | `/^(?:abstract\s+)?class\s+(\w+)/m` | `class UserService`, `abstract class Base` |
| Go | `/^\s*type\s+(\w+)\s+struct\s*\{/m` | `type Server struct {` |
| Rust | `/^\s*(?:pub...)?\s+struct\s+(\w+)/m` | `pub struct Config`, `struct State` |
| Java | `/^\s*(?:public...)?class\s+(\w+)/m` | `public class OrderService` |

These are **line-anchored, top-level patterns**. They don't parse nested structures, closures, or complex expressions. A class declaration at the top level of a file has exactly one syntactic form per language.

### What would AST require?

To add AST parsing for 7 languages, we would need:

- 7 separate parser libraries (or bindings to tree-sitter grammars)
- FFI layer for compiled parsers (tree-sitter is C-based)
- Grammar version management (language specs evolve)
- ~10x more code for the same result
- Build complexity (native extensions, CI matrix)

The cost-to-benefit ratio is disproportionate. Regex correctly handles the **top-level declaration extraction** use case.

### Scope boundaries

The scanner explicitly does NOT parse:

- Nested classes or inner functions
- Method bodies or control flow
- Generic type parameters beyond declaration
- Macro-expanded code (Rust `macro_rules!`, C++ templates)

If a declaration is too complex for regex (e.g., a Java method with deeply nested generics), the scanner may miss it — but this is acceptable because the goal is documentation discovery, not code compilation.

### C++ negative lookahead

The C++ function pattern uses negative lookahead to exclude control flow keywords:

```
(?!if\b|else\b|for\b|while\b|switch\b|return\b|catch\b)
```

This prevents `if(condition)` from being misidentified as a function named `if`. The lookahead is minimal and targeted — it doesn't attempt to understand C++ semantics.

## 2. Security Validation: 3-Layer Architecture

### Overview

The `SecurityValidator` validates content downloaded via `--download` and `--update` before saving to `.docs/`. It prevents prompt injection, script injection, and encoded payloads from entering the documentation that AI agents consume.

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

**What remains active:** Size check, URL scheme check, Layer 1 (unicode normalization), Layer 3 (base64 in text), Layer 3b (base64 in code blocks), and caution patterns.

The rationale: a trusted source (official documentation, known security guides) may contain injection patterns as examples in prose, but should never contain base64-obfuscated payloads. Trust mode relaxes pattern matching while maintaining obfuscation detection.

When trust mode is active, a warning is added: "Security Layer 2 (injection patterns) skipped — content trusted by operator".

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

## 3. Search Scoring: Logarithmic Algorithm

### Formula

The `ContentScorer` uses a three-tier scoring system:

**Tier 1 — Name match:**
- YAML `name` field: **+10 points** per keyword match
- Auto-detected name (first header): H1=+7, H2=+6, H3=+5, H4=+4, H5=+3, H6=+2

**Tier 2 — Description match:**
- YAML `description` field: **+5 points** per keyword match
- Auto-detected description (first paragraph): **+3 points**

**Tier 3 — Content frequency (logarithmic):**

```
score = min(ceil(log₂(count + 1)), 10)
```

| Occurrences | Score | Rationale |
|------------|-------|-----------|
| 1 | 1 | Present but rare |
| 3 | 2 | Mentioned a few times |
| 7 | 3 | Discussed topic |
| 15 | 4 | Significant topic |
| 31 | 5 | Major topic |
| 50+ | capped at 10 | Prevents keyword stuffing |

### Why logarithmic?

Linear scoring (`1 point per occurrence`) would rank long documents with repeated keywords higher than short, focused documents. An AI agent needs **semantic relevance**, not document length.

Logarithmic scaling ensures:
- First occurrence matters most (+1 point)
- Diminishing returns for repetition
- Hard cap at 10 points prevents gaming via keyword stuffing
- Short, focused documents compete fairly with long ones

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

## 5. Docker/CI mtime Reliability Detection

### Problem

In Docker containers, `COPY` and `ADD` instructions set all copied files to the same modification time (build timestamp). When `brain docs` falls back to filesystem `filemtime()` (because git is unavailable in the container), every file appears to have been modified at the same time — causing 100% false positive rate for staleness detection and recent changes.

### Solution: Uniform mtime detection

Both `StalenessDetector` and `RecentChangesDetector` check mtime reliability before trusting filesystem timestamps:

**Algorithm:**
1. Collect mtime values from sibling files in the same directory
2. If fewer than 3 siblings exist — assume reliable (not enough data to detect pattern)
3. Calculate `max(mtimes) - min(mtimes)`
4. If variance ≤ 2 seconds — mtime is **unreliable** (Docker/CI build detected)
5. Skip the filemtime fallback entirely

**Constants:**
- `MTIME_TOLERANCE_SECONDS = 2` — maximum variance to consider uniform
- `MTIME_MIN_SIBLINGS = 3` (StalenessDetector) / `MTIME_MIN_FILES = 3` (RecentChangesDetector) — minimum files for detection

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

## 7. HTML-to-Markdown Conversion

### Library: `league/html-to-markdown`

Downloaded HTML content is converted to semantic Markdown preserving:

- Tables (HTML `<table>` to markdown pipe tables)
- Headers (`<h1>`-`<h6>` to `#` syntax)
- Lists (ordered and unordered)
- Links and images
- Code blocks (`<pre><code>` to fenced blocks)
- Emphasis and strong text

Non-HTML content (plain text, markdown) passes through unchanged. Detection is based on presence of HTML tags in the content.

## 8. Filesystem Fallback Strategy

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

## 9. Threat Model & Defense-in-Depth

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

## 10. Markdown Structure Validation

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
