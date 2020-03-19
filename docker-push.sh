#!/bin/bash

REPO="$DOCKER_USERNAME"/bungeecord

if [ "$TRAVIS_BRANCH" == "master" ]; then
    if [ "$BUNGEECORD_JOB_ID" == "lastStableBuild" ]; then
        # Upload to "latest"
        docker tag bungeecord "$REPO":latest
        docker push "$REPO":latest
    else
        # Or to any given build number
        docker tag bungeecord "$REPO":"$BUNGEECORD_JOB_ID"
        docker push "$REPO":"$BUNGEECORD_JOB_ID"
    fi
elif [ "$TRAVIS_BRANCH" == "develop" ]; then
    if [ "$BUNGEECORD_JOB_ID" == "lastStableBuild" ]; then
        # In the "develop" branch only upload to "nightly"
        docker tag bungeecord "$REPO":nightly
        docker push "$REPO":nightly
    fi
else
    echo "Skipping deployment because it's neither master nor develop"
    exit 0;
fi
