#!/bin/bash
# Sync le SDK Flutter depuis le monorepo vers ce repo public

MONOREPO_SDK="/Users/jorisobert/StudioProjects/comments-2/packages/gvl_comments/"
TARGET_DIR="/Users/jorisobert/StudioProjects/gvl_comments-RECOVERY/"

rsync -av --delete \
  --exclude='.dart_tool/' \
  --exclude='build/' \
  --exclude='.flutter-plugins' \
  --exclude='.flutter-plugins-dependencies' \
  --exclude='.packages' \
  --exclude='pubspec.lock' \
  --exclude='.git/' \
  --exclude='sync-from-monorepo.sh' \
  "$MONOREPO_SDK" "$TARGET_DIR"

echo ""
echo "=== Sync terminé. Changements :"
git -C "$TARGET_DIR" status --short
