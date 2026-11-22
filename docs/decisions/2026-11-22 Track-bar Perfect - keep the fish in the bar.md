# 2026-11-22 Track-bar Perfect - keep the fish in the bar
PRD section: §4 (Rewards for skill).
Was: §4 defines a Perfect catch as "no misses, no drain below 50%", written for all reel variants. The track bar is the only variant in M1 (built in M1 session 3). It has no discrete misses and no 50% line. The plan says session 3's design sets the exact rule.
Now: The user chose "Keep it in the bar" on 2026-11-22. On the track bar, a miss is the fish marker staying outside the player's catch bar for more than 0.25 s in a row. The first 1 s of the reel does not count (a settle-in). One stretch outside is one miss. A Perfect catch is a catch with zero misses. The 0.25 s grace and the 1 s settle-in live in the `ReelTuning` data module, so they can be tuned. The other variants keep "no misses, no drain below 50%" until each one is built.
Why: A miss that the player can see (the marker leaves the bar) is easy to understand and to feel. The grace covers short slips, so Perfect is hard but not unfair.

Options not chosen:
- "Never lose much": progress never drops more than 10 points below its highest point. It is forgiving, but players can't see the rule easily.
- "Spotless": no 0.25 s grace. It is the strictest.

Consequences:
- The same miss event drives the session 8 feel pass: sound, camera shake and phone haptics.
- The server decides Perfect from its replay of the client's input log (PRD §14). The client never reports it.
- Perfect still adds +15% sell value and counts toward mastery stars. The Assist setting still disables Perfect.

See [[PRD#4. Fishing and the reel minigame]], [[plans/2026-11-22 M1 Vertical slice]] and [[Status]].
