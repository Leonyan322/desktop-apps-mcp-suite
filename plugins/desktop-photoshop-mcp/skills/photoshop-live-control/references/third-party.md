# Third-party source and licensing

The plugin repository contains installer, launcher, safety policy, an audited npm lockfile, and documentation. It does not vendor the upstream MCP source tree. `scripts/install.ps1` downloads the exact commit below into the user's local runtime and verifies the Git SHA.

## Photoshop MCP

- Source: <https://github.com/alisaitteke/photoshop-mcp>
- Commit: `152f8937be98b352c40ab5b525829a50d022f283`
- Local source metadata: version `1.4.0`, license field `MIT`
- Registry status at audit time: npm published versions stopped at `1.3.13`; `1.4.0` was not published
- License caveat: the audited commit had no `LICENSE`, `LICENCE`, or `COPYING` file, and GitHub did not detect a repository license. Package metadata alone declared MIT.

Do not copy the upstream source tree into this plugin or publish a modified mirror without confirming the applicable license with the copyright holder. Preserve the upstream URL and commit hash, and re-audit licensing before each public release.
