#!/usr/bin/env bash
# Gather every source of review feedback for a PR into one labeled stream:
#   1. Local .review.json at the repo root (produced by the my-review skill)
#   2. Inline GitHub review comments (anchored to a file/line)
#   3. Review summaries (the top-level body of each review)
#   4. Conversation (issue) comments
#
# Usage: gather-comments.sh [pr-number]
# With no argument, defaults to the current branch's PR.
set -euo pipefail

pr="${1:-$(gh pr view --json number -q .number)}"
repo_root="$(git rev-parse --show-toplevel)"

# Echo a gh api call, then run it.
run_gh() {
  echo "\$ gh api $*"
  gh api "$@"
}

echo "=== LOCAL .review.json ==="
if [[ -f "${repo_root}/.review.json" ]]; then
  cat "${repo_root}/.review.json"
else
  echo "(none)"
fi

echo ""
echo "=== INLINE REVIEW COMMENTS (file/line anchored) ==="
run_gh "repos/{owner}/{repo}/pulls/${pr}/comments" \
  --jq '.[] | {path, line, body, user: .user.login}'

echo ""
echo "=== REVIEW SUMMARIES (top-level review body) ==="
run_gh "repos/{owner}/{repo}/pulls/${pr}/reviews" \
  --jq '.[] | select(.body != "") | {state, body, user: .user.login}'

echo ""
echo "=== CONVERSATION (ISSUE) COMMENTS ==="
run_gh "repos/{owner}/{repo}/issues/${pr}/comments" \
  --jq '.[] | {body, user: .user.login}'
