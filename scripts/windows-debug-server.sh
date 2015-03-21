#!/usr/bin/env bash

PLATFORM=$(uname -s | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")
COMMIT_MESSAGE=$(git show -s --format=%B $TRAVIS_COMMIT | tr -d '\n')
GITSHA="$1"

if [ $PLATFORM != "linux" ]; then
    exit 0
fi

if test "${COMMIT_MESSAGE#*'[windebug]'}" == "$COMMIT_MESSAGE"
then
    echo "no [windebug] in commit message, nothing to do here."
    exit 0
fi

echo "Starting Windows Debug Server"
