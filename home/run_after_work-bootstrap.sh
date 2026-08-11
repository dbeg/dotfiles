#!/usr/bin/env bash
# This is a script shim that runs after chezmoi apply time,
# but only if the convention-placed script exists. This is
# how the .work chezmoi external source can bootstrap itself.

work_bootstrap="$HOME/.work/bootstrap.sh"
if [[ -f "$work_bootstrap" ]]; then
  echo "--- Running $work_bootstrap ---"
  "$work_bootstrap"
  echo "--- Finished running $work_bootstrap ---"
else
  echo "--- No $work_bootstrap found, skipping ---"
fi
