#!/usr/bin/env bash

set -Exeuo pipefail

if [[ -z "$1" ]]
then
    (>&2 echo 'Error: script requires a release (gzipped) tarball path, e.g. "/tmp/filecoin-ffi-Darwin-standard.tar.tz"')
    exit 1
fi

if [[ -z "$2" ]]
then
    (>&2 echo 'Error: script requires a release name, e.g. "filecoin-ffi-Darwin-standard" or "filecoin-ffi-Linux-optimized"')
    exit 1
fi

RELEASE_FILE=$1
RELEASE_NAME=$2
RELEASE_TAG="${CIRCLE_SHA1:0:16}"

# make sure we have a token set, api requests won't work otherwise
if [ -z $GITHUB_TOKEN ]; then
  echo "\$GITHUB_TOKEN not set, publish failed"
  exit 1
fi

# see if the release already exists by tag
RELEASE_RESPONSE=`
  curl \
    --header "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/releases/tags/$RELEASE_TAG"
`

RELEASE_ID=`echo $RELEASE_RESPONSE | jq '.id'`

if [ "$RELEASE_ID" = "null" ]; then
  echo "creating release"

  RELEASE_DATA="{
    \"tag_name\": \"$RELEASE_TAG\",
    \"target_commitish\": \"$CIRCLE_SHA1\",
    \"name\": \"$RELEASE_TAG\",
    \"body\": \"\"
  }"

  # create it if it doesn't exist yet
  RELEASE_RESPONSE=`
    curl \
      --request POST \
      --header "Authorization: token $GITHUB_TOKEN" \
      --header "Content-Type: application/json" \
      --data "$RELEASE_DATA" \
      "https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/releases"
  `
else
  echo "release already exists"
fi

RELEASE_UPLOAD_URL=`echo $RELEASE_RESPONSE | jq -r '.upload_url' | cut -d'{' -f1`

curl \
  --request POST \
  --header "Authorization: token $GITHUB_TOKEN" \
  --header "Content-Type: application/octet-stream" \
  --data-binary "@$RELEASE_FILE" \
  "$RELEASE_UPLOAD_URL?name=$(basename $RELEASE_FILE)"

echo "release file uploaded"
