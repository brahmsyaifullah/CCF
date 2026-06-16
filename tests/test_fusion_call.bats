#!/usr/bin/env bats
# CCF dispatcher tests — cover the pre-network error paths (no API calls, fully offline).

setup() {
  CCF="$BATS_TEST_DIRNAME/../bin/fusion-call"
  export CLAUDE_HOME="$BATS_TEST_TMPDIR/claude"
  mkdir -p "$CLAUDE_HOME/fusion"
  cp "$BATS_TEST_DIRNAME/fixtures/providers.json" "$CLAUDE_HOME/fusion/providers.json"
  cp "$BATS_TEST_DIRNAME/fixtures/panel.json"     "$CLAUDE_HOME/fusion/panel.json"
  : > "$CLAUDE_HOME/fusion/secrets.env"
}

@test "unknown panelist is rejected" {
  run "$CCF" does-not-exist "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown panelist"* ]]
}

@test "unknown provider (ad-hoc) is rejected" {
  run "$CCF" --provider nope --model m "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown provider"* ]]
}

@test "empty prompt is rejected" {
  run bash -c ': | "'"$CCF"'" guardp'
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty prompt"* ]]
}

@test "missing key is reported before any network call" {
  run "$CCF" nokeyp "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing key"* ]]
}

@test "context guard rejects an oversize prompt before upload" {
  big=$(printf 'x%.0s' $(seq 1 4000))   # 4000 chars * 1.0 tok/char > window
  run "$CCF" guardp "$big"
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceeds"* ]]
}

@test "a prompt within the window passes the guard (reaches network, not a guard error)" {
  run "$CCF" guardp "small prompt"
  [[ "$output" != *"exceeds"* ]]   # guard passed; may then fail on the dummy endpoint, that's fine
}

@test "shipped JSON configs are valid" {
  for f in catalog providers.dist panel.dist; do
    run jq -e . "$BATS_TEST_DIRNAME/../config/$f.json"
    [ "$status" -eq 0 ]
  done
}

@test "all built-in presets are valid and reference a panel" {
  for p in "$BATS_TEST_DIRNAME/../config/presets/"*.json; do
    run jq -e '.panel | length > 0' "$p"
    [ "$status" -eq 0 ]
  done
}
