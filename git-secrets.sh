#!/bin/sh
# run on root of repo after initialize/clone so hooks can be written to .git
#
git secrets --install -f
git secrets --register-aws