#!/bin/sh
set -eu

# XcodeGen's project is intentionally ignored, including the workspace location
# where Xcode expects its dependency lock. Generate first, then install the
# tracked lock so local and CI builds resolve the same reviewed revisions.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
resolved_dir="Fixer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"

cd "$repo_dir"
xcodegen generate
mkdir -p "$resolved_dir"
cp Package.resolved "$resolved_dir/Package.resolved"
