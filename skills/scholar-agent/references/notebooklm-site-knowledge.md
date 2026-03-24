# NotebookLM Site Knowledge

This file records the current assumptions behind Scholar Agent's NotebookLM automation.

## Design Goal

Treat NotebookLM automation as a goal-driven capability, not a rigid click script.

Target outcome:
- Open the notebook
- Reach a state where URLs can be submitted as sources
- Submit URLs
- Release the shared browser profile cleanly

## Current UI Patterns

The regex patterns used by shell automation live in:

`scripts/notebooklm_site_knowledge.sh`

That file is the single source of truth for:
- add source button text
- website tab text
- URL textbox text
- insert button text
- new notebook button text

## Operational Facts

1. `playwright-cli open` must not redirect stdout/stderr to `/dev/null`.
2. NotebookLM is a SPA, so fixed `sleep` values are weaker than polling page state.
3. `playwright-cli` and `patchright` sharing one browser profile will create lock conflicts if they overlap.
4. "Button not found" usually means UI drift or unexpected dialog state, not necessarily total NotebookLM failure.

## Recommended Recovery Order

1. Run `scholar-inbox doctor`
2. Check for profile lock conflicts
3. Inspect a fresh `playwright-cli snapshot`
4. Update `scripts/notebooklm_site_knowledge.sh` if UI text drifted
5. Retry the add/create flow
