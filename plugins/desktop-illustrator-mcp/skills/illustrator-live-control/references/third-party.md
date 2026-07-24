# Third-party source and licensing

The plugin repository contains installer, launcher, safety policy, and documentation files. It does not vendor the upstream MCP source tree. `scripts/install.ps1` downloads the exact commit below into the user's local runtime and verifies the Git SHA.

## Illustrator MCP

- Source: <https://github.com/krVatsal/illustrator-mcp>
- Commit: `5040dde760688502f6006204ce9562c01c82c65c`
- Local source metadata: version `0.1.0`
- License caveat: the audited commit had no license file or license declaration, and GitHub did not detect a repository license.

Do not copy the upstream source tree into this plugin or publish a modified mirror without confirming the applicable license with the copyright holder. Preserve the upstream URL and commit hash, and re-audit licensing before each public release.
