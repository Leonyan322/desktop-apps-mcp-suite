# Third-party sources and licensing

The plugin repository contains installer, launcher, safety policy, and documentation files. It does not vendor the two upstream MCP source trees. `scripts/install.ps1` downloads the exact commits listed below into the user's local runtime directory and verifies each resulting Git SHA.

## Photoshop MCP

- Source: <https://github.com/alisaitteke/photoshop-mcp>
- Commit: `152f8937be98b352c40ab5b525829a50d022f283`
- Local source metadata: version `1.4.0`, license field `MIT`
- Registry status at audit time: npm published versions stopped at `1.3.13`; `1.4.0` was not published
- License caveat: the audited Git commit had no `LICENSE`, `LICENCE`, or `COPYING` file, and GitHub did not detect a repository license. Package metadata alone declared MIT.

## Illustrator MCP

- Source: <https://github.com/krVatsal/illustrator-mcp>
- Commit: `5040dde760688502f6006204ce9562c01c82c65c`
- Local source metadata: version `0.1.0`
- License caveat: the audited commit had no license file or license declaration, and GitHub did not detect a repository license.

## Redistribution rule

Do not copy either upstream source tree into this plugin or publish a modified mirror without confirming the applicable license with the copyright holder. Downloading a public repository during installation does not resolve downstream use or redistribution rights. Preserve the upstream URLs and commit hashes in derivative installation instructions, and re-audit licensing before each public release.
