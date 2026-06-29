#!/usr/bin/env bash
# Atomic update of the gh-pages branch for the preview system.
#
#   tools/ci/ghpages.sh <op> <branch> <sha> <base-url>
#
# Ops:
#   check      validate the branch name only, write nothing (fast fail gate)
#   building   mark the branch preview as building (keeps any existing files)
#   deployed   copy build/web into the branch folder and mark it deployed
#   failed     mark the branch preview as failed (keeps any existing files)
#   remove     delete the branch folder (used when a branch is deleted)
#   refresh    no file change, only re-render the dashboard (used on PR events)
#
# Layout on gh-pages:
#   master           -> the site root
#   any other branch -> branches/<slug>/        (slug = branch, slashes to dashes)
#   the dashboard    -> _dashboard/
# Non master branches always live under branches/, so a branch can never write
# over the root, the dashboard, .nojekyll, or master's files, whatever it is
# named. Branch names are validated first (safe character set, no traversal, no
# reserved name), so a crafted name cannot escape its folder or corrupt state.
#
# Each op touches only its own folder, re-renders the dashboard from the whole
# tree, and pushes. On a rejected push it re-clones the latest gh-pages and
# replays, so parallel branch deploys converge without losing a folder or a row.
# The dashboard is always rebuilt from what is on disk, so it never depends on a
# previous run's edit surviving.
#
# Requires GITHUB_TOKEN and GITHUB_REPOSITORY in the environment.

set -euo pipefail

OP="${1:?op required}"
BRANCH="${2:?branch required}"
SHA="${3:?sha required}"
BASE="${4:?base url required}"

# Reserved names that may never be deployed as a branch preview. The underscore
# prefix is reserved as a whole namespace (see the leading-character check), so
# _dashboard is covered twice on purpose.
RESERVED=("_dashboard" "branches" "gh-pages")

fail() { echo "ghpages: $*" >&2; exit 1; }

# Refuse anything that could escape the branch folder or shadow a system path.
validate_branch() {
  local b="$1"
  [ -n "$b" ] || fail "empty branch name"
  case "$b" in
    -*|/*|.*|_*) fail "branch name starts with a reserved character: '$b'" ;;
    */|*..*|*//*) fail "branch name has an unsafe path shape: '$b'" ;;
  esac
  case "$b" in
    *[!A-Za-z0-9._/-]*) fail "branch name has disallowed characters: '$b'" ;;
  esac
  [ "${#b}" -le 200 ] || fail "branch name too long: '$b'"
  local r
  for r in "${RESERVED[@]}"; do
    [ "$b" = "$r" ] && fail "reserved branch name: '$b'"
  done
  return 0
}

validate_branch "$BRANCH"
if [ "$OP" = "check" ]; then
  echo "branch name ok: $BRANCH"
  exit 0
fi

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
  DIR="branches/$SLUG"
  URL="${BASE%/}/branches/$SLUG/"
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
      [ -d "$SRC_WEB" ] || fail "no build at $SRC_WEB"
      mkdir -p "$DIR"
      cp -R "$SRC_WEB/." "$DIR/"
      write_meta "$DIR" deployed
      ;;
    remove)
      [ "$BRANCH" = "master" ] && { echo "refusing to remove the site root"; return; }
      rm -rf "$DIR"
      ;;
    refresh) : ;;
    *) fail "unknown op: $OP" ;;
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
    GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}" GITHUB_TOKEN="${GITHUB_TOKEN:-}" node "$RENDER" .
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

fail "gh-pages update failed after retries"
