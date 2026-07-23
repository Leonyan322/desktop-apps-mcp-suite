# Third-party components

This plugin does not vendor either upstream repository. `install.ps1` downloads the exact commits below into the user's local application-data directory and verifies each checked-out SHA.

## Origin-Pro-MCP

- Repository: <https://github.com/youngminsw/Origin-Pro-MCP>
- Commit: `1e9741af96c45bcac9e619c3ba32264bac6950e7`
- Package version at that commit: `0.3.1`
- Declared license: MIT
- The upstream repository contains a complete `LICENSE` file.

The public package mirror currently exposes an older release, so the installer uses the pinned Git commit rather than claiming that PyPI version 0.3.1 is available.

## HFSS_McpServer

- Repository: <https://github.com/leonardwy/HFSS_McpServer>
- Commit: `950c06dc8dae360ebe701bf00ff51542ac08c2b2`
- README license label: MIT
- License caveat: the audited upstream commit has no `LICENSE` file and GitHub does not detect a repository license.

The README label alone is not a complete license notice. Do not vendor, republish, or claim complete redistribution rights for the upstream HFSS source without clarification from its author. This plugin distributes only installation logic and a compatibility patch; the installer retrieves the upstream checkout directly. The repository-level MIT grant covers the suite's original scripts and configuration, not upstream context retained in `hfss-2023r1.patch`.

## Python dependencies

Python packages are downloaded during installation from the configured Tsinghua PyPI mirror and remain governed by their own licenses. Direct versions are recorded in `scripts/requirements-origin.txt` and `scripts/requirements-hfss.txt`.

## Safety overlay

The HFSS patch is tied to the exact upstream commit. It fixes MCP stdio isolation, pins AEDT 2023 R1, changes stop to detach-only, and hard-disables restart and analysis. Do not apply it to a different upstream revision without reviewing and retesting every hunk.
