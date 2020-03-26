#!/bin/bash

REPO="$DOCKER_USERNAME"/bungeecord

if [ "$TRAVIS_BRANCH" == "master" ]; then
    if [ "$BUNGEECORD_JOB_ID" == "lastStableBuild" ]; then
        # Upload to "latest"
        TARGET="$REPO":latest
    else
        # Or to any given build number
        TARGET="$REPO":"$BUNGEECORD_JOB_ID"
    fi
elif [ "$TRAVIS_BRANCH" == "develop" ]; then
    if [ "$BUNGEECORD_JOB_ID" == "lastStableBuild" ]; then
        # In the "develop" branch only upload to "nightly"
        TARGET="$REPO":nightly
    fi
else
    echo "Skipping deployment because it's neither master nor develop"
    exit 0
fi

# Upload to Docker Hub
docker tag bungeecord "$TARGET"
docker push "$TARGET"
