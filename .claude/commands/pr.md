Create a PR for the current branch. This is an execution command, not a review — run `/review` first.

Input: optional issue number or PR title override. Use `$ARGUMENTS` as the input.

## Mode

**Arguments:** `$ARGUMENTS`

- **No arguments** → infer issue number from branch name and commit history. Generate PR title from commits.
- **An issue number** (e.g., `/pr 15`) → link the PR to that issue with `Closes #15`.
- **A title string** (e.g., `/pr "chore: remove url shortener"`) → use as the PR title instead of generating one.

## Context gathering

Before creating, silently:

1. Read `CLAUDE.md` → Pre-PR Checklist and Definition of Done
2. Run `git log --oneline main..HEAD` to understand all commits on this branch
3. Run `git diff main --stat` to see the scope of changes
4. Run `git diff main` to see the full diff
5. Run `git branch -vv` to check if the branch tracks a remote
6. Run `git status` to check for uncommitted changes

## Pre-flight checks

Stop and report if any of these fail:

- [ ] Branch is not `main` (never PR from main)
- [ ] Branch has been pushed to remote (if not, tell Victor to push first)
- [ ] No uncommitted changes that should be included
- [ ] At least one commit vs main

## Steps

1. Determine which issue(s) this branch closes from the commit history, branch name, or `$ARGUMENTS`
2. Create the PR using `gh pr create` with:
   - Title in conventional commits format: `type: description (#issue)`
   - Body with: Summary (bullet points), Changes (files touched and why), Deploy notes (if any VPS-side steps needed)
   - Use `Closes #XX` for each related issue
3. Return the PR URL

## Output

```
PR created: <url>
Closes: #XX
Title: type: description (#issue)
```

If something went wrong, report the failure clearly — don't retry silently.
