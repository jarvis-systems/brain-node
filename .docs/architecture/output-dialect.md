---
name: "Output Dialect Contract"
description: "Defines the mixed XML+Markdown output dialect used by Brain compilation and its escaping guarantees"
type: architecture
date: 2026-02-21
version: "1.0.0"
status: active
---

# Output Dialect Contract

## What Brain Outputs

Brain compilation produces a **mixed dialect**: XML structural tags wrapping Markdown content. This is intentional, not a bug.

```
<system>                          ← XML structural tag
<meta>
<id>brain-core</id>              ← XML inline text (raw passthrough)
</meta>

<provides>                        ← XML structural tag
Content in **Markdown** format    ← Markdown content (raw passthrough)
- Lists, `code`, **bold**         ← Markdown formatting preserved as-is
</provides>

# Iron Rules                     ← Pure Markdown (no XML wrapper)
## rule-name (CRITICAL)           ← Markdown heading
</system>
```

## Why Mixed Output Exists

1. **Token efficiency**: XML-escaped content (`&amp;`, `&lt;`, `&quot;`) wastes tokens. LLMs do not need well-formed XML — they parse structure semantically.
2. **Readability**: Raw Markdown inside XML tags is more readable for both humans and LLMs than escaped equivalents.
3. **Prompt optimization**: Research shows LLMs respond better to mixed structural+natural formats than to strict XML or strict Markdown alone.

## Escaping Contract

### `raw()` — Default (used in production)

Raw passthrough. Content goes through unchanged. No character escaping.

| Input | Output | Note |
|-------|--------|------|
| `Hello & world` | `Hello & world` | `&` stays as `&` |
| `a < b > c` | `a < b > c` | Angle brackets preserved |
| `key="val"` | `key="val"` | Quotes preserved |

**Used by**: `XmlBuilder::renderNode()` for text content and attribute values.

### `escapeXml()` — Available (not used by default)

Genuine XML escaping via `htmlspecialchars(ENT_XML1 | ENT_QUOTES, UTF-8)`.

| Input | Output |
|-------|--------|
| `Hello & world` | `Hello &amp; world` |
| `a < b > c` | `a &lt; b &gt; c` |
| `key="val"` | `key=&quot;val&quot;` |

**When to use**: Subclasses that override `raw()` with `escapeXml()` for strict XML output contexts (XML parsers, validation tools, schema-aware consumers).

## Guarantees

| Property | Guaranteed | Note |
|----------|-----------|------|
| XML structural tags well-formed | Yes | Opening/closing tags, self-closing, attributes |
| Content XML-escaped | **No** | Intentional — raw passthrough for LLM consumption |
| Markdown formatting preserved | Yes | Bold, code, lists, headers pass through unchanged |
| No tab indentation | Yes | Newlines only, no tabs |
| Stable output ordering | Yes | Deterministic for same input |
| Idempotent compilation | Yes | Same source = same output |

## Extension Point

To produce strict XML output, extend `XmlBuilder` and override `raw()`:

```php
class StrictXmlBuilder extends XmlBuilder
{
    protected function raw(string $value): string
    {
        return $this->escapeXml($value);
    }
}
```

## History

- **v0.1.x**: `escape()` method with `htmlspecialchars()` commented out — contract lie
- **v0.2.1**: Renamed to `raw()` (honest passthrough) + added `escapeXml()` (real escaping). Contract now matches implementation.
