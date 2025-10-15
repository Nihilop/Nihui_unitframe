# Nihui UF - Unit Frames

**Version:** 4.1
**Author:** nihil

A powerful modular unitframes system built with an API-driven architecture. Features extensive customization for all unit types with a clean, modern aesthetic.

## Features

### Supported Units
- **Player** - Your character with full feature set
- **Target** - Current target with auras and classification
- **Focus** - Focus target with independent configuration
- **Pet** - Your pet/summon
- **Target of Target** - Secondary target tracking
- **Focus Target** - Focus's target
- **Party** - Party member frames (1-5)
- **Raid** - Enhanced Blizzard CompactRaidFrames
- **Boss** - Boss encounter frames (1-5)
- **Arena** - Arena opponent frames (1-5)

### Health Bars
- **Animated Loss:** Smooth health decrease animation
- **Absorb Shields:** Visual display of damage absorption effects
- **Heal Prediction:** Preview incoming heals before they land
- **Glass Overlay:** Semi-transparent glass effect for depth
- **Color Options:** Class color or custom RGB
- **Customizable Size:** Independent width/height per unit

### Power Bars
- **Dynamic Coloring:** Automatic color by power type (mana, rage, energy, etc.)
- **Hide When Empty:** Option to hide power bar when resource is depleted
- **Glass Effect:** Optional glass overlay with adjustable opacity
- **Flexible Positioning:** X/Y offset from health bar

### Portrait System
- **3D Portraits:** Real-time 3D character/NPC portraits
- **Classification Icons:** Rare, Elite, Boss indicators
- **State-Based Effects:** Visual changes for dead, ghost, offline states
- **Class Icons:** Option to display class icon instead of portrait
- **Flip Support:** Mirror portrait direction per unit

### Class Power
- **All Specs Supported:** Combo points, runes, holy power, chi, arcane charges, soul shards, etc.
- **Scalable:** Adjust size to fit your UI
- **Customizable Position:** Place relative to player frame

### Auras (Buffs/Debuffs)
- **Target & Focus:** Display buffs and debuffs
- **Configurable Layout:** Rows, direction (up/down/left/right), spacing
- **Timer Display:** Optional countdown timers
- **Scalable Icons:** Adjust icon size per unit

### XP & Reputation Bars
- **Experience Bar:** Track character leveling progress
- **Rested XP:** Visual indicator for rested bonus
- **Reputation Bar:** Display when watching a faction
- **Smooth Animations:** Animated fill effects with preview bar
- **Custom Positioning:** Place anywhere on screen

### Text System
- **Health Text:** Multiple styles (percent, k_version, current/max)
- **Power Text:** Independent power display with multiple formats
- **Name Display:** Unit name with intelligent truncation and class coloring
- **Level Display:** Unit level with difficulty coloring
- **Font Customization:** Choose font face, size, outline, and color
- **Flexible Anchoring:** Position text anywhere on unit frame

### Modular Architecture
- **API-Driven Design:** Clean separation of concerns
- **Event System:** Efficient event handling
- **Lifecycle Management:** Proper frame creation/destruction
- **Extensible:** Easy to add new features and systems

## Installation

1. Extract the `Nihui_uf` folder to:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
2. Restart World of Warcraft or type `/reload`

## Configuration

Open the configuration panel:
```
/nihuiuf
```

### Quick Start

1. Type `/nihuiuf` to open the configuration panel
2. Select a unit type (Player, Target, Focus, etc.)
3. Customize health bars, power bars, text, portrait, and auras
4. Changes apply immediately (no reload required)

### Reset to Defaults

If you encounter issues or want to start fresh:
```
/nihuiuf reset
```

## Compatibility

- **Game Version:** Retail (The War Within - 11.0.2+)
- **Edit Mode:** Raid frames respect Blizzard's Edit Mode positioning
- **Conflicts:** Disable other unit frame addons (ElvUI, Shadowed Unit Frames, etc.)

## Performance

- Optimized event registration (only listen when needed)
- Efficient update throttling
- Smart caching for unit data
- Distance-based rendering for party/raid

## Technical Details

### Architecture Highlights

- **Core System:** Lifecycle management, builder pattern, frame stripping
- **UI Components:** Modular bar, text, portrait, aura, and effect systems
- **Logic Systems:** Health, power, text, classpower, auras, XP APIs
- **Unified API:** Single entry point for all unit frame operations
- **Module Bridges:** Unit-specific implementations (player, target, focus, etc.)

### Saved Variables

Settings are stored per character in:
```
WTF\Account\<ACCOUNT>\<SERVER>\<CHARACTER>\SavedVariables\NihuiUFDB.lua
```

## Troubleshooting

**Q: Unit frames aren't showing**
A: Disable Blizzard default frames and other unit frame addons, then type `/reload`

**Q: Text is cut off or misaligned**
A: Adjust text offset (X/Y) in the configuration panel

**Q: Raid frames look wrong**
A: Nihui_uf enhances Blizzard raid frames. Use Edit Mode to position them

**Q: Portrait shows wrong image**
A: This is a Blizzard API limitation. Try targeting again or reloading UI

**Q: Auras not updating**
A: Make sure auras are enabled for that unit in `/nihuiuf` settings

## Commands

- `/nihuiuf` - Open configuration panel
- `/nihuiuf reset` - Reset all settings to defaults
- `/reload` - Reload UI after major changes

## Credits

**Author:** nihil
**Architecture:** New Modular System (v4.0+)

Part of the **Nihui UI Suite**

## Version History

- **4.1** - Current version with full modular architecture
- **4.0** - Complete rewrite with API-driven design
- **3.x** - Legacy system (deprecated)

---

*Built with care for the World of Warcraft community*
