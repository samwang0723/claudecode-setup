---
name: write-tech-spec
description: "Generate a technical specification document using the DDD template in template.md. Use when the user says 'write tech spec', 'create tech spec', 'technical specification', or needs a structured design document for a new feature or major change covering architecture, domain models, APIs, data design, security, and operations."
---

# Write Tech Spec

Generate a complete technical specification document following the DDD (Domain Driven Design) template at `template.md`.

## Workflow

### Step 1: Gather Context

Ask the user for these essentials before generating:

- **Feature name** and one-line description
- **New feature or modification** to an existing service?
- **Owning team/pillar** and key stakeholders/reviewers
- **Related links** — PRD, Figma, Slack threads, existing docs

### Step 2: Technical Discovery

For each relevant template section, ask targeted questions:

| Section | Key Questions |
|---------|--------------|
| Architecture | What services are involved? Upstream/downstream dependencies? |
| Domain | New domain models or entities? State machines needed? |
| Data | Database schema changes? PII considerations? Retention policy? |
| APIs | New endpoints? Error code patterns? Rate limiting needs? |
| Security | External exposure? Auth changes? Threat model required? |
| Operations | Feature flags? Rollout strategy? Monitoring metrics? |

Skip sections the user confirms are not applicable — mark them "N/A" in the output.

### Step 3: Generate the Spec

1. Read `template.md` from this skill directory for the full document structure
2. Fill in each section with gathered information
3. Mark gaps with `[TODO: description]` placeholders
4. Mark diagram locations with `[DIAGRAM: description]` placeholders
5. Use mermaid code blocks for architecture and sequence diagrams where possible

### Step 4: Output and Review

1. Save the completed spec to `.claude/tasks/{slug}/tech-spec.md`
2. Present a summary of completed vs TODO sections for user review
3. Optionally upload to Confluence using `mcp__atlassian__confluence_create_page`

## Template Reference

The full template structure lives in `template.md` (bundled with this skill). Key sections:

1. **TL;DR Change Summary** — 2-3 sentences: What? Why? Impact?
2. **Background** — Objective, Goals, Non-Goals
3. **Architecture Overview** — Component diagram, service relationships
4. **Domain Design** — Use cases, fund flows, domain models, state machines, configuration
5. **Data Design** — DB schemas, storage, privacy, retention
6. **APIs Design** — Model definitions, endpoints, sequence diagrams, error codes (`{App}-{4-digit-code}`)
7. **Logging Design** — Log structure with PII masking
8. **Security Design** — Auth, XSS/CSRF/CORS/SQLi prevention, key management
9. **Compatibility Design** — Backward compatibility, platform support
10. **Operations** — Capacity, rollout plan, monitoring, fallback, security assessment, testing, infrastructure

### Operations Sections Are Required

Every tech spec must include rollout plan, monitoring metrics/alerts, fallback plan, and security assessment — these are non-negotiable for production readiness.

---

Focus: $ARGUMENTS
