#!/usr/bin/env bash
# Test suite for gh-file-attach
# Run: ./test.sh
# Run upload tests against a real repo: REPO=owner/repo ./test.sh

set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/gh-file-attach"
PASS=0
FAIL=0
SKIP=0
TMPDIR_BASE=""

# --- Test Helpers -----------------------------------------------------------

setup() {
  TMPDIR_BASE=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_BASE"
}

pass() {
  (( PASS++ )) || true
  echo "  ✓ $1"
}

fail() {
  (( FAIL++ )) || true
  echo "  ✗ $1"
  if [[ -n "${2:-}" ]]; then
    echo "    Expected: $2"
  fi
  if [[ -n "${3:-}" ]]; then
    echo "    Got:      $3"
  fi
}

skip() {
  (( SKIP++ )) || true
  echo "  ○ $1 (skipped)"
}

# Run a command, capture stdout/stderr/exit separately
run() {
  set +e
  "$@" >"${TMPDIR_BASE}/stdout" 2>"${TMPDIR_BASE}/stderr_out"
  echo "$?" > "${TMPDIR_BASE}/exit_code"
  set -e
}

# Run via bash -c for piping tests
run_bash() {
  set +e
  bash -c "$1" >"${TMPDIR_BASE}/stdout" 2>"${TMPDIR_BASE}/stderr_out"
  echo "$?" > "${TMPDIR_BASE}/exit_code"
  set -e
}

get_stdout() { cat "${TMPDIR_BASE}/stdout"; }
get_stderr() { cat "${TMPDIR_BASE}/stderr_out"; }
get_exit()   { cat "${TMPDIR_BASE}/exit_code"; }

assert_exit() {
  [[ "$(get_exit)" == "$1" ]]
}

assert_stdout_contains() {
  get_stdout | grep -qF "$1" 2>/dev/null
}

assert_stdout_matches() {
  get_stdout | grep -q "$1" 2>/dev/null
}

assert_stderr_contains() {
  get_stderr | grep -qF "$1" 2>/dev/null
}

assert_stderr_matches() {
  get_stderr | grep -q "$1" 2>/dev/null
}

# Create a test file
make_file() {
  local name="$1"
  local content="${2:-test content}"
  echo "$content" > "${TMPDIR_BASE}/${name}"
  echo "${TMPDIR_BASE}/${name}"
}

# --- Test Groups ------------------------------------------------------------

test_version() {
  echo ""
  echo "=== Version & Help ==="

  run "$SCRIPT" --version
  if assert_exit 0 && assert_stdout_contains "gh-file-attach"; then
    pass "--version prints version"
  else
    fail "--version prints version" "exit 0 + version string" "exit $(get_exit): $(get_stdout)"
  fi

  run "$SCRIPT" --help
  if assert_exit 0 && assert_stdout_contains "USAGE"; then
    pass "--help prints usage"
  else
    fail "--help prints usage"
  fi
}

test_no_args() {
  echo ""
  echo "=== No Arguments ==="

  run "$SCRIPT"
  if assert_exit 1 && assert_stderr_contains "No files specified"; then
    pass "No args shows error"
  else
    fail "No args shows error" "exit 1 + 'No files specified'" "exit $(get_exit): $(get_stderr)"
  fi
}

test_repo_validation() {
  echo ""
  echo "=== Repo Validation ==="

  # Valid format — should NOT produce "Invalid repo format"
  run "$SCRIPT" --repo "owner/repo" nonexistent.png
  if ! assert_stderr_contains "Invalid repo format"; then
    pass "--repo owner/repo accepted"
  else
    fail "--repo owner/repo should be accepted"
  fi

  # Spaces in repo
  run "$SCRIPT" --repo "owner/repo --json foo" test.png
  if assert_exit 1 && assert_stderr_contains "Invalid repo format"; then
    pass "--repo with embedded flags rejected"
  else
    fail "--repo with embedded flags rejected" "Invalid repo format" "$(get_stderr)"
  fi

  # No slash
  run "$SCRIPT" --repo "justrepo" test.png
  if assert_exit 1 && assert_stderr_contains "Invalid repo format"; then
    pass "--repo without slash rejected"
  else
    fail "--repo without slash rejected" "Invalid repo format" "$(get_stderr)"
  fi
}

