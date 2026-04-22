# Development Orchestration Workflow v0.1

## Goal

Define the backend and frontend requirement analysis, task planning, coding, preview, review, test, and delivery workflow for generated software projects.

## Stage Outputs

The development stage must expose these outputs in stage detail:

- Frontend task package: page list, routes, component split, state needs, API dependencies, agent-ready task files.
- Backend task package: API contract, data model, module split, error codes, deployment config, agent-ready task files.
- Integration plan: branch policy, preview policy, merge gates, test gates.
- Delivery archive: frontend build, backend build, API docs, deployment docs, environment docs, acceptance report.

## Agent Limits

Current version:

- One frontend implementation agent.
- One backend implementation agent.
- Implementation model: `gpt-5.4-mini`.
- Code Review model: `gpt-5.4-codex`.

Future version:

- Multiple agents can work on one large feature after task boundaries and file ownership are explicit.
- Each agent must own a separate development branch.

## Git Workflow

Branch model:

- `main`: formal release branch.
- `preview`: stable user preview branch.
- `develop`: integrated development branch for a large feature.
- `agent/frontend-*`: frontend agent work branch.
- `agent/backend-*`: backend agent work branch.

Merge flow:

1. Create agent branch from `develop`.
2. Agent completes local implementation and minimal validation.
3. Agent opens merge request into `develop`.
4. Code Review runs before merge.
5. Review fixes are committed on the same agent branch.
6. Tests pass before merge.
7. `develop` receives all completed agent branches.
8. Integrated validation runs on `develop`.
9. After validation passes, promote `develop` to `preview`.
10. User preview URL always points to `preview`.

When GitHub integration is enabled, project creation must also create or sync a GitHub repository used as the source-code archive.

## Preview Policy

The user-facing preview must always be usable.

- User preview points only to the last validated `preview` version.
- In-progress work is never exposed through the stable preview URL.
- Agent branch previews are internal and can be unstable.
- `develop` previews are internal integration previews.
- A feature becomes visible to users only after validation passes and `preview` is promoted.

Completion message format:

```text
任务：<task-name> 已完成
预览地址：<stable-preview-url>
验证范围：<routes-or-features>
产物：<artifact-list>
```

## Coding Loop

Each implementation task must follow this loop:

```text
coding -> code review -> fix review comments -> test -> coding
```

Exit conditions:

- Review has no blocking findings.
- Tests for the task pass.
- Build passes.
- Code is readable and locally scoped.
- The task output files match the task plan.
- Preview promotion rules are satisfied.

If the same failure repeats twice without new evidence, stop the old path and switch to a new evidence path or ask for confirmation.

## Frontend Task File Template

Each frontend task file must include:

- Goal.
- Page or component scope.
- Routes affected.
- Input specs.
- Output files.
- API dependencies.
- State and loading/error behavior.
- Validation commands.
- Preview eligibility.
- Files that must not be modified.

## Backend Task File Template

Each backend task file must include:

- Goal.
- API endpoints.
- Request and response schema.
- Data model or migration needs.
- Module ownership.
- Error codes.
- Logging and configuration needs.
- Validation commands.
- Contract compatibility checks.
- Files that must not be modified.

## Final Delivery Archive

The final downloadable archive should include:

- `frontend-build/`
- `backend-build/`
- `docs/api-spec.md`
- `docs/frontend-tasks.md`
- `docs/backend-tasks.md`
- `docs/deployment.md`
- `docs/env.md`
- `docs/acceptance-report.md`
- `scripts/start.sh`
- `scripts/deploy.sh`

