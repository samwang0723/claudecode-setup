---
name: write-tech-spec
description: Create technical specification documents following the template.
triggers:
  - "write tech spec"
  - "create tech spec"
  - "tech spec"
  - "technical specification"
---

# Write Tech Spec Skill

Generate technical specification documents following the template.

## Usage

```
/write-tech-spec [feature name]
```

## What This Skill Does

1. **Gathers information** about the feature/change through targeted questions
2. **Generates a complete tech spec** following the TMAB template structure
3. **Outputs both formats**:
   - Markdown file for local storage/git
   - Confluence-ready content for direct upload

## Template Structure

The tech spec follows DDD (Domain Driven Design) approach with these sections:

### Header Metadata

- Team
- Feature Label
- Authors
- Audiences
- Status (Draft → In Review → Approved/Rejected)
- Version
- Reviewers
- Useful links (PRD/Figma/Slack)
- Approved Date

### Main Sections

1. **TL;DR Change Summary** - Quick purpose and major changes
2. **Background** - Objective, Goals, Non-Goals
3. **Architecture Overview** - Component diagram, Service relationships
4. **Domain Design** - Use cases, Fund flows, Domain models, State machines, Configuration
5. **Data Design** - DB schemas, Storage, Privacy, Retention
6. **APIs Design** - Model definitions, User/Internal/Partner APIs, Sequence diagrams
7. **Logging Design** - Log information and privacy considerations
8. **Security Design** - Auth, XSS/CSRF/CORS/SQL injection prevention
9. **Compatibility Design** - Backward compatibility, supported platforms
10. **Operations** - Capacity, Rollout, Monitoring, Fallback, Security assessment, Testing, Infrastructure

## Workflow

### Step 1: Gather Context

Ask the user for:

- Feature name and description
- Is this a new feature or modification?
- Which pillar/team owns this?
- Key stakeholders/reviewers
- Related PRD/Figma/Slack links

### Step 2: Technical Discovery

For each relevant section, ask targeted questions:

- What services are involved?
- Are there new domain models?
- Any database schema changes?
- API endpoints needed?
- Feature flags/configuration?

### Step 3: Generate Tech Spec

Create the document with:

- All gathered information filled in
- Placeholders for diagrams (marked with `[DIAGRAM: description]`)
- Code blocks for schemas, APIs, state machines
- Clear action items marked with `[TODO: description]`

### Step 4: Output

1. Save markdown to `.claude/tasks/{slug}/tech-spec.md`
2. Optionally upload to Confluence using `mcp__atlassian__confluence_create_page`

## Section Guidelines

### TL;DR Change Summary

Keep it to 2-3 sentences. Answer: What? Why? Impact?

### Background

- **Objective**: Why this change is needed
- **Goals**: Prioritized list of what the system will do
- **Non-Goals**: Explicitly out of scope items

### Architecture Overview

Include component diagram showing position in overall architecture.
List upstream/downstream service relationships.

### Domain Design

- Use cases with actors and scenarios
- Fund flow diagrams if financial transactions involved
- Domain models (entities, value objects)
- State machines for stateful models
- Configuration/feature flags

### Data Design

- ER diagrams for schema changes
- Consider user vs non-user data separation
- Privacy by design for PII
- Retention and archival strategy

### APIs Design

- OpenAPI specifications (link to ma-backend\_\_openapi-mock)
- Sequence diagrams for critical flows
- Idempotency, rate limiting, caching mechanisms
- Error codes following pattern: `{App}-{4-digit-error-code}`
- Timeout and retry mechanisms

### Security Design

- Authentication/authorization
- XSS/CSRF/CORS/SQL injection prevention
- Key management
- Threat modeling if external exposure

### Operations (REQUIRED)

- **Rollout Plan**: Incremental deployment strategy
- **Monitoring**: Metrics, alerts, dashboards
- **Fallback Plan**: Feature flags, kill switches
- **Security Assessment**: Work with security team before release

## Error Code Structure

```
{App}-{Service Error Code}

Examples:
CC-0400 Transaction rejected
CC-0401 Service unexpected error
```
