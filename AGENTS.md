# AGENTS.md

## Purpose and scope

This file defines how human maintainers and AI coding agents collaborate in this repository. It applies to the entire repository unless a more specific `AGENTS.md` in a subdirectory overrides part of it.

PSCX is a PowerShell module with compiled C# cmdlets, PowerShell functions, platform-specific components, generated help, bundled dependencies, and release tooling. Changes can affect command compatibility, user sessions, multiple operating systems, and published packages, so agents should favor clear communication, narrow scope, and verifiable results.

## Maintainer-agent relationship

The maintainer owns product direction, priorities, compatibility policy, public API decisions, release timing, and final acceptance.

Agents are expected to act as collaborative engineering partners:

- inspect the repository and gather evidence before recommending changes;
- explain important assumptions, risks, and tradeoffs;
- keep the maintainer informed during material work;
- make requested changes carefully and in a reviewable form;
- validate changes in proportion to their risk;
- distinguish confirmed behavior from inference;
- surface disagreements or concerns with concrete technical reasoning;
- stop and request direction when a decision would materially expand or redirect the requested work.

Do not silently make product, architecture, compatibility, dependency, packaging, or release-policy decisions on the maintainer's behalf.

## Approval and commit policy

The maintainer wants to review changes before they are committed.

Agents must not create a Git commit until the maintainer has reviewed the completed worktree changes and explicitly approved the commit. Before requesting approval, provide:

- a concise summary of what changed and why;
- the files changed;
- tests and validation performed, including failures or tests that could not run;
- known limitations, follow-up work, and any unrelated worktree changes;
- the proposed commit message.

An initial request to implement a change does not by itself authorize committing it. Even if a task initially mentions committing, pause after implementation for review unless the maintainer explicitly waives the review step for that specific task.

Without explicit approval, do not:

- stage files;
- commit or amend a commit;
- rebase, merge, cherry-pick, or reset branches;
- create or move tags;
- push branches or tags;
- open, update, approve, or merge pull requests;
- publish modules, packages, artifacts, or releases.

Read-only Git inspection is allowed when relevant. After approval, commit only the reviewed changes and use the approved or subsequently agreed commit message. If the worktree changes after approval, summarize the new difference and obtain approval again before committing.

## Communication expectations

For a material task:

1. State the intended outcome and the repository areas likely to be affected.
2. Report significant findings as they are discovered.
3. Call out choices that affect the public API, compatibility, dependencies, build/release behavior, or package contents.
4. At completion, lead with the outcome and provide validation evidence.

Ask before proceeding when:

- requirements have multiple materially different interpretations;
- a public command could be removed, renamed, or behaviorally changed;
- a new runtime or redistributed dependency is proposed;
- a change would broaden supported or unsupported platforms;
- credentials, signing material, publishing permissions, or external coordination are needed;
- existing uncommitted work overlaps the requested change and cannot be preserved safely;
- destructive or difficult-to-reverse action is required.

Routine read-only inspection and normal implementation details within an approved task do not require repeated permission.

## Repository orientation

Before making material changes:

- read `README.md` for the current project description;
- read `PSCX_MODERNIZATION_PLAN.md` when the task relates to modernization, testing, help, packaging, CI, compatibility, or the public command surface;
- inspect the current branch and `git status`;
- look for more specific instructions in nested `AGENTS.md` files;
- identify generated files and their source before editing them;
- preserve unrelated maintainer changes in a dirty worktree.

Treat the modernization plan as direction, not blanket authorization to implement every listed item. Work only on the task currently approved by the maintainer.

## Shell and command execution

- Use PowerShell 7 (`pwsh`) as the shell for repository and internal agent commands.
- Do not fall back to `cmd.exe` or Windows PowerShell when `pwsh` cannot be found, launched, or accessed.
- If a `pwsh` command fails because of sandbox access or executable resolution, retry the same command with `pwsh` outside the sandbox after obtaining any required approval.
- If `pwsh` still cannot run outside the sandbox, stop and report the executable path and exact error so the maintainer can troubleshoot the environment. Do not continue through a different shell.

## Change discipline

- Keep changes focused on the requested outcome.
- Avoid opportunistic rewrites and unrelated formatting churn.
- Prefer small, reviewable diffs over broad mechanical changes.
- Do not edit generated output when its authoritative source can be changed instead.
- Do not commit build output, temporary files, test results, credentials, signing material, or local IDE state.
- Preserve existing behavior unless the requested task intentionally changes it.
- Document intentional breaking changes and provide migration guidance.
- Do not suppress warnings or tests merely to make CI pass; resolve the cause or document and obtain approval for a narrowly scoped exception.
- Do not add fallback behavior that hides missing dependencies, unsupported platforms, or corrupted state.
- In commit messages include the GitHub issue number the commit relates to, provided there is an issue filed. Ask the user to provide an optional issue number if one cannot be inferred from the plan.

