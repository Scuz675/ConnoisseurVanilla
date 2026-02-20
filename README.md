# ConnoisseurVanilla

A lightweight **Turtle WoW (1.12.1)** consumable helper inspired by Consumable-Connoisseur.

This addon automatically finds the best usable consumables in your bags and updates macros so you always use the correct item.

---

## ✨ Features

### Automatic Consumable Detection
Automatically detects:

- 🍖 Food
- 🥤 Drinks (water)
- ❤️ Health Potions
- 🔵 Mana Potions
- 🩹 Bandages

Detection is tooltip-based, so it works with:

- Vanilla items
- Turtle WoW custom items
- Future server additions

---

### 🧠 Smart Selection

The addon always chooses the **best usable** item:

- Highest restore value wins
- Items above your level are ignored
- Automatically falls back to lower-tier consumables

Example:

If you are level 20 and have:

- Major Healing Potion (Req 45)
- Healing Potion (Req 12)

→ Healing Potion is used automatically.

---

### 🍗 Well Fed Priority

If you do NOT currently have the **Well Fed** buff:

- Food that grants Well Fed gets priority.

Once Well Fed is active, normal food scoring resumes.

---

### 🧩 Auto Macro Management

The addon automatically creates and updates these macros:

```
Food
Water
Bandage
Health Potion
Mana Potion
```

Macro body:

```
/run CCV_Use("<type>")
```

---

### 🎨 Hardcoded Macro Icons

Uses stable icon indices compatible with Turtle 1.12:

| Macro | Icon |
|---|---|
| Bandage | Spell_Holy_SealOfSacrifice |
| Food | Spell_Misc_Food |
| Water | Spell_Misc_Drink |
| Health Potion | Spell_Nature_Strength |
| Mana Potion | Spell_Misc_ConjureManaJewel |

---

### 📊 Login Report

On login (or manual command) the addon prints:

```
CCV Detected consumables (best usable):
Food: ...
Drink: ...
Health Potion: ...
Mana Potion: ...
```

This helps verify detection is working.

---

## 🕹 Commands

### Update macros manually
```
/ccv update
```

### Show consumable report
```
/ccv report
```

### Check Well Fed detection
```
/ccv wellfed
```

---

## 🔧 Installation

1. Extract into:

```
Interface/AddOns/ConnoisseurVanilla
```

2. Login or reload UI:
```
/reload
```

3. Open macro window (`/macro`)
4. Drag the generated macros to your bars.

---

## ⚙️ How it Works

The addon scans your bags and:

1. Reads tooltip text.
2. Detects:
   - health restoration
   - mana restoration
   - potion names
   - level requirements
3. Scores each item.
4. Selects the best usable item.

No database maintenance required.

---

## 🧱 Design Goals

- Fully Vanilla-safe (1.12 API only)
- No minimap button
- Lightweight
- Works with Turtle custom content
- Zero setup after install

---

## ⚠️ Known Limits

- Tooltip scanning depends on item tooltips loading correctly.
- Non-standard custom tooltips may need keyword additions.

---

## Credits

Inspired by:
Consumable-Connoisseur by Gogo1951

Vanilla adaptation & TurtleWoW compatibility build.
