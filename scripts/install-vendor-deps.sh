#!/usr/bin/env bash
# Install vendor SUT-lib npm dependencies for the Selakovic 2016 dataset.
#
# Run from the fork root after `git clone`/`git submodule update`. Uses pnpm
# with --frozen-lockfile so the resolved versions match each pnpm-lock.yaml
# byte-for-byte. node_modules/ is gitignored — this script repopulates it.
#
# See MODIFICATIONS.md for the rationale and the full list of vendored deps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm not found in PATH. Install via 'npm install -g pnpm' or 'corepack enable'." >&2
  exit 1
fi

# Each entry is a directory containing a package.json + pnpm-lock.yaml.
# Layout follows the version-conflict strategy documented in MODIFICATIONS.md.
#
# server-side `require()` deps (SUT lib's own npm deps):
# - chalk: per-issue (chalk@1 for 27a/27b vs chalk@0.4 for 28)
# - request: per-issue (2.12 vs 2.45 deps differ)
# - socket.io: per-issue (0.8.5 vs 0.8.7 patch versions)
# - cheerio: shared (8 issues, all cheerio@0.13.1)
# - mocha: single issue (763)
#
# client `<script src>` deps (jquery/handlebars/underscore that the v_*.html
# loads from a CDN; jsdom does not auto-load <script src>, so MB-scanner's
# preprocess reads node_modules/<pkg>/dist/<pkg>.js and concatenates it into the
# candidate setup):
# - angular: shared category (27 issues, jquery@1.11.3)
# - ember: shared category (jquery@2.1.3 + handlebars@1.1.0); issue_3174 /
#   issue_3288 override jquery to 1.7.x (conflicts with the category 2.1.3)
# - react: shared category (5 issues, jquery@1.7.x)
# - backbone: shared category (5 issues, underscore@1.8.3 + jquery@2.1.3)
# - ejs / moment / node-lru-cache / underscore.string / underscore: shared
#   category (jquery@2.1.3)
# - q: shared category (issue_169, jquery@1.7.x)
# (jquery itself is the SUT in JQueryIssues, loaded as jquery_before.js -> no
#  vendored CDN dep there.)
DIRS=(
  # server-side require() deps
  serverIssues/ChalkIssues/issues/issue_27a
  serverIssues/ChalkIssues/issues/issue_27b
  serverIssues/ChalkIssues/issues/issue_28
  serverIssues/CheerioIssues
  serverIssues/MochaIssues/issues/issue_763
  serverIssues/RequestIssues/issues/issue_403
  serverIssues/RequestIssues/issues/issue_1165
  serverIssues/Socket.ioIssues/issues/issue_573
  serverIssues/Socket.ioIssues/issues/issue_689
  # client <script src> deps
  clientIssues/AngularIssues
  clientIssues/EmberIssues
  clientIssues/EmberIssues/issues/issue_3174
  clientIssues/EmberIssues/issues/issue_3288
  clientIssues/ReactIssues
  clientServerIssues/BackboneIssues
  clientServerIssues/EjsIssues
  clientServerIssues/MomentIssues
  clientServerIssues/NodeLruCacheIssues
  clientServerIssues/QIssues
  clientServerIssues/Underscore.stringIssues
  clientServerIssues/UnderscoreIssues
)

for d in "${DIRS[@]}"; do
  echo "==> $d"
  (cd "$ROOT/$d" && pnpm install --frozen-lockfile)
done

echo
echo "All vendor deps installed. node_modules/ regenerated for ${#DIRS[@]} locations."
