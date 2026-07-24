# Third-party components

This plugin does not vendor the upstream repository. `install.ps1` downloads the exact commit below into the user's local application-data directory and verifies its remote, checked-out SHA, and clean worktree.

## Origin-Pro-MCP

- Repository: <https://github.com/youngminsw/Origin-Pro-MCP>
- Commit: `1e9741af96c45bcac9e619c3ba32264bac6950e7`
- Package version at that commit: `0.3.1`
- Declared license: MIT
- The upstream repository contains a complete `LICENSE` file.

The public package mirror currently exposes an older release, so the installer uses the pinned Git commit rather than claiming that PyPI version 0.3.1 is available.

## Python dependencies

Python packages are downloaded during installation from the configured Tsinghua PyPI mirror and remain governed by their own licenses. Direct versions are recorded in `scripts/requirements.txt`.
