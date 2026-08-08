# Test ownership inventory

Phase 2 retired `Pscx.LegacyTests` and its custom in-process PowerShell host.
Every active test now has one owner based on the behavior it exercises.

## `Pscx.InternalTests`

The NUnit project owns deterministic implementation logic that does not need a
PowerShell session:

- date/time forwarding, arithmetic, and transition behavior;
- unit value objects and unit conversion;
- encoding-name resolution;
- binary parser positioning, strings, and bit primitives;
- Windows dynamic database type generation and row mapping, conditionally
  compiled only for `Full` builds.

The project must not depend on profiles, installed modules, user PATH, network
services, Active Directory, SQL Server, or desktop state.

## `Pscx.Package.Tests.ps1`

Pester owns behavior visible through the staged module:

- manifests, exports, aliases, providers, help, and README examples;
- default and optional-feature imports in clean child processes;
- parameter binding, pipelines, errors, `WhatIf`, and `Confirm`;
- Base64 acceleration, hashing, unit conversion, XML, YAML, and Windows links.

The old bitmap fixtures were removed because their commands are no longer part
of the exported module contract. External directory-service fixtures were
removed because they depended on unavailable lab infrastructure; the packaged
provider contract remains covered without network or AD dependencies.

Archive safety will receive focused ownership when `Pscx.Archive` is extracted
in Phase 5. No standalone archive-safety primitive is retained in the core
module today.
