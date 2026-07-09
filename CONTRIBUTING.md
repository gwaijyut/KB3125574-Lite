# Contributing

## Scope
This project computes which KB3125574 payloads remain terminal (never superseded)
on a fully-patched baseline, maps them to signed sub-packages in a layered manifest,
and installs them from the KB source. Contributions that improve correctness,
reproducibility, or safety are welcome.

## Ground rules
- Scripts and tools must be pure ASCII (no CJK, no BOM, no em-dash) for portability.
- Do not commit the KB3125574 source, .msu/.cab/.wim files, or machine-specific
  paths and logs.
- Do not fabricate package identities. Every claim about a payload or package must
  be reproducible from the tools in `tools/`.
- Manifest changes: bump the semantic version. Terminal-set recomputation against a
  new patch baseline: bump the build number (e.g. 20260201.full2). Add a CHANGELOG
  entry using this milestone as the diff origin.

## Reproducing the analysis
See `tools/` (parse -> find-terminal -> resolve-owning -> optimize-min-ride) and
`docs/VALIDATION.md`. Results must reproduce the terminal set before a manifest
change is accepted.
