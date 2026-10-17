#!/usr/bin/env bash
set -euo pipefail

test "$(git rev-parse HEAD^{tree})" = cf73b76814f16351823906c97e25d8d0e7a8aef6
test "$(git rev-parse HEAD^)" = e8274fdb8bd591503a356a37ca7533c6e44c5908
git diff --exit-code

# Exact new regression first. No providers, external databases, or live opt-ins.
go test -p 1 ./pkg/index -run TestHNSWBatchDimensionContract -count=1 -v

# Same race/coverage flags as the repository CI, serialized to bound peak use.
go test -p 1 -v -race -timeout 25m -coverprofile="$RUNNER_TEMP/cortexdb-coverage.txt" -covermode=atomic ./...

# CI explicitly runs this large test without race instrumentation.
go test -p 1 -count=1 -run TestALargeUpsertDoesNotExhaustTheSQLPlaceholders ./pkg/cortexdb

go build -p 1 ./...
go list -m github.com/liliang-cn/cortexdb/v2
go test -p 1 ./pkg/eval -run TestLexicalRetrievalQuality -v

for cortex_example in examples/*/; do
  printf 'Checking %s\n' "$cortex_example"
  (cd "$cortex_example" && go build -p 1 -o /dev/null .)
done

# Literal version-consistency inputs from the current repository CI.
cortex_extract_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n1
}
cortex_go_version="$(sed -n 's/.*Version = "\([^"]*\)".*/\1/p' version.go)"
test -n "$cortex_go_version"
for cortex_manifest in \
  plugins/cortexdb/.claude-plugin/plugin.json \
  plugins/cortexdb/.codex-plugin/plugin.json \
  plugins/cortexdb-live/.claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  plugins/dsh-cortexdb-memory/package.json \
  plugins/obsidian-cortexdb/manifest.json \
  plugins/obsidian-cortexdb/package.json; do
  cortex_manifest_version="$(cortex_extract_version "$cortex_manifest")"
  printf '%s=%s\n' "$cortex_manifest" "$cortex_manifest_version"
  test "$cortex_manifest_version" = "$cortex_go_version"
done

git diff --exit-code
printf '\nAll requested Go gates passed for exact tree cf73b76814f16351823906c97e25d8d0e7a8aef6.\n'
