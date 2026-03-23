# OCR Flag Ideas

- **`-l language`** — Specify recognition language(s) (e.g., `en`, `de`, `zh`). Vision supports multiple languages and the default may not be ideal for non-English text.
- **`-f fast`** — Use `.fast` recognition level instead of `.accurate` for quicker but less precise results.
- **`-r revision`** — Select a specific Vision revision (e.g., revision 3 vs 2) if you need deterministic behavior across OS versions.
- **`-s separator`** — Custom line separator instead of `\n` (e.g., space to get all text on one line, or `\n\n` for paragraph spacing).
- **`-c confidence`** — Minimum confidence threshold — only output text observations above a given score (0.0–1.0).
- **`-n candidates`** — Output the top N candidates per observation instead of just the first, useful for debugging ambiguous text.
- **`-j`** — JSON output with text, confidence scores, and bounding box coordinates for each observation.
- **`-q`** — Quiet mode — suppress the stderr notice on overwrite.
