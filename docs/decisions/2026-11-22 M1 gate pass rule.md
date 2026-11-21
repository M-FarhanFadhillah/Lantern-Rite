# 2026-11-22 M1 gate pass rule
PRD section: §16 (M1 gate) and §17 (metrics).
Was: The M1 gate is "5 testers enjoy the first 10 min", with no measure of "enjoy".
Now: Claude's call; the user had no preference. Each tester rates "Would you play again tomorrow?" from 1 to 5, and the gate passes if at least 4 of the 5 answer 4 or 5. The §2 targets (first catch within 60 seconds, first sale and first upgrade within 10 minutes) are recorded per tester but don't fail the gate. Phone FPS is measured, not required, because §16 gates 30 FPS in M3. If the gate fails, a fix round follows before re-testing. The user can also playtest on their own phone after the playable loop and after the Rowboat (private publishes, each with their go-ahead).
Why: A gate needs a pass mark that a tester session can produce, and the §2 timings are better as diagnostics than as a hard fail for a first slice.

See [[PRD]], [[plans/2026-11-22 M1 Vertical slice]] and [[sessions/2026-11-21 2137 M0 foundations]].
