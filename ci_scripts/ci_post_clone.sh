#!/bin/sh
# Xcode Cloud: runs after repo clone, before any build.
#
# Quality gates (SwiftLint, SwiftFormat) run on PULL REQUEST workflows and on
# builds of the `staging` branch: they gate the merge and the pre-release
# branch, not the ship. The TestFlight workflow builds already-reviewed code
# from its target branch, so it skips these and never blocks a release on a
# style finding. Gate keys: CI_PULL_REQUEST_NUMBER is set only for PR-triggered
# builds; CI_BRANCH is the branch of a branch-triggered build.
set -e

REPOSITORY_DIR="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
cd "$REPOSITORY_DIR"

if [ -z "$CI_PULL_REQUEST_NUMBER" ] && [ "$CI_BRANCH" != "staging" ]; then
    echo "Not a pull request or staging build; skipping quality gates."
    exit 0
fi

# Both tools are pinned to an exact version and verified by checksum so CI lints with the same rules every run.
# SwiftFormat used to come from `brew install`, which always installs the latest release: a new rule in a newer
# version (e.g. `extensionAttributes` in 0.64) failed the gate on code that passed locally. To upgrade a tool, bump
# its version and checksum here, and run the same version locally (`brew upgrade swiftformat`).
SWIFTLINT_VERSION="0.65.0"
SWIFTLINT_SHA256="d6cb0aa7a2f5f1ef306fc9e37bcb54dc9a26facc8f7784ac0c3dd3eccf5c6ba6"
SWIFTFORMAT_VERSION="0.64.7"
SWIFTFORMAT_SHA256="e82e224325cbd3403fc7b68caf6c917926dc106de3af875fca4b87e3c4634038"
SWIFTLINT_DIR="$(mktemp -d)"
SWIFTFORMAT_DIR="$(mktemp -d)"
trap 'rm -rf "$SWIFTLINT_DIR" "$SWIFTFORMAT_DIR"' 0

curl --fail --location --silent --show-error \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
    --output "$SWIFTLINT_DIR/swiftlint.zip"
echo "$SWIFTLINT_SHA256  $SWIFTLINT_DIR/swiftlint.zip" | shasum --algorithm 256 --check
unzip -q "$SWIFTLINT_DIR/swiftlint.zip" -d "$SWIFTLINT_DIR"

curl --fail --location --silent --show-error \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip" \
    --output "$SWIFTFORMAT_DIR/swiftformat.zip"
echo "$SWIFTFORMAT_SHA256  $SWIFTFORMAT_DIR/swiftformat.zip" | shasum --algorithm 256 --check
unzip -q "$SWIFTFORMAT_DIR/swiftformat.zip" -d "$SWIFTFORMAT_DIR"
SWIFTFORMAT_BIN="$(find "$SWIFTFORMAT_DIR" -type f -name swiftformat | head -n 1)"
chmod +x "$SWIFTFORMAT_BIN"

export XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain"
"$SWIFTLINT_DIR/swiftlint" lint --strict --quiet
"$SWIFTFORMAT_BIN" --lint --swift-version 6.0 --language-mode 6 .
