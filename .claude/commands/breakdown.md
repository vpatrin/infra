Break down a task into small, focused GitHub issues.

Rules from CLAUDE.md:
- Each issue should be independently deployable
- One issue = one branch = one PR

Steps:
1. Analyze the task and identify logical units of work.
2. Order them by dependency — which issues must land before others?
3. For each unit, draft:
   - Title (conventional commits style)
   - Labels (from: `bug`, `feature`, `chore`, `refactor`, `docs`)
   - Description
   - Acceptance criteria
4. Present the numbered breakdown for Victor's approval before creating anything.
5. Once approved, create each issue with `gh issue create --label <label>`.
6. List all created issues with their numbers and URLs.