## PSCX architecture and API guidance

- Keep cross-platform functionality in the cross-platform module and Windows-specific functionality in the Windows module.
- Mark platform-specific compiled APIs consistently and test their platform behavior.
- Avoid loading optional or platform-specific dependencies during a default core import.
- Treat manifests, exported commands, aliases, help, type data, and format data as parts of the public contract.
- Prefer explicit exports. Do not introduce new wildcard exports.
- Do not create or replace global aliases during default module import.
- Use approved PowerShell verbs and the repository's noun/verb constants for compiled cmdlets.
- For mutating commands, use `ShouldProcess` where appropriate.
- Prefer structured output over preformatted text unless formatting is the command's purpose.
- Follow normal PowerShell pipeline, `-Path`, `-LiteralPath`, wildcard, error-record, and common-parameter conventions.
- Place command descriptions and documentation in the repository's current authoritative help source. When the PlatyPS migration is implemented, Markdown becomes the source and generated MAML remains build output.
- Add or update public help and examples whenever public behavior changes.

Do not hard-code a new PowerShell, .NET, module, assembly, or package version in another location. Follow the repository's authoritative version source once established. Until version centralization is implemented, identify all currently synchronized locations and update them consistently through the existing tooling.

## Testing and validation

Tests should provide evidence about the shipped PowerShell experience.

- Exercise public commands through the packaged module when practical.
- Use Pester for module import, manifests, exports, command behavior, parameter binding, pipelines, errors, aliases, help, packaging, and OS integration.
- Use managed unit tests only for pure implementation logic that is better isolated from a PowerShell session.
- Avoid duplicating the same behavior across Pester and managed tests without a specific regression reason.
- Add a regression test for every defect fixed when practical.
- Run the narrowest relevant tests during development and the broader applicable suite before handoff.
- Validate on every affected operating system when infrastructure permits.
- Report skipped tests and environmental limitations explicitly.
- Never claim a test passed if it did not run to completion.

Use the repository's unified build/test entry point once it exists. Until then, use the current supported build and test commands and document any known limitations, including build steps that depend on solution-level properties.

## Dependencies and redistributed binaries

Before adding or updating a dependency:

- explain why built-in PowerShell or .NET functionality is insufficient;
- assess platform and runtime compatibility;
- review transitive dependencies and known vulnerabilities;
- identify license, source, version, checksum, and redistribution implications;
- consider package size and module import cost;
- obtain maintainer approval for new runtime or redistributed dependencies.

Do not download, replace, or publish third-party native binaries without explicit approval.

## Documentation and generated help

- Keep user documentation accurate for the currently shipped behavior.
- Avoid manually maintaining duplicate command inventories when they can be generated or validated.
- Preserve useful examples and detailed help during documentation migrations.
- Validate that every exported command has usable installed help.
- Treat generated MAML, command catalogs, and release packages as artifacts derived from authoritative source files.

## GitHub and external actions

Creating issues, milestones, project items, pull requests, releases, comments, or other remote state requires explicit maintainer authorization.

When proposing GitHub issues:

- make each issue outcome-oriented and independently actionable;
- include scope, non-goals, acceptance criteria, dependencies, and the relevant roadmap link;
- avoid creating the entire long-term backlog before near-term decisions are settled;
- use milestones and labels consistently once the maintainer approves their taxonomy.

## Security and destructive actions

- Never expose credentials, tokens, certificates, private keys, or sensitive environment values.
- Do not weaken signing, execution-policy, package-validation, or dependency-audit behavior without explicit approval.
- Resolve exact paths and targets before deleting or moving files.
- Prefer recoverable operations and narrow targets.
- Do not discard maintainer changes.
- Do not use destructive Git commands unless explicitly requested and approved for the exact target.

If a suspected security issue is found, report it privately to the maintainer with enough detail to assess impact before adding public discussion or exploit-oriented tests.

## Definition of done

A change is ready for maintainer review when:

- the requested behavior is implemented;
- the diff is focused and understandable;
- applicable tests and validation have run;
- documentation and help are updated where necessary;
- platform, compatibility, dependency, and packaging effects are stated;
- no unrelated files are staged or modified by the agent;
- remaining limitations and follow-up work are explicit;
- no commit has been created without approval.
