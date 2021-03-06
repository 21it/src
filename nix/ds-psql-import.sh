#!/bin/sh

set -e

THIS_DIR="$(dirname "$(realpath "$0")")"
BUILD_DIR="$THIS_DIR/../build"
DATA_DIR="/var/lib/postgresql/data"

sh "$THIS_DIR/ds-down.sh" || true

docker run --rm \
  -v 21it_postgres:$DATA_DIR \
  -v $BUILD_DIR:/app \
  -w /app heathmont/postgres:11-alpine-a2e8bbe \
  sh -c "
  mkdir -p $DATA_DIR &&
  tar -xvzf ./data.tar.gz -C /
  "

echo "21it_postgres ==> imported from $BUILD_DIR/data.tar.gz"