test_tag_validation() {
  echo ""
  echo "=== Tag Validation ==="

  # Valid — should NOT produce "Invalid tag format"
  run "$SCRIPT" --tag "_attachments" --repo "owner/repo" nonexistent.png
  if ! assert_stderr_contains "Invalid tag format"; then
    pass "--tag _attachments accepted"
  else
    fail "--tag _attachments should be accepted"
  fi

  run "$SCRIPT" --tag "v1.0/release-2" --repo "owner/repo" nonexistent.png
  if ! assert_stderr_contains "Invalid tag format"; then
    pass "--tag with slashes/dots/hyphens accepted"
  else
    fail "--tag with slashes/dots/hyphens should be accepted"
  fi

  # Spaces
  run "$SCRIPT" --tag "my tag" --repo "owner/repo" test.png
  if assert_exit 1 && assert_stderr_contains "Invalid tag format"; then
    pass "--tag with spaces rejected"
  else
    fail "--tag with spaces rejected" "Invalid tag format" "$(get_stderr)"
  fi

  # Embedded flags
  run "$SCRIPT" --tag "v1 --notes-file /etc/passwd" --repo "owner/repo" test.png
  if assert_exit 1 && assert_stderr_contains "Invalid tag format"; then
    pass "--tag with embedded flags rejected"
  else
    fail "--tag with embedded flags rejected" "Invalid tag format" "$(get_stderr)"
  fi
}

test_file_validation() {
  echo ""
  echo "=== File Validation ==="

  # Unsupported type (test before anything that needs gh, since classify is local)
  local f
  f=$(make_file "test.exe")
  run "$SCRIPT" --repo "owner/repo" "$f"
  if assert_exit 1 && assert_stderr_contains "Unsupported file type"; then
    pass "Unsupported .exe rejected"
  else
    fail "Unsupported .exe rejected" "Unsupported file type" "$(get_stderr)"
  fi

  f=$(make_file "test.dmg")
  run "$SCRIPT" --repo "owner/repo" "$f"
  if assert_exit 1 && assert_stderr_contains "Unsupported file type"; then
    pass "Unsupported .dmg rejected"
  else
    fail "Unsupported .dmg rejected" "Unsupported file type" "$(get_stderr)"
  fi

  # Symlink
  local real
  real=$(make_file "real.png")
  ln -sf "$real" "${TMPDIR_BASE}/link.png"
  run "$SCRIPT" --repo "owner/repo" "${TMPDIR_BASE}/link.png"
  if assert_exit 1 && assert_stderr_contains "symlink"; then
    pass "Symlink rejected"
  else
    fail "Symlink rejected" "symlink error" "$(get_stderr)"
  fi

  # Missing file
  run "$SCRIPT" --repo "owner/repo" "${TMPDIR_BASE}/nonexistent.png"
  if assert_exit 1 && assert_stderr_contains "File not found"; then
    pass "Missing file shows error"
  else
    fail "Missing file shows error" "File not found" "$(get_stderr)"
  fi
}

test_file_type_classification() {
  echo ""
  echo "=== File Type Classification ==="

  # Extract classify_file as standalone function
  local classify_fn
  classify_fn=$(sed -n '/^classify_file()/,/^}/p' "$SCRIPT")

  test_classify() {
    local ext="$1" expected="$2"
    local result
    result=$(bash -c "$classify_fn"$'\n'"classify_file '$ext'")
    if [[ "$result" == "$expected" ]]; then
      pass ".$ext → $expected"
    else
      fail ".$ext → $expected" "$expected" "$result"
    fi
  }

  # Images
  test_classify "png" "image"
  test_classify "jpg" "image"
  test_classify "gif" "image"
  test_classify "svg" "image"
  test_classify "webp" "image"
  test_classify "avif" "image"
  test_classify "bmp" "image"
  test_classify "tiff" "image"

  # Videos
  test_classify "mp4" "video"
  test_classify "mov" "video"
  test_classify "webm" "video"
  test_classify "mkv" "video"
  test_classify "avi" "video"

  # Audio
  test_classify "mp3" "audio"
  test_classify "wav" "audio"
  test_classify "flac" "audio"
  test_classify "ogg" "audio"

  # Documents
  test_classify "pdf" "document"
  test_classify "docx" "document"
  test_classify "xlsx" "document"
  test_classify "pptx" "document"

  # Code (yaml/yml/xml are classified as code)
  test_classify "py" "code"
  test_classify "js" "code"
  test_classify "ts" "code"
  test_classify "go" "code"
  test_classify "rs" "code"
  test_classify "java" "code"
  test_classify "yaml" "code"
  test_classify "yml" "code"
  test_classify "xml" "code"
  test_classify "html" "code"
  test_classify "css" "code"
  test_classify "sh" "code"

  # Archives
  test_classify "zip" "archive"
  test_classify "tar" "archive"
  test_classify "gz" "archive"
  test_classify "7z" "archive"

  # Text
  test_classify "txt" "text"
  test_classify "csv" "text"
  test_classify "json" "text"
  test_classify "log" "text"
  test_classify "md" "text"
  test_classify "toml" "text"
  test_classify "ini" "text"

  # Other
  test_classify "debug" "other"
  test_classify "eml" "other"
  test_classify "dmp" "other"

  # Unsupported
  test_classify "exe" "unsupported"
  test_classify "dmg" "unsupported"
  test_classify "iso" "unsupported"
  test_classify "random" "unsupported"
}

