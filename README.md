# ElvUI_ThreatImproved

Plugin for ElvUI that aims to improve threat management, both in the Threat frame and in the NamePlates.

![colors](https://github.com/user-attachments/assets/984a3e7e-9907-424f-aee6-8ecf2c4fd80b)

## Dependencies

* [ElvUI](https://github.com/ElvUI-WotLK/ElvUI)
* [FrostAtom's awesome wotlk](https://github.com/FrostAtom/awesome_wotlk) patch

## What does it do

We defined 11 aggro situations:

1.  Role: non-tank. Threat: low
2.  Role: non-tank. Threat: high
3.  Role: non-tank. Threat: more than tank, but not yet taken
4.  Role: non-tank. Threat: currently tanking
5.  Role: tank. Threat: low. Tank: another tank ⬅️
6.  Role: tank. Threat: low. Tank: another non-tank
7.  Role: tank. Threat: high. Tank: another tank ⬅️
8.  Role: tank. Threat: high. Tank: another non-tank
9.  Role: tank. Threat: tanking, low. 2nd on aggro: tank ⬅️
10. Role: tank. Threat: tanking, low. 2nd on aggro: non-tank
11. Role: tank. Threat: tanking, high on aggro

The new, interesting situations are #5, #7, and #9. In these cases, threat is being contested between two tanks, which is a completely different scenario than between a tank and a non-tank, so new colors may be desireable.

## Sample

[![imatge](https://github.com/user-attachments/assets/15bf45af-d10b-4c45-90a7-d33c3ff945fc)](https://www.twitch.tv/videos/2350542434)

### How?

With [FrostAtom's awesome wotlk](https://github.com/FrostAtom/awesome_wotlk), UnitIDs `NameplateX` are available. We can also listen for the event `NAME_PLATE_UNIT_ADDED`. This way, we can get a unit's nameplate and customize it according to our aggro situation.

### Why?

Why not? It's been fun!

### Acknowledgements

Inspired by [ElvUI_ProjectZidras](https://github.com/Zidras/ElvUI_ProjectZidras).
