# Routing Harness

This project separates cheap executor orchestration from expensive advisor judgement.

Intended invariants:
- executor handles cheap deterministic orchestration
- advisor handles architectural judgement
- advisor calls receive no tools
- route decisions preserve reasons and warnings for audit
- privacy-sensitive requests must not route to public profiles
- deterministic classification should not use premium advisor models

Known assumption:
Advisor routes are safe because they are observe-only.

The assumption above is intentionally incomplete: observe-only model calls can still leak context or tool access if tool exposure is inherited from the caller.