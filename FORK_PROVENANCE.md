# Fork provenance

The `backend/` directory in this repository was copied from the EpiWatch
WPF repository at commit `fcdf283f9aa96d999590578bba6b6d597c172710`
("Give the lab role its own workspace") on 2026-08-20.

Only git-tracked files were copied. The virtualenv, `.env`, caches and
logs were deliberately left behind.

## Why this file exists

The backend now exists in two places. Until the WPF client is retired,
any backend change made in one repository must be mirrored to the other
or the two will silently diverge. This file records the point they were
identical, so a future `diff` has a known starting point.

Once the Flutter client reaches parity and the WPF repository stops
receiving backend changes, this repository's backend becomes canonical
and this file can be deleted.
