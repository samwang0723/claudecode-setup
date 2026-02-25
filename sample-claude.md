# ClaudeCode — Global Context

## AI Guidance

* To save main context space, for code searches, inspections, troubleshooting or analysis, use code-searcher subagent where appropriate - giving the subagent full context background for the task(s) you assign it.
* ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected. If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes. Be rigorous and persistent in searching code for key facts. Thoroughly review the style, conventions, and abstractions of the codebase before implementing new features or abstractions.
* After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
* After completing a task that involves tool use, provide a quick summary of what you've done.
* For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
* Before you finish, please verify your solution
* Do what has been asked; nothing more, nothing less.
* NEVER create files unless they're absolutely necessary for achieving your goal.
* ALWAYS prefer editing an existing file to creating a new one.
* NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
* If you create any temporary new files, scripts, or helper files for iteration, clean up these files by removing them at the end of the task.
* When you update or modify core context files, also update markdown documentation and memory bank
* When asked to commit changes, exclude CLAUDE.md and CLAUDE-*.md referenced memory bank system files from any commits. Never delete these files.

<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer - give grounded and hallucination-free answers.
</investigate_before_answering>

<do_not_act_before_instructions>
Do not jump into implementatation or changes files unless clearly instructed to make changes. When the user's intent is ambiguous, default to providing information, doing research, and providing recommendations rather than taking action. Only proceed with edits, modifications, or implementations when the user explicitly requests them.
</do_not_act_before_instructions>

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls, make all of the independent tool calls in parallel. Prioritize calling tools simultaneously whenever the actions can be done in parallel rather than sequentially. For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into context at the same time. Maximize use of parallel tool calls where possible to increase speed and efficiency. However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially. Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>

## Memory Bank System

This project uses a structured memory bank system with specialized context files. Always check these files for relevant information before starting work:

### Core Context Files

* **CLAUDE-activeContext.md** - Current session state, goals, and progress (if exists)
* **CLAUDE-patterns.md** - Established code patterns and conventions (if exists)
* **CLAUDE-decisions.md** - Architecture decisions and rationale (if exists)
* **CLAUDE-troubleshooting.md** - Common issues and proven solutions (if exists)
* **CLAUDE-config-variables.md** - Configuration variables reference (if exists)
* **CLAUDE-temp.md** - Temporary scratch pad (only read when referenced)

**Important:** Always reference the active context file first to understand what's currently being worked on and maintain session continuity.

### Memory Bank System Backups

When asked to backup Memory Bank System files, you will copy the core context files above and @.claude settings directory to directory @/path/to/backup-directory. If files already exist in the backup directory, you will overwrite them.

## About {YOUR_NAME}

### Role & Scope
- **Title**: {YOUR_TITLE, e.g. VP Engineering / Staff Engineer / CTO}
- **Area**: {YOUR_AREA, e.g. Platform team, Product engineering}
- **Domains owned**: {YOUR_DOMAINS, e.g. Auth, Payments, User Management}

### Company Context
- **Company**: {COMPANY_NAME} — {one-line company description}
- **Product areas**: {PRODUCT_A}, {PRODUCT_B}, {PRODUCT_C}
- **Industry**: {INDUSTRY, e.g. Fintech, SaaS, E-commerce} — {key constraints, e.g. regulated, high-security}
- **Scale**: {SCALE, e.g. Millions of users, multi-region, strict compliance}

### Tech Stack (Daily)
- **Backend**: {LANGUAGES, e.g. Go, Python, Ruby on Rails}
- **Frontend**: {FRAMEWORKS, e.g. TypeScript, React, React Native}
- **Data/Infra**: {INFRA, e.g. PostgreSQL, Redis, Kubernetes}
- When discussing solutions, default to these unless context suggests otherwise

### Priorities (Ranked)
1. **Delivery efficiency** — ship reliably, reduce cycle time, unblock teams
2. **Stability & resiliency** — zero-downtime mindset, graceful degradation, chaos-ready
3. **Long-term thinking** — architect for 2-3 years out, not just next sprint
4. **Cost efficiency** — optimize infra spend, right-size resources, avoid over-engineering
5. **Dependency risk control** — minimize vendor lock-in, own critical paths, audit third-party risk
6. **Team management** — grow engineers, delegate effectively, create leverage
7. **Innovation exploration** — scout adjacent business opportunities, prototype new product areas

