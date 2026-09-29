---
status: investigating
trigger: "The public Nations League dashboard now shows 100% everywhere; probability values are clearly wrong."
created: 2026-09-29T00:00:00+02:00
updated: 2026-09-29T00:00:00+02:00
---

## Current Focus

bug_class: bohrbug
hypothesis: "An upstream forecast or presentation transform is collapsing probability distributions to 1.0/100% for every team, rank, or progression outcome."
test: "Compare raw simulation outcomes, accepted payload probability fields, rendered HTML values, and the WC dashboard's analogous fields; identify the first layer where values collapse."
expecting: "The first divergent layer will reveal whether the issue is simulation aggregation, payload promotion, numeric parsing/formatting, or a generic renderer fallback."
next_action: "Gather initial evidence from current source, payload, and published HTML."

## Symptoms

expected: "Unfinished groups should show a conserved probability distribution across possible ranks and progression outcomes; only resolved outcomes may be 100%."
actual: "The public Nations League dashboard appears to show 100% for every forecast/probability value."
errors: "No runtime error supplied; this is a semantic/data-rendering defect."
reproduction: "Open the public Nations League dashboard and inspect Groups/Outlook probability cells and bars."
started: "Observed after the latest Nations League dashboard publication."

## Eliminated

## Evidence

