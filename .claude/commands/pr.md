Create a PR for the current branch. Follow the Pre-PR Checklist from CLAUDE.md:

This assumes /review has already been run and passed.

1. Run `git log --oneline main..HEAD` to understand all commits on this branch.
2. Run `git diff main` to see the full diff.
3. Verify the branch has been pushed to remote (`git branch -vv`). If not, stop and ask Victor to push first.
4. Determine which issue(s) this branch closes from the commit history and branch name.
5. Create the PR using `gh pr create` with:
   - Title in conventional commits format: `type: description (#issue)`
   - Body with: Summary (bullet points), Changes (files touched and why), How to test (if applicable)
   - Use `Closes #XX` for each related issue
6. Return the PR URL.
