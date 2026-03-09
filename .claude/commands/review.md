Review the current branch as a senior software engineer. Be honest, opinionated, and educational.

1. Run `git diff main --stat` and `git diff main` to see all changes on this branch.
2. Run `git log --oneline main..HEAD` to see all commits.
3. Check `git status` for untracked or unstaged files that should be included.
4. Review against the Pre-PR Checklist from CLAUDE.md:
   - No secrets or credentials exposed
   - Caddyfile syntax valid (check directive ordering, proper nesting)
   - docker-compose.yml syntax correct
   - Existing services not affected by changes
   - Makefile targets work correctly
   - README and docs/ updated if routing or ports changed
5. For Caddyfile changes: verify all routes still resolve correctly, check for conflicting matchers.
6. For docker-compose changes: verify network connectivity, volume mounts, restart policies.
7. Categorize findings: 🔴 Must fix, 🟡 Should fix, 🟢 Nit/optional.
8. Give a clear verdict: ready to push, or list what needs fixing first.
