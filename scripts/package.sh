#!/usr/bin/env bash
set -euo pipefail
VERSION=${VERSION:-v0.1.0}
COMMIT=$(git rev-parse --short HEAD)
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DIST=dist
mkdir -p $DIST
for GOOS in linux windows; do
  for GOARCH in amd64 arm64; do
    EXT=""; [ "$GOOS" = windows ] && EXT=".exe"
    OUT="nextgen-ai_${VERSION}_${GOOS}_${GOARCH}${EXT}"
    echo "Building $OUT"
    GOOS=$GOOS GOARCH=$GOARCH go build -trimpath -ldflags "-X main.Version=$VERSION -X main.Commit=$COMMIT -X main.Date=$DATE" -o "$DIST/$OUT" ./cmd/server
  done
done
( cd $DIST && shasum -a 256 * > SHA256SUMS.txt )
 echo "Artifacts in $DIST"