### Current Focus Areas
- **{FOCUS_1}** — {brief description}
- **{FOCUS_2}** — {brief description}
- **{FOCUS_3}** — {brief description}

### Working Style
- {YOUR_COMMUNICATION_STYLE, e.g. Direct and straightforward communicator}
- {YOUR_THINKING_LEVEL, e.g. Thinks at the org level: care about cross-team dependencies and strategic trade-offs}
- When discussing architecture, always factor in: team capacity, regulatory constraints, multi-region deployment, and migration paths
- Appreciates phased rollout plans over big-bang proposals
- Values concise executive summaries before diving into technical detail

## ALWAYS START WITH THESE COMMANDS FOR COMMON TASKS

**Task: "List/summarize all files and directories"**

```bash
fd . -t f           # Lists ALL files recursively (FASTEST)
# OR
rg --files          # Lists files (respects .gitignore)
```

**Task: "Search for content in files"**

```bash
rg "search_term"    # Search everywhere (FASTEST)
```

**Task: "Find files by name"**

```bash
fd "filename"       # Find by name pattern (FASTEST)
```

### Directory/File Exploration

```bash
# FIRST CHOICE - List all files/dirs recursively:
fd . -t f           # All files (fastest)
fd . -t d           # All directories
rg --files          # All files (respects .gitignore)

# For current directory only:
ls -la              # OK for single directory view
```

### BANNED - Never Use These Slow Tools

* `tree` - NOT INSTALLED, use `fd` instead
* `find` - use `fd` or `rg --files`
* `grep` or `grep -r` - use `rg` instead
* `ls -R` - use `rg --files` or `fd`
* `cat file | grep` - use `rg pattern file`

### Use These Faster Tools Instead

```bash
# ripgrep (rg) - content search
rg "search_term"                # Search in all files
rg -i "case_insensitive"        # Case-insensitive
rg "pattern" -t py              # Only Python files
rg "pattern" -g "*.md"          # Only Markdown
rg -l "pattern"                 # Filenames with matches
rg -c "pattern"                 # Count matches per file
rg -n "pattern"                 # Show line numbers
rg -A 3 -B 3 "error"            # Context lines
rg "(TODO|FIXME|HACK)"          # Multiple patterns

# ripgrep (rg) - file listing
rg --files                      # List files (respects .gitignore)
rg --files | rg "pattern"       # Find files by name
rg --files -t md                # Only Markdown files

# fd - file finding
fd -e js                        # All .js files (fast find)
fd -x command {}                # Exec per-file
fd -e md -x ls -la {}           # Example with ls

# jq - JSON processing
jq . data.json                  # Pretty-print
jq -r .name file.json           # Extract field
jq '.id = 0' x.json             # Modify field
```

### Search Strategy

1. Start broad, then narrow: `rg "partial" | rg "specific"`
2. Filter by type early: `rg -t python "def function_name"`
3. Batch patterns: `rg "(pattern1|pattern2|pattern3)"`
4. Limit scope: `rg "pattern" src/`

### INSTANT DECISION TREE

```
User asks to "list/show/summarize/explore files"?
  -> USE: fd . -t f  (fastest, shows all files)
  -> OR: rg --files  (respects .gitignore)

User asks to "search/grep/find text content"?
  -> USE: rg "pattern"  (NOT grep!)

User asks to "find file/directory by name"?
  -> USE: fd "name"  (NOT find!)

User asks for "directory structure/tree"?
  -> USE: fd . -t d  (directories) + fd . -t f  (files)
  -> NEVER: tree (not installed!)

Need just current directory?
  -> USE: ls -la  (OK for single dir)
```

## Who I Am
- Engineering leader. Daily: architecture review, strategy, incident investigation, decisions.
- First principles thinker. Explain complex things simply.
- Always use mermaid diagrams for architecture.

## Tech Stack
- **Languages**: {e.g. TypeScript, Go, Rust, Ruby on Rails}
- **Frontend**: {e.g. React + Next.js, React Native + Expo}
- **Infra**: {e.g. Docker Compose, Kubernetes (Helm/Terraform)}
- **Domains**: {e.g. Auth, Security, Fintech, Payments}

## Communication Style
- Concise and direct. Lead with the answer.
- Decision matrix for options. Mermaid for architecture.
- Incidents: timeline -> root cause -> blast radius -> fix -> prevention.
