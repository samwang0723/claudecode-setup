---
name: arch-review
description: "Run a multi-agent architecture review producing codebase map, mermaid diagrams, STRIDE threat model, and operational risk assessment. Use when the user says 'arch review', 'architecture audit', 'review the architecture', 'system design review', or needs a comprehensive assessment of codebase structure, dependencies, and security posture."
disable-model-invocation: true
context: fork
agent: team-lead
---

# Architecture Review

Conduct a comprehensive architecture review using the agent team. Creates `.claude/tasks/arch-review-{slug}/` to track all outputs.

## Workflow

### Phase 1: Exploration

**Agent:** explorer → output: `dev-1.md`

- Map the codebase structure — key directories, entry points, module boundaries
- Identify external dependencies and their versions
- Document service relationships (upstream/downstream)
- Note configuration patterns and environment requirements

### Phase 2: Architecture Assessment

**Agent:** architect → output: `architect.md`

- Evaluate component boundaries and separation of concerns
- Assess coupling between modules — identify tight coupling risks
- Generate mermaid diagrams: component diagram, dependency graph, data flow
- Review patterns in use (MVC, hexagonal, event-driven, etc.)
- Flag architectural debt: circular dependencies, god classes, leaky abstractions

### Phase 3: Security Review

**Agent:** security-reviewer → output: `security.md`

- Apply STRIDE threat model to identified components
- Review authentication and authorization boundaries
- Check for common vulnerability patterns (injection, XSS, CSRF, insecure deserialization)
- Assess secret management and credential handling
- Evaluate network exposure and attack surface

### Phase 4: Operational Risk

**Agent:** pm → output: `pm.md`

- Assess deployment complexity and rollback capability
- Review monitoring and observability coverage
- Identify single points of failure
- Evaluate scalability bottlenecks
- Document operational dependencies (databases, queues, external APIs)

### Phase 5: Synthesis

Combine findings into `summary.md` with:

1. **Executive summary** — overall health assessment (green/yellow/red)
2. **Key findings** — prioritized list of issues by severity
3. **Architecture diagrams** — mermaid visualizations from Phase 2
4. **Recommendations** — actionable improvements ranked by impact vs effort
5. **Risk matrix** — combined security + operational risks

Track progress in `_status.md` throughout all phases.

---

Focus: $ARGUMENTS
