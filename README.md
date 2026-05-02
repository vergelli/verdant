# Verdant
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)
![ESO API](https://img.shields.io/badge/ESO%20API-101049-orange)
![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)
![AI Assisted](https://img.shields.io/badge/AI%20Assisted-Claude%20by%20Anthropic-D97757?logo=anthropic&logoColor=white)

![Verdant logo](doc/assets/Verdant%20Logo%204.png)

**Real-time healer contribution bar for The Elder Scrolls Online**

Verdant quantifies your healing and shielding output into a single bar that adapts its meaning depending on whether you are playing solo or in a group. 
In other words it tracks *contribution*: how much of a meaningful ceiling your output is covering.

---

## Core Metrics

### Effective Healing Per Second

![eHPS](doc/assets/eHPS_1.png)

Healing that lands on missing HP

### Mitigation Per Second

![MPS](doc/assets/MPS_1.png)

Damage absorbed by shields you cast

### Effective Mitigation Score

![EMS](doc/assets/EMS_1.png)

The combined metric. This is what the bar primarily represents.

$$EMS = eHPS + MPS$$

---

## The Contribution Bar

**Open world** — the bar measures *efficiency*: what fraction of everything you cast was actually useful.

**In a group** — the bar measures *coverage*: how well your output keeps pace with the damage your group is taking. 

> Verdant switches between both modes automatically based on group status.

> PvP Environments (BG specially) are Work in Progress

### Bar fill

The **EMS** bar uses two stacked fills:

- **Green (bottom)** — your **eHPS** share of **EMS**
- **Pink (above)** — your **MPS** share of **EMS**

This lets you see at a glance whether your contribution is heal-driven, shield-driven, or a mix!

---

## Display Modes

Cycle through modes with the **<** / **>** arrows at the top of the window.

| Mode | What it shows |
|------|---------------|
| **EMS** | Single bar: green (**eHPS**) + pink (**MPS**) stacked fills |
| **eHPS** | Segmented bar, each segment colored by the **ability's class** or **skill line** |
| **MPS** | Segmented bar, each segment colored by the** ability's class** or **skill line** |
| **ALL** | Three columns side by side — **EMS**, *eHPS* and **MPS** simultaneously |

The **%** / **#** button below, are not the best, but toggles between contribution percentage and raw value

### Skill-color segmentation

In **eHPS** and **MPS** modes the bar is split into colored segments — one per ability group — so you can see which **class** or **skill line** is carrying the most weight.

| Swatch | Group |
|--------|-------|
| ![](https://img.shields.io/badge/-%20-F2BF26?style=flat-square) | Templar |
| ![](https://img.shields.io/badge/-%20-33EB59?style=flat-square) | Arcanist |
| ![](https://img.shields.io/badge/-%20-33D9E6?style=flat-square) | Warden |
| ![](https://img.shields.io/badge/-%20-B8802E?style=flat-square) | Restoration Staff |
| ![](https://img.shields.io/badge/-%20-E04714?style=flat-square) | Dragonknight |
| ![](https://img.shields.io/badge/-%20-4761F2?style=flat-square) | Sorcerer |
| ![](https://img.shields.io/badge/-%20-D11A2E?style=flat-square) | Nightblade |
| ![](https://img.shields.io/badge/-%20-A62ED1?style=flat-square) | Necromancer |
| ![](https://img.shields.io/badge/-%20-00BFFF?style=flat-square) | Scribing |
| ![](https://img.shields.io/badge/-%20-6B6B2E?style=flat-square) | Undaunted |
| ![](https://img.shields.io/badge/-%20-6B4FAD?style=flat-square) | Alliance War support |
| ![](https://img.shields.io/badge/-%20-8C8C8C?style=flat-square) | Unclassified |

### In-Game example

![UI example](doc/assets/verdant_ui_example_1.png)

---

## Settings

Click the **gear icon** (top-right corner of the value row) to open the settings panel. 

All values are saved per account.

### Refresh Rate

How often the bar redraws **(watch performance)**

Six presets from `0.5 Hz` to `20 Hz`. Default is `1 Hz`.

| Preset | Interval |
|--------|----------|
| 20 Hz | 50 ms |
| 10 Hz | 100 ms |
| 5 Hz | 200 ms |
| 2 Hz | 500 ms |
| 1 Hz | 1000 ms (default) |
| 0.5 Hz | 2000 ms |

### Heal Window

The rolling time window used to calculate **eHPS**. A shorter window reacts faster; a longer one smooths out burst heals.

| Preset |
|--------|
| 2 s |
| 3 s |
| **5 s** (default) |
| 8 s |
| 10 s |
| 15 s |

### Shield Window

The rolling time window used to calculate **MPS**. Shields are sparse events, so a wider window sometimes is convenient to avoid the metric collapsing to zero between hits (not an often thing anyway)

| Preset |
|--------|
| 10 s |
| 15 s |
| **30 s** (default) |
| 45 s |
| 60 s |

---

## Installation

1. Download the latest release from [ESOUI](https://www.esoui.com) or [GitHub Releases](../../releases).
2. Extract to your AddOns folder:
   ```
   Documents/Elder Scrolls Online/live/AddOns/Verdant/
   ```
3. Reload the UI with `/reloadui` or restart the game.
4. The bar appears by default. Drag it anywhere on screen.

A keybinding to toggle the bar can be assigned under **Controls → Verdant**.

---

## Known Limitations

- **PvP** (Battlegrounds, Cyrodiil) is not yet validated — group damage tracking may not correctly reflect PvP hit events.
- Shields cast by **other players** are not tracked; only your own.
- **Ability classification** is name-pattern based. Newly added abilities may appear grey until the pattern list is updated.

---

*Verdant v1.0.0 — API 101049*
