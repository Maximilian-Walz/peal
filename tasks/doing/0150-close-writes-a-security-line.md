---
milestone: m3
plan: required
---

# 0150 — Close writes a Security: line in the pull request body when the project keeps a threat model

## Intent

Belfry shows a pull request body's `Security:` line on the merge item: the boundary the change touches and how, or `none`, highlighted when it is not `none`. It reads one line, the last `Security:` line outside code blocks, not a section (Belfry's docs/contract.md, "Pull request bodies"). `/peal:close` builds the body from `--summary`, `--decisions`, `--human-steps` and the project's `pr.sections` (`peal_close_body` in `plugin/lib/close.sh`), but has no way to write that line. So a Peal pull request never shows the human which boundary it touches, even in a project such as this one, whose `docs/security.md` names its boundaries, and whose review tier in Belfry (0149) decides merges by the paths at those boundaries.

Give close a `Security:` line: the session names the boundary its change touches and how, or `none`, and close writes it as the body's last line before the commit list (or wherever Belfry still finds it as the last such line). Where the project keeps a threat model, close asks for it and refuses to finish without one; elsewhere it stays optional.

## Scope

## Done when

## Raw

> /peal:close writes Summary, Decisions and Human steps but no Security: line, which Belfry highlights on the merge item. The fix is a Peal task, not a pr.sections entry, since Belfry reads a line, not a section.

## Notes

- Found while reviewing this repository's own `.belfry.yml` (0149).
- Open for the planner: how close knows a project keeps a threat model (a config setting, say `pr.security: required`, or the presence of a security document the config names), and whether the reviewer subagent checks the line against the diff.
- Belfry is also adding a `## Notes` section for everything that is not a step, after a "None" in Human steps held merges (belfry#577). If close grows a `--notes`, keep it in step with that.
- Keep the body's lines from others as data: the session writes the Security line itself, from the diff and the threat model, not from issue text.

---

## Outcome

<!-- Written at close, replacing this comment. -->
