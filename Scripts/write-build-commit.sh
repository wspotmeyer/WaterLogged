#!/bin/sh
#
# write-build-commit.sh
#
# Records the short hash of the commit being built in
# WaterLogged/Resources/BuildCommit.txt. The app bundles that file and the
# About screen shows it after the build number, e.g. "(42) d3fa839".
#
# The file is generated, never committed (see .gitignore). It is written:
#   - locally, by the git hooks in Scripts/git-hooks after each commit,
#     checkout, merge, and rebase (enable once with
#     `git config core.hooksPath Scripts/git-hooks`);
#   - in Xcode Cloud, by ci_scripts/ci_post_clone.sh, using CI_COMMIT.
#
# If the file is missing, the app simply shows the build number alone.

set -eu

repo_root="${CI_PRIMARY_REPOSITORY_PATH:-$(git rev-parse --show-toplevel)}"
commit="${CI_COMMIT:-$(git -C "$repo_root" rev-parse HEAD)}"

# Seven characters matches how GitHub abbreviates commits.
printf '%s\n' "$(printf '%s' "$commit" | cut -c1-7)" > "$repo_root/WaterLogged/Resources/BuildCommit.txt"
