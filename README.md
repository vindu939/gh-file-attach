# gh-file-attach

A lightweight [GitHub CLI](https://cli.github.com/) extension that replicates GitHub's "Attach files" feature from the terminal. Upload images, videos, documents, code files, archives, and more — get shareable URLs back.

Uses the official GitHub Releases API — no browser cookies, no hacks, just your existing `gh` auth.

## Prerequisites

1. **Install the [GitHub CLI](https://cli.github.com/)** (v2.0+):

   ```bash
   # macOS
   brew install gh

   # Linux
   sudo apt install gh   # Debian/Ubuntu
   sudo dnf install gh   # Fedora

   # Windows
   winget install --id GitHub.cli
   ```

2. **Authenticate with GitHub**:

   ```bash
   gh auth login
   ```

   This extension uses the OAuth token managed by `gh` — no separate token or environment variable needed. Your existing `gh auth login` session is all it requires.

   The token needs **`repo`** scope to create releases and upload assets. To verify:

   ```bash
   gh auth status
   ```

   If `repo` scope is missing:

   ```bash
   gh auth refresh -s repo
   ```

3. **Write access** to the target repository.

## Install

```bash
gh extension install vindu939/gh-file-attach
```

To upgrade:

```bash
gh extension upgrade file-attach
```

## Usage

### Upload a file and get its URL

```bash
$ gh file-attach screenshot.png
https://github.com/you/repo/releases/download/_attachments/screenshot-20260410-a1b2c3d4.png
```

### Upload multiple files

```bash
$ gh file-attach shot1.png report.pdf recording.mp4 debug.log
https://github.com/you/repo/releases/download/_attachments/shot1-20260410-a1b2c3d4.png
https://github.com/you/repo/releases/download/_attachments/report-20260410-b2c3d4e5.pdf
https://github.com/you/repo/releases/download/_attachments/recording-20260410-c3d4e5f6.mp4
https://github.com/you/repo/releases/download/_attachments/debug-20260410-d4e5f6a7.log
```

### Markdown output (`-m`)

Different file types get different markdown formatting:

```bash
$ gh file-attach -m screenshot.png recording.mp4 report.pdf data.csv app.zip
![screenshot.png](https://github.com/you/repo/releases/download/_attachments/screenshot-20260410-a1b2c3d4.png)
[▶ recording.mp4](https://github.com/you/repo/releases/download/_attachments/recording-20260410-b2c3d4e5.mp4)
[📄 report.pdf](https://github.com/you/repo/releases/download/_attachments/report-20260410-c3d4e5f6.pdf)
[📝 data.csv](https://github.com/you/repo/releases/download/_attachments/data-20260410-d4e5f6a7.csv)
[📦 app.zip](https://github.com/you/repo/releases/download/_attachments/app-20260410-e5f6a7b8.zip)
```

| File Type | Markdown Format | Renders on GitHub as |
|---|---|---|
| Images | `![label](url)` | Inline image |
| Videos | `[▶ label](url)` | Clickable link |
| Audio | `[🔊 label](url)` | Clickable link |
| Documents | `[📄 label](url)` | Clickable link |
| Code | `[📝 label](url)` | Clickable link |
| Archives | `[📦 label](url)` | Clickable link |
| Other | `[📎 label](url)` | Clickable link |

### Named files with labels

Use `"Label:path"` syntax for descriptive labels:

```bash
$ gh file-attach -m "Before fix:before.png" "After fix:after.png" "Demo:recording.mp4" "Q4 Report:report.pdf"
![Before fix](https://github.com/you/repo/releases/download/_attachments/before-20260410-a1b2c3d4.png)
![After fix](https://github.com/you/repo/releases/download/_attachments/after-20260410-b2c3d4e5.png)
[▶ Demo](https://github.com/you/repo/releases/download/_attachments/recording-20260410-c3d4e5f6.mp4)
[📄 Q4 Report](https://github.com/you/repo/releases/download/_attachments/report-20260410-d4e5f6a7.pdf)
```

If a file path contains a colon and exists on disk, it's treated as a plain path.

### Copy to clipboard (`-c`)

```bash
$ gh file-attach -m -c "Before fix:before.png" "After fix:after.png"
![Before fix](https://github.com/you/repo/releases/download/_attachments/before-20260410-a1b2c3d4.png)
![After fix](https://github.com/you/repo/releases/download/_attachments/after-20260410-b2c3d4e5.png)
Copied to clipboard!
```

### Target a specific repo (`-r`)

```bash
$ gh file-attach --repo myorg/myrepo screenshot.png
https://github.com/myorg/myrepo/releases/download/_attachments/screenshot-20260410-a1b2c3d4.png
```

### Custom release tag (`-t`)

```bash
$ gh file-attach --tag design-assets screenshot.png
https://github.com/you/repo/releases/download/design-assets/screenshot-20260410-a1b2c3d4.png
```

### Public release (`--public`)

By default, the release is a draft. Use `--public` so URLs are accessible in browsers and PR descriptions:

```bash
$ gh file-attach --public -m screenshot.png
![screenshot.png](https://github.com/you/repo/releases/download/_attachments/screenshot-20260410-a1b2c3d4.png)
```

**Important**: For private repos, always use `--public` if you want URLs to work in browser and render in PR descriptions.

### Version and help

```bash
$ gh file-attach --version
gh-file-attach 1.1.0

$ gh file-attach --help
# prints full usage information
```

## Supported Formats

| Category | Formats | Max Size |
|---|---|---|
| **Images** | PNG, JPG, JPEG, GIF, WebP, SVG, BMP, ICO, TIFF, AVIF | 50 MB |
| **Videos** | MP4, MOV, WebM, AVI, MKV | 200 MB |
| **Audio** | MP3, WAV, OGG, FLAC, AAC, M4A | 50 MB |
| **Documents** | PDF, DOCX, PPTX, XLSX, XLS, RTF, DOC, ODT, ODS, ODP, ODG, ODF | 25 MB |
| **Code** | PY, JS, TS, TSX, JSX, Java, C, CPP, CS, Go, RS, RB, SH, SQL, HTML, CSS, XML, YAML, Swift, Kotlin, Scala, Vue, Svelte, and more | 10 MB |
| **Archives** | ZIP, GZ, TGZ, TAR, BZ2, XZ, 7Z, RAR | 50 MB |
| **Text/Data** | TXT, MD, CSV, TSV, LOG, JSON, TOML, INI, CFG, CONF | 25 MB |
| **Other** | DEBUG, MSG, EML, DMP, PDB, CPUPROFILE | 25 MB |

## Managing Attachments

### List all uploads (`--list`)

```bash
$ gh file-attach --list
NAME                                                     SIZE  UPLOADED
----                                                     ----  --------
screenshot-20260410-091857-8438f428.png                  13 KB  2026-04-10
recording-20260410-091901-384e83de.mp4                    2 MB  2026-04-10
report-20260410-091905-973dc268.pdf                     302 B   2026-04-10

3 file(s), 2 MB total
```

### Storage stats (`--stats`)

See a breakdown of storage usage by file type:

```bash
$ gh file-attach --stats
Storage stats for '_attachments' in you/repo

  Images           4 files      120 KB
  Videos           2 files        8 MB
  Documents        1 files      302 B
  Code             3 files      276 B
  Archives         1 files      478 B
  ────────────────────────────────
  Total           11 files        8 MB

GitHub repo storage limits: 5 GB (warning at 1 GB)
Release assets count toward total repo size.
View in browser: https://github.com/you/repo/releases/tag/_attachments
```

### Cleanup old assets (`--cleanup`)

Delete by age — remove assets older than N days:

```bash
$ gh file-attach --cleanup 30d
Found 5 asset(s) older than 30 days (out of 18 total)
Proceed? (y/N) y
Deleted: old-screenshot-20260301-a1b2c3d4.png
Deleted: old-recording-20260305-b2c3d4e5.mp4
...
5 asset(s) deleted
```

Delete by count — keep only the latest N assets:

```bash
$ gh file-attach --cleanup 100
Deleting 20 oldest asset(s), keeping latest 100 (out of 120 total)
Proceed? (y/N) y
...
20 asset(s) deleted
```

Both strategies ask for confirmation before deleting.

## How It Works

1. Uses your `gh` auth token (via `gh release` commands) — no separate API keys or env vars
2. Creates an `_attachments` release in the target repo (once, on first use)
3. Uploads files as release assets with unique timestamped names
4. Returns permanent download URLs

**Where files are stored**: Files are uploaded as [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) assets under a release tagged `_attachments`. You can view, download, and manage them from the Releases page in your repo.

**Visibility**: For private repos, uploaded files are accessible to users with repo access. Use `--public` flag so URLs work in browsers and render in PR descriptions.

## Storage Limits

GitHub Release assets count toward your total repository size:

| Plan | Warning | Hard Limit |
|---|---|---|
| Free / Pro / Team | 1 GB | 5 GB |
| Enterprise | 5 GB | 100 GB |

Use `gh file-attach --stats` to monitor usage and `--cleanup` to remove old assets.

## Limits

- **Symlinks**: Rejected for security — only regular files are accepted
- **Size limits**: Vary by file type (see table above)
- **Unsupported types**: Executables (.exe, .dmg, .iso, .deb, .rpm) are rejected

## Comparison with GitHub's "Attach files"

| | GitHub Attach (Web UI) | gh-file-attach (CLI) |
|---|---|---|
| API/CLI support | No (cookies only) | Yes (`gh auth`) |
| Automation friendly | No | Yes |
| Max image size | 10 MB | 50 MB |
| Max video size | 100 MB (paid) / 10 MB (free) | 200 MB |
| Inline image rendering | Yes | Yes |
| Inline video rendering | Yes (native player) | No (download link) |
| Supports documents | Yes | Yes |
| Supports code files | Yes | Yes |
| Supports archives | Yes | Yes |
| Works in CI/CD | No | Yes |

## Using with Claude Code

Add the following to your `CLAUDE.md` (project-level) or `~/.claude/CLAUDE.md` (global):

```markdown
## File Attachments

When files need to be attached to PRs (screenshots, recordings, logs, documents),
use the gh file-attach CLI extension:

\`\`\`bash
# IMPORTANT: "gh file-attach" (three words), NOT "gh-file-attach" (hyphenated)
gh file-attach --public -m "Descriptive label:path/to/file"
\`\`\`

- Always ask for confirmation before uploading
- Always use --public flag so URLs work in browsers and PR descriptions
- Use descriptive labels (e.g. "Before fix", "After fix", "Error log")
- When creating PRs, append uploaded markdown to the PR description
- If gh file-attach is not installed, suggest: gh extension install vindu939/gh-file-attach
```

## Uninstall

```bash
gh extension remove file-attach
```

## License

MIT
