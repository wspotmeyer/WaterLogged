#!/bin/sh
#
# ci_post_clone.sh
#
# Xcode Cloud runs this after cloning the repository, before every action.
# It records the commit being built so the About screen can show it; see
# Scripts/write-build-commit.sh.

set -eu

"$CI_PRIMARY_REPOSITORY_PATH/Scripts/write-build-commit.sh"
