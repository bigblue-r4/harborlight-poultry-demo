#!/bin/sh
# Re-copy the witness code this demo runs on from kiss-protocol, at a given ref.
#
#   scripts/sync-from-kiss.sh <path-to-kiss-protocol-checkout> [ref]     (ref defaults to the latest v* tag)
#
# The demo is deliberately self-contained (Go does not allow importing another
# module's internal/ packages), so these files are copies. Run this after a
# kiss-protocol release, then `go test ./... && go run .` and commit.
set -eu
KISS=${1:?usage: $0 <kiss-protocol checkout> [ref]}
REF=${2:-$(git -C "$KISS" describe --tags --abbrev=0 --match 'v*')}
SHA=$(git -C "$KISS" rev-parse --short "$REF^{commit}")
HERE=$(cd "$(dirname "$0")/.." && pwd)

FILES="
internal/store/store.go internal/store/log_test.go internal/store/fuzz_test.go internal/store/treehead_missing_test.go internal/store/treehead_signer_test.go
internal/farm/farm.go internal/farm/farm_test.go internal/farm/testdata/farm_events.jsonl
internal/pipelock/tailer.go internal/pipelock/ident_unix.go internal/pipelock/ident_other.go internal/pipelock/openinfo.go
internal/pipelock/evidence_tailer.go internal/pipelock/tailer_test.go internal/pipelock/evidence_tailer_test.go internal/pipelock/tailer_resume_test.go
internal/encrypt/encrypt.go internal/encrypt/encrypt_test.go
internal/merkle/tree.go internal/merkle/proof.go internal/merkle/tree_test.go internal/merkle/proof_test.go internal/merkle/fuzz_test.go
internal/signer/signer.go internal/signer/dev.go internal/signer/dev_test.go internal/signer/piv_stub.go
docs/farm-events.md
"
rm -rf "$HERE/internal"
for f in $FILES; do
  mkdir -p "$HERE/$(dirname "$f")"
  git -C "$KISS" show "$REF:$f" > "$HERE/$f"
done
# Fuzz corpora the copied fuzz tests read, if present at that ref.
for d in internal/store/testdata internal/merkle/testdata; do
  if git -C "$KISS" cat-file -e "$REF:$d" 2>/dev/null; then
    git -C "$KISS" archive "$REF" "$d" | tar -x -C "$HERE"
  fi
done
# The demo program itself; kiss-protocol's examples/poultry-demo is its source of truth.
git -C "$KISS" show "$REF:examples/poultry-demo/main.go" > "$HERE/main.go"
sed -i 's#go run ./examples/poultry-demo#go run .#g' "$HERE/main.go"
# Point the copies at this module.
find "$HERE/internal" "$HERE/main.go" -name '*.go' -exec sed -i \
  's#github.com/bigblue-r4/kiss-protocol/internal/#github.com/bigblue-r4/harborlight-poultry-demo/internal/#g' {} +
cat > "$HERE/internal/SOURCE.md" <<MD
# Source of the code in internal/

Copied from [kiss-protocol](https://github.com/bigblue-r4/kiss-protocol) **$REF** (commit \`$SHA\`)
by \`scripts/sync-from-kiss.sh\`. Do not edit these files here: fix them in kiss-protocol, release,
and re-sync. Only the files the demo needs are copied; import paths are rewritten to this module.
MD
echo "synced from kiss-protocol $REF ($SHA)"
