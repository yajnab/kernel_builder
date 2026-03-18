#!/bin/bash

repo sync -j$(nproc)

repo forall -c '
  echo "Updating submodules in $REPO_PATH"
  git submodule update --init --recursive
'