test_file_count_limit() {
  echo ""
  echo "=== File Count Limit ==="

  # Create 51 fake file paths (they won't exist, but count check happens first)
  local args=""
  for i in $(seq 1 51); do
    args+="${TMPDIR_BASE}/fake${i}.png "
  done
  run_bash "'$SCRIPT' --repo 'owner/repo' $args"
  if assert_exit 1 && assert_stderr_contains "Too many files"; then
    pass "51 files rejected (max 50)"
  else
    fail "51 files rejected (max 50)" "Too many files" "$(get_stderr)"
  fi
}

test_cleanup_validation() {
  echo ""
  echo "=== Cleanup Validation ==="

  # Piped stdin rejected
  run_bash "echo 'y' | '$SCRIPT' --repo owner/repo --cleanup 5"
  if assert_exit 1 && assert_stderr_contains "interactive confirmation"; then
    pass "Piped stdin rejected for cleanup"
  else
    fail "Piped stdin rejected for cleanup" "interactive confirmation" "$(get_stderr)"
  fi

  # Invalid cleanup arg
  run_bash "echo 'n' | '$SCRIPT' --repo 'owner/repo' --cleanup 'abc'"
  if assert_exit 1; then
    pass "--cleanup abc rejected"
  else
    fail "--cleanup abc rejected" "exit 1" "exit $(get_exit)"
  fi
}

test_label_parsing() {
  echo ""
  echo "=== Label Parsing ==="

  # Create a real file and test label parsing indirectly via markdown output format
  # We can't fully test without upload, but we can test the arg parsing logic
  local f
  f=$(make_file "labeled.png")

  # File that exists — used as plain path even if arg contains colon-like pattern
  run "$SCRIPT" --repo "owner/repo" "$f"
  # Should fail at gh release (not file-not-found), meaning the file was accepted
  if ! assert_stderr_contains "File not found"; then
    pass "Existing file path accepted"
  else
    fail "Existing file path accepted" "no 'File not found'" "$(get_stderr)"
  fi

  # Label:nonexistent — should parse as label + path, fail on file not found
  run "$SCRIPT" --repo "owner/repo" "My Label:${TMPDIR_BASE}/nope.png"
  if assert_exit 1 && assert_stderr_contains "File not found"; then
    pass "Label:path splits correctly"
  else
    fail "Label:path splits correctly" "File not found for nope.png" "$(get_stderr)"
  fi
}

test_markdown_formatting() {
  echo ""
  echo "=== Markdown Formatting ==="

  local funcs
  funcs=$(sed -n '/^markdown_icon()/,/^}/p' "$SCRIPT")
  funcs+=$'\n'
  funcs+=$(sed -n '/^format_markdown()/,/^}/p' "$SCRIPT")

  test_fmt() {
    local category="$1" expected="$2"
    local result
    result=$(bash -c "$funcs"$'\n'"format_markdown 'https://example.com/file' 'Test Label' '$category'")
    if echo "$result" | grep -qF "$expected"; then
      pass "$category → '$expected'"
    else
      fail "$category markdown" "contains '$expected'" "$result"
    fi
  }

  test_fmt "image" "![Test Label]"
  test_fmt "video" "[▶ Test Label]"
  test_fmt "audio" "[🔊 Test Label]"
  test_fmt "document" "[📄 Test Label]"
  test_fmt "code" "[📝 Test Label]"
  test_fmt "archive" "[📦 Test Label]"
  test_fmt "text" "[📝 Test Label]"
  test_fmt "other" "[📎 Test Label]"

  # All non-image should contain URL
  local result
  result=$(bash -c "$funcs"$'\n'"format_markdown 'https://example.com/file.mp4' 'Vid' 'video'")
  if echo "$result" | grep -qF "https://example.com/file.mp4"; then
    pass "Markdown contains URL"
  else
    fail "Markdown contains URL" "URL in output" "$result"
  fi
}

