Review the current branch as a senior software engineer. Be honest, opinionated, and educational.

1. Run `git diff main --stat` and `git diff main` to see all changes on this branch.
2. Run `git log --oneline main..HEAD` to see all commits.
3. Check `git status` for untracked or unstaged files that should be included.
4. Review against the Pre-PR Checklist from CLAUDE.md:
   - Broken links or missing data in content.js
   - CSS issues (hover states, responsive, consistency)
   - Caddyfile syntax and routing correctness
   - No secrets or sensitive paths exposed
   - Homepage renders correctly with the changes
5. Categorize findings: must fix, should fix, nit/optional.
6. Give a clear verdict: ready to push, or list what needs fixing first.
