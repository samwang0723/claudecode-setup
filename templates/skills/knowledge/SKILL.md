---
name: knowledge
description: >
  Search, browse, and update the Obsidian knowledge vault using the Obsidian CLI.
  Use when asked about fiat SOPs, interview questions, engineering references,
  project docs, commands, or anything that might be in personal notes.
---

# Knowledge Vault

Personal Obsidian knowledge base for Sam Wang.

## Setup

- **Vault name**: `knowledge`
- **Vault path**: `/Users/samwang/.claude/knowledge/`
- **CLI binary**: `/Applications/Obsidian.app/Contents/MacOS/obsidian`
- **Prerequisite**: Obsidian app must be running for CLI commands to work.

> **Fallback**: If Obsidian is not running (CLI returns error), fall back to filesystem tools
> (Grep, Read, Glob) with the vault path above.

## Folder Structure

| Folder | Purpose | Examples |
|--------|---------|---------|
| `00-Active/` | Current work (2025-2026) | Card Lifestyle Offset Agent, Clowdbot, Lynq-Cubix, ACME, React Native, proposals |
| `01-Reference/` | Evergreen SOPs & knowledge | Commands.md (master ref), Fiat Critical Knowledge, Entity Migration, GPG YubiKey Setup, auth flows |
| `02-Engineering/` | Tech skills & tools | Coding Patterns, System Design, Kubernetes, Rust, React, PostgreSQL, MCP, AI tools |
| `03-People/` | Interviews, hiring, career | Interview question banks, JD templates, performance reviews |
| `04-Projects/` | Named project docs | Project Harbour, Bankie System, Project Allison, Jarvis |
| `99-Archive/` | Historical (read-only) | Migrations/, Incidents/, Completed-Projects/, Legacy-Setup/ |
| `assets/` | Images, attachments | Screenshots, swagger.yaml, javascript.zip |

## Operations

All commands use `obsidian` CLI. Add `vault=knowledge` if multiple vaults are open.

### Search: `/knowledge <query>`

Search across all notes for a keyword or topic.

```bash
# Full-text search (file list)
obsidian search query="<query>"

# Search with matching line context (like rg -C)
obsidian search:context query="<query>"

# Scoped to a folder
obsidian search query="<query>" path="01-Reference"

# Limit results
obsidian search query="<query>" limit=10

# Case-sensitive search
obsidian search query="<query>" case

# JSON output for structured parsing
obsidian search query="<query>" format=json
```

Then read matching files with `obsidian read` to get full content.

### Browse: `/knowledge browse <folder>`

List notes in a category:

```bash
# List all files
obsidian files

# List files in a specific folder
obsidian files folder="01-Reference"

# Total file count
obsidian files total

# List all folders
obsidian folders

# Folder info (file count, size)
obsidian folder path="02-Engineering"
```

Valid folders: `00-Active`, `01-Reference`, `02-Engineering`, `03-People`, `04-Projects`, `99-Archive`, `99-Archive/Migrations`, `99-Archive/Incidents`, `99-Archive/Completed-Projects`, `99-Archive/Legacy-Setup`

### Read: `/knowledge read <filename>`

Read a specific note:

```bash
# Read by file name (wikilink-style resolution)
obsidian read file="Commands"

# Read by exact path
obsidian read path="01-Reference/Commands.md"

# Get file metadata
obsidian file file="Commands"

# Read file properties/frontmatter
obsidian properties file="Commands"

# Show outline/headings
obsidian outline file="Commands"
```

### Update: `/knowledge update <filename>`

Modify an existing note:

```bash
# Append content to end of file
obsidian append file="Commands" content="## New Section\nNew content here"

# Prepend content to beginning of file
obsidian prepend file="Commands" content="## Top Section\nContent here"

# Set/update a frontmatter property
obsidian property:set file="Commands" name="updated" value="2026-03-13"

# Remove a property
obsidian property:remove file="Commands" name="deprecated"
```

For complex edits (replacing/rewriting sections), read the file first with `obsidian read`, then use the Edit tool with the vault path.

### Add: `/knowledge add <folder> <title>`

Create a new note:

```bash
# Create with content
obsidian create name="<Title>" path="<folder>/<Title>.md" content="---\ntags:\n  - <tag>\nCreated: 2026-03-13\nUpdated: 2026-03-13\n---\n\n# <Title>\n\nContent here"

# Create from template
obsidian create name="<Title>" path="<folder>/<Title>.md" template="<template-name>"

# List available templates
obsidian templates
```

### Delete: `/knowledge delete <filename>`

```bash
# Move to trash (safe)
obsidian delete file="<filename>"

# Permanent delete (use with caution)
obsidian delete file="<filename>" permanent
```

### Daily Notes

```bash
# Read today's daily note
obsidian daily:read

# Append to daily note (quick capture)
obsidian daily:append content="- [ ] Follow up on <topic>"

# Prepend to daily note
obsidian daily:prepend content="## Morning Notes\n..."

# Get daily note path
obsidian daily:path
```

### Tags & Tasks

```bash
# List all tags with counts
obsidian tags counts sort=count

# Tag info (which files use it)
obsidian tag name="fiat" verbose

# List incomplete tasks
obsidian tasks todo

# List completed tasks
obsidian tasks done

# Tasks from daily note
obsidian tasks daily

# Tasks from a specific file
obsidian tasks file="Commands"

# Toggle a task
obsidian task path="01-Reference/Commands.md" line=42 toggle
```

### Graph & Links

```bash
# Backlinks to a note
obsidian backlinks file="Commands"
obsidian backlinks file="Commands" counts

# Outgoing links from a note
obsidian links file="Commands"

# Find orphan notes (no incoming links)
obsidian orphans

# Find dead-end notes (no outgoing links)
obsidian deadends

# Find unresolved/broken links
obsidian unresolved
```

### History & Versions

```bash
# List file versions
obsidian history file="Commands"

# Read a specific version
obsidian history:read file="Commands" version=2

# Restore a version
obsidian history:restore file="Commands" version=3

# Diff between versions
obsidian diff file="Commands" from=1 to=3
```

## Category Guide

When searching, target the right folder:

| Looking for... | Search in |
|---------------|-----------|
| Console commands, kubectl, tsh, rails | `01-Reference/Commands.md` |
| Fiat wallet, vendor integration, currency launch | `01-Reference/Fiat*.md` |
| Interview questions, hiring | `03-People/` |
| Active vendor evaluations, current projects | `00-Active/` |
| Auth flows (TOTP, PassKey, BFF) | `01-Reference/` |
| System design, coding patterns | `02-Engineering/` |
| Old migrations, incidents | `99-Archive/` |

## Instructions

1. When the user asks about a topic that might be in their notes, search the vault first before answering from general knowledge.
2. Present results concisely — show the file name, relevant excerpt, and offer to show more.
3. If updating a note, prefer `obsidian append`/`obsidian prepend` for additive changes. Use Edit tool only for surgical replacements within a section.
4. For new notes, follow the existing naming convention (Title Case, descriptive names).
5. Never delete notes without explicit confirmation.
6. If the CLI returns an error (Obsidian not running), fall back to filesystem tools with the vault path `/Users/samwang/.claude/knowledge/`.

---

Query: $ARGUMENTS