test_unique_name() {
  echo ""
  echo "=== Unique Name Generation ==="

  local func
  func=$(sed -n '/^unique_name()/,/^}/p' "$SCRIPT")

  test_uname() {
    local filename="$1" pattern="$2" desc="$3"
    mkdir -p "${TMPDIR_BASE}/utest"
    touch "${TMPDIR_BASE}/utest/${filename}"
    local result
    result=$(bash -c "$func"$'\n'"unique_name '${TMPDIR_BASE}/utest/${filename}'")
    if echo "$result" | grep -qE "$pattern"; then
      pass "$desc"
    else
      fail "$desc" "matches /$pattern/" "$result"
    fi
  }

  test_uname "screenshot.png" "^screenshot-[0-9]{8}-[0-9]{6}-[a-f0-9]+\.png$" "Normal file: timestamped with .png"
  test_uname "report.pdf" "\.pdf$" "PDF keeps extension"
  test_uname "data.tar.gz" "\.gz$" "Double extension keeps last part"
  test_uname "hello.py" "^hello-.*\.py$" "Python file preserves name and ext"
}

test_size_limits() {
  echo ""
  echo "=== Size Limits ==="

  local func vars
  vars=$(grep '^MAX_.*_SIZE=' "$SCRIPT")
  func=$(sed -n '/^max_size_for()/,/^}/p' "$SCRIPT")

  test_limit() {
    local category="$1" expected_mb="$2"
    local expected=$(( expected_mb * 1024 * 1024 ))
    local result
    result=$(bash -c "$vars"$'\n'"$func"$'\n'"max_size_for '$category'")
    if [[ "$result" == "$expected" ]]; then
      pass "$category → ${expected_mb}MB"
    else
      fail "$category size limit" "$expected" "$result"
    fi
  }

  test_limit "image" 50
  test_limit "video" 200
  test_limit "audio" 50
  test_limit "document" 25
  test_limit "code" 10
  test_limit "archive" 50
  test_limit "text" 25
  test_limit "other" 25
}

# --- Upload Tests (require real repo) ----------------------------------------

test_upload() {
  echo ""
  echo "=== Upload Tests (live) ==="

  local repo="${REPO:-}"
  if [[ -z "$repo" ]]; then
    skip "Set REPO=owner/repo to run live upload tests"
    return
  fi

  # Upload image — plain URL
  local img
  img=$(make_file "test-upload.png" "fake png data")
  run "$SCRIPT" --repo "$repo" --public "$img"
  if assert_exit 0 && assert_stdout_contains "releases/download"; then
    pass "Image upload returns URL"
  else
    fail "Image upload" "URL in stdout" "exit $(get_exit): $(get_stderr)"
  fi

  # Upload with markdown + label
  run "$SCRIPT" --repo "$repo" --public -m "Test Image:$img"
  if assert_exit 0 && assert_stdout_contains "![Test Image]"; then
    pass "Markdown output with label"
  else
    fail "Markdown with label" "![Test Image](url)" "$(get_stdout)"
  fi

  # Upload code file — should get 📝
  local pyfile
  pyfile=$(make_file "hello.py" "print('test')")
  run "$SCRIPT" --repo "$repo" --public -m "$pyfile"
  if assert_exit 0 && assert_stdout_contains "📝"; then
    pass "Code file gets 📝 icon"
  else
    fail "Code 📝 icon" "📝 in output" "$(get_stdout)"
  fi

  # Multi-file upload
  local txt
  txt=$(make_file "notes.txt" "some notes")
  run "$SCRIPT" --repo "$repo" --public -m "$img" "$pyfile" "$txt"
  if assert_exit 0 && assert_stderr_contains "3 file(s) uploaded"; then
    pass "Multi-file upload summary"
  else
    fail "Multi-file summary" "3 file(s) uploaded" "$(get_stderr)"
  fi

  # List
  run "$SCRIPT" --repo "$repo" --list
  if assert_exit 0 && assert_stdout_contains "NAME"; then
    pass "--list shows header"
  else
    fail "--list" "NAME header" "$(get_stdout)"
  fi

  # Stats
  run "$SCRIPT" --repo "$repo" --stats
  if assert_exit 0 && assert_stdout_contains "Total"; then
    pass "--stats shows total"
  else
    fail "--stats" "Total line" "$(get_stdout)"
  fi
}

# --- Run All Tests ----------------------------------------------------------

main() {
  echo "gh-file-attach test suite"
  echo "========================="

  setup
  trap teardown EXIT

  test_version
  test_no_args
  test_repo_validation
  test_tag_validation
  test_file_validation
  test_file_type_classification
  test_file_count_limit
  test_cleanup_validation
  test_label_parsing
  test_markdown_formatting
  test_unique_name
  test_size_limits
  test_upload

  echo ""
  echo "========================="
  echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
