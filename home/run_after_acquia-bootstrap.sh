#!/usr/bin/env bash
# This is a script shim that runs after chezmoi apply time,
# but only if the convention-placed script exists. This is
# how the .acquia chezmoi external source can bootstrap itself.

acq_bootstrap="$HOME/.acquia/bootstrap.sh"
if [[ -f "$acq_bootstrap" ]]; then
  echo "--- Running $acq_bootstrap ---"
  "$acq_bootstrap"
  echo "--- Finished running $acq_bootstrap ---"
else
  echo "--- No $acq_bootstrap found, skipping ---"
fi
