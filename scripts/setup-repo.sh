#!/bin/bash
set -e

# Setup a new GitHub repo with Victor's standard configuration.
#
# Usage:
#   ./scripts/setup-repo.sh vpatrin/my-repo
#   ./scripts/setup-repo.sh vpatrin/my-repo api scraper frontend   # with extra labels
#
# What it does:
#   1. Configures merge settings (squash + rebase, no merge commit, delete branch on merge)
#   2. Disables wiki
#   3. Deletes GitHub default labels, creates standard set
#   4. Creates main-protection ruleset (no deletion, no force push, require PR)
#   5. Adds any extra labels passed as arguments

REPO="$1"
shift 2>/dev/null || true  # remaining args are extra labels

if [ -z "$REPO" ]; then
  echo "Usage: $0 <owner/repo> [extra-label ...]"
  echo "Example: $0 vpatrin/my-repo api scraper frontend"
  exit 1
fi

echo "=== Setting up $REPO ==="

# ── 1. Merge settings ──────────────────────────────────────────────
echo ""
echo "→ Configuring merge settings..."
gh repo edit "$REPO" \
  --enable-squash-merge \
  --enable-rebase-merge \
  --enable-merge-commit=false \
  --delete-branch-on-merge \
  --enable-wiki=false
echo "  Done: squash + rebase only, delete branch on merge, wiki disabled"

# ── 2. Labels ───────────────────────────────────────────────────────
echo ""
echo "→ Cleaning up default labels..."

# GitHub default labels to remove
DEFAULT_LABELS=(
  "documentation"
  "duplicate"
  "enhancement"
  "good first issue"
  "help wanted"
  "invalid"
  "question"
  "wontfix"
)

for label in "${DEFAULT_LABELS[@]}"; do
  gh label delete "$label" --repo "$REPO" --yes 2>/dev/null && echo "  Deleted: $label" || true
done

echo ""
echo "→ Creating standard labels..."

# Base labels: name|color|description
# Colors are consistent across all repos
BASE_LABELS="
bug|b93c2c|Something isn't working
feature|0e8a16|New feature or enhancement
chore|666666|Maintenance and housekeeping
refactor|c5def5|Code restructuring, no behavior change
docs|0075ca|Documentation changes
"

echo "$BASE_LABELS" | while IFS='|' read -r label color description; do
  [ -z "$label" ] && continue
  # Try create, if exists update to ensure consistent color/description
  gh label create "$label" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null \
    && echo "  Created: $label" \
    || { gh label edit "$label" --repo "$REPO" --color "$color" --description "$description" 2>/dev/null && echo "  Updated: $label"; }
done

# Extra labels (repo-specific, neutral color)
for label in "$@"; do
  gh label create "$label" --repo "$REPO" --color "ededed" --description "" 2>/dev/null \
    && echo "  Created extra: $label" \
    || echo "  Exists: $label (skipped)"
done

# ── 3. Main protection ruleset ──────────────────────────────────────
echo ""
echo "→ Creating main-protection ruleset..."

# Check if ruleset already exists
EXISTING=$(gh api "repos/$REPO/rulesets" 2>/dev/null | python3 -c "
import json, sys
rulesets = json.load(sys.stdin)
for r in rulesets:
    if r['name'] == 'main-protection':
        print(r['id'])
        break
" 2>/dev/null || true)

if [ -n "$EXISTING" ]; then
  echo "  Ruleset already exists (ID: $EXISTING), skipping"
else
  gh api "repos/$REPO/rulesets" --method POST --input - <<'RULESET_EOF'
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash", "rebase"]
      }
    }
  ],
  "bypass_actors": []
}
RULESET_EOF
  echo "  Created main-protection ruleset"
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "=== $REPO setup complete ==="
echo ""
echo "Verify:"
echo "  gh repo view $REPO --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed,deleteBranchOnMerge,hasWikiEnabled"
echo "  gh label list --repo $REPO"
echo "  gh ruleset list --repo $REPO"
