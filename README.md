# ConnoisseurVanilla — Final Pro

Turtle WoW (1.12.1) consumable macro helper inspired by Consumable-Connoisseur.

## What it does
Creates/updates these per-character macros:

- Food
- Water
- Bandage
- Health Potion
- Mana Potion

Each macro is simply:

- `/run CCV_Use("<type>")`

The addon scans your bags and uses the best **usable** consumable.

## Pro features
- **Tooltip-based detection** (works with Turtle custom items)
- **Level-aware**: ignores items above your level
- **Well Fed priority**: prefers Well Fed foods if you’re not Well Fed
- **Combat-aware**:
  - Food macro uses **Health Potion** while in combat
  - Water macro uses **Mana Potion** while in combat
- **Smart potion sizing**: chooses the *smallest* potion that fits your missing HP/MP (reduces waste)
- **Conjured preference toggle** (food/drink):
  - Default: prefer vendor food/drink (uses conjured later)
  - Toggle: `/ccv conjured`

## Commands
- `/ccv update`  — rebuild macros now
- `/ccv report`  — print best detected food/drink/potions
- `/ccv wellfed` — prints whether Well Fed buff is detected
- `/ccv conjured` — toggle preferConjured on/off
- `/ccv dump` — dumps tooltip lines for bag 0 slot 1 (debug)

## Install
Unzip to:

`Interface/AddOns/ConnoisseurVanilla`

Then `/reload`.

## Notes
- Macro icons are set using the Turtle macro icon list (iconIndex) for compatibility.
- If you want to force/override an item’s classification, add it to `Data_Vanilla.lua` in `CCV_DATA.items`.


## #showtooltip integration
If **SuperCleveRoidMacros** is loaded, macros are written with `#showtooltip item:<id>` for the currently best detected item.
If it is not loaded, macros remain vanilla-safe without `#showtooltip`.
