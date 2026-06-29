#!/usr/bin/env bash
# Atomic update of the gh-pages branch for the preview system.
#
#   tools/ci/ghpages.sh <op> <branch> <sha> <base-url>
#
# Ops:
#   building   mark the branch preview as building (keeps any existing files)
#   deployed   copy build/web into the branch folder and mark it deployed
#   failed     mark the branch preview as failed (keeps any existing files)
#   remove     delete the branch folder (used when a branch is deleted)
#   refresh    no file change, only re-render the dashboard (used on PR events)
#
# master publishes to the site root, every other branch to its own slug folder.
# Each op touches only its own folder (disjoint paths), then re-renders the
# dashboard page from the whole tree and pushes. On a rejected push it re-clones
# the latest gh-pages and replays, so parallel branch deploys converge without
# losing a folder or a row. The dashboard is always rebuilt from what is on
# disk, so it never depends on a previous run's edit surviving.
#
# Requires GITHUB_TOKEN and GITHUB_REPOSITORY in the environment.

set -euo pipefail

OP="${1:?op required}"
BRANCH="${2:?branch required}"
SHA="${3:?sha required}"
BASE="${4:?base url required}"

# The token remote needs both. A test can point elsewhere with GHPAGES_REMOTE.
if [ -z "${GHPAGES_REMOTE:-}" ]; then
  : "${GITHUB_TOKEN:?GITHUB_TOKEN required}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
RENDER="$REPO_ROOT/.github/scripts/render-dashboard.mjs"
SRC_WEB="$REPO_ROOT/build/web"

SLUG="${BRANCH//\//-}"
if [ "$BRANCH" = "master" ]; then
  DIR="."
  URL="$BASE"
else
  DIR="$SLUG"
  URL="${BASE%/}/$SLUG/"
fi

# GHPAGES_REMOTE lets a test point at a local repo. CI uses the token remote.
REMOTE="${GHPAGES_REMOTE:-https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git}"
UPDATED="$(date -u '+%Y-%m-%d %H:%M')"

write_meta() {
  local dir="$1" status="$2"
  mkdir -p "$dir"
  cat > "$dir/_meta.json" <<EOF
{
  "branch": "$BRANCH",
  "slug": "$SLUG",
  "url": "$URL",
  "sha": "$SHA",
  "status": "$status",
  "updated": "$UPDATED"
}
EOF
}

apply_op() {
  case "$OP" in
    building) write_meta "$DIR" building ;;
    failed)   write_meta "$DIR" failed ;;
    deployed)
      [ -d "$SRC_WEB" ] || { echo "no build at $SRC_WEB"; exit 1; }
      mkdir -p "$DIR"
      cp -R "$SRC_WEB/." "$DIR/"
      write_meta "$DIR" deployed
      ;;
    remove)
      if [ "$BRANCH" = "master" ]; then
        echo "refusing to remove the site root"
        return
      fi
      rm -rf "$DIR"
      ;;
    refresh) : ;;
    *) echo "unknown op: $OP"; exit 1 ;;
  esac
}

attempt() {
  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  if ! git clone --quiet --depth 1 --branch gh-pages "$REMOTE" "$work" 2>/dev/null; then
    # gh-pages does not exist yet: start an orphan branch.
    git clone --quiet --depth 1 "$REMOTE" "$work"
    git -C "$work" checkout --quiet --orphan gh-pages
    git -C "$work" rm -rqf . >/dev/null 2>&1 || true
  fi

  (
    cd "$work"
    touch .nojekyll
    apply_op
    GITHUB_REPOSITORY="$GITHUB_REPOSITORY" GITHUB_TOKEN="$GITHUB_TOKEN" node "$RENDER" .
    git add -A
    if git diff --cached --quiet; then
      echo "gh-pages already up to date for $OP $BRANCH"
      exit 0
    fi
    git -c user.name='github-actions[bot]' \
        -c user.email='github-actions[bot]@users.noreply.github.com' \
        commit --quiet -m "preview: $OP $BRANCH ($SHA) [skip ci]"
    git push --quiet origin gh-pages
  )
}

for i in 1 2 3 4 5 6 7 8; do
  if attempt; then
    echo "gh-pages updated ($OP $BRANCH) on attempt $i"
    exit 0
  fi
  echo "push rejected, refetching and retrying ($i)"
  sleep "$(( (RANDOM % 5) + 1 ))"
done

echo "gh-pages update failed after retries"
exit 1
