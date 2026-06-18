# Hotfix Prompt Template

```text
Prompt XXX - Hotfix: [Bug Title]

Read AGENTS.md first.

Bug:
- Platform:
- Severity:
- Screen:
- Reproduction:
- Expected:
- Actual:
- Evidence:
- Logs:
- Affected version/build:

Rules:
- Fix only this bug.
- Do not add unrelated features.
- Do not redesign.
- Do not add Firebase/push.
- Do not weaken RLS.
- Do not commit secrets.
- Run flutter analyze and flutter test.
- Report changed files, root cause, fix, tests, analyze/test result.
```
