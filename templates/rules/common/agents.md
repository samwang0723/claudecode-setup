# Agent Orchestration

## Available Agents

Located in `~/.claude/agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| team-lead | Pipeline orchestrator, delegates to specialists, tracks state | Complex multi-step tasks, coordinated work |
| architect | System design, mermaid diagrams, architecture gate | Architectural decisions, design reviews |
| dev | TDD implementation, peer review (up to 5 parallel) | Feature implementation, bug fixes |
| qa | E2E testing, integration, user flows, error paths | After peer review, critical user flows |
| code-reviewer | Multi-language code review, quality/security enforcement | After writing code, before merge |
| security-reviewer | STRIDE, OWASP, auth flows, PCI-DSS, SOC2 | Before commits, security audits |
| pm | Requirements (MoSCoW), scope, timeline, risk | Project scoping, build-vs-buy decisions |
| explorer | Fast codebase scout, file lookups, structure mapping | Quick code search, orientation |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **team-lead** agent with `/lead-start --devs {num} {description}` skill
2. Architectural decision - Use **architect** agent with `/write-tech-spec` skill
3. Bug fix or new feature - Use **dev** agent
4. Code just written/modified - Use **code-reviewer** agent
5. Security concerns - Use **security-reviewer** agent
6. Product requirement discussion - Use **pm** agent with `/write-prd` skill

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth module
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utilities

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker
