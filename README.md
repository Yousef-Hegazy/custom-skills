# Custom Skills

A curated repository of high-discipline, model-agnostic, and agent-independent skills created by [Yousef Hegazy](https://github.com/Yousef-Hegazy).

These skills are designed to be universally compatible across AI developer environments, coding assistants, agentic frameworks, and standard chat models.

---

## Skills Catalog

| Skill | Description | Direct Link |
| :--- | :--- | :--- |
| [`real-world-integration-testing`](skills/real-world-integration-testing/SKILL.md) | High-discipline, non-stubbed integration and contract testing protocol for TypeScript, Rust, Python, and Go. Enforces real dependency wiring, wire-level third-party interception (WireMock/MSW), triple-layer contract assertions, and uncommitted local sabotage checks to eliminate false-positive test suites. | [skills/real-world-integration-testing/SKILL.md](skills/real-world-integration-testing/SKILL.md) |
| [`opus-rigor`](skills/opus-rigor/SKILL.md) | High-discipline strategic & engineering protocol. Elevates any LLM to Claude Opus-level rigor: epistemic humility, transparent collaboration, candid pushback, proactive clarification, two-phase planning, and surgical verification. | [skills/opus-rigor/SKILL.md](skills/opus-rigor/SKILL.md) |
| [`senior-react-tauri-architect`](skills/senior-react-tauri-architect/SKILL.md) | Staff Desktop & Frontend Architect protocol for React 19+, Vite, and Tauri v1/v2. Zero-lag 60fps UI thread invariants, non-blocking asynchronous IPC, functional GoF patterns (Facade, Strategy, Adapter), WebView memory hygiene, and atomic Zustand selectors. | [skills/senior-react-tauri-architect/SKILL.md](skills/senior-react-tauri-architect/SKILL.md) |
| [`senior-nextjs-architect`](skills/senior-nextjs-architect/SKILL.md) | Staff Full-Stack Next.js Architect protocol for Next.js 15/16+, React 19+, and App Router. Leaf-only `"use client"`, asynchronous dynamic APIs (`params`, `cookies`), Server Action primitives (`useActionState`, `useOptimistic`), streaming Suspense, and functional GoF enterprise architecture. | [skills/senior-nextjs-architect/SKILL.md](skills/senior-nextjs-architect/SKILL.md) |

---

## How to Use Across Different Tools & Environments

Each skill adheres to the open standard skill specification (`SKILL.md` with YAML frontmatter), making it universally importable into your development workflow.

### 1. Antigravity
Clone or copy the skill into your Antigravity skills directory:
```bash
# Global skills
cp -r skills/opus-rigor ~/.gemini/config/skills/

# Or per-workspace skills
cp -r skills/opus-rigor .gemini/skills/
```

### 2. Cursor
You can include the protocol in `.cursorrules` or inside `.cursor/rules/opus-rigor.mdc`:
- Copy the content of [`skills/opus-rigor/SKILL.md`](skills/opus-rigor/SKILL.md) directly into your `.cursorrules` file or as a rule under `.cursor/rules/`.

### 3. Claude Code
Copy into your project's `.claude/skills` directory, or append to `CLAUDE.md`:
```bash
mkdir -p .claude/skills
cp -r skills/opus-rigor .claude/skills/
```

### 4. Windsurf / Codeium
Add the contents of the skill to your project's `.windsurfrules` file or your global system instructions.

### 5. Aider
Pass the skill file as part of your system prompt or custom instructions:
```bash
aider --read skills/opus-rigor/SKILL.md
```
Or reference it in your `.aider.conf.yml`:
```yaml
read:
  - skills/opus-rigor/SKILL.md
```

### 6. Raw Chat Interfaces & Custom API Agents (ChatGPT, Gemini, Claude, Local Models)
Copy the markdown content of [`skills/opus-rigor/SKILL.md`](skills/opus-rigor/SKILL.md) (excluding the YAML frontmatter) directly into the Custom Instructions, System Prompt, or initial message of your session.
