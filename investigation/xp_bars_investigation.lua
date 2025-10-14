-- investigation/xp_bars_investigation.lua - Investigate Blizzard XP/Rep bars
-- This file is for understanding the structure of Blizzard's XP and Reputation bars

--[[
BLIZZARD XP/REP BAR STRUCTURE (Retail WoW)

Main frame: StatusTrackingBarManager
- Manages all status tracking bars (XP, Rep, Honor, Azerite, etc.)
- Located at bottom of screen by default

Key global frames:
1. StatusTrackingBarManager - Main container
2. MainMenuExpBar - Experience bar (legacy name, might be part of StatusTrackingBarManager now)
3. ReputationBar - Reputation bar

Important events:
- PLAYER_XP_UPDATE - When player gains XP
- UPDATE_EXHAUSTION - When rested XP changes
- PLAYER_LEVEL_UP - When player levels up
- UPDATE_FACTION - When reputation changes

Key functions:
- UnitXP("player") - Current XP
- UnitXPMax("player") - Max XP for current level
- GetXPExhaustion() - Rested XP amount
- GetWatchedFactionInfo() - Current watched faction info

XP Bar features to replicate:
1. Current XP fill
2. Rested XP (lighter blue overlay)
3. XP gain animation
4. Tooltip showing XP numbers
5. Click to toggle reputation tracking

Rep Bar features:
1. Faction name
2. Current standing (Friendly, Honored, etc.)
3. Progress bar
4. Tooltip with detailed info

Our implementation approach:
- Strip Blizzard bars using SetAlpha(0) and UnregisterAllEvents()
- Create custom XP bar using ns.UI.Bar.Create() (same as health bars)
- Add rested XP as a secondary bar or overlay
- Use glass effect and borders from our existing system
- Position at bottom of screen (or configurable)
]]

local _, ns = ...

-- Investigation functions (can be called from /dump or /run)
ns.Investigation = ns.Investigation or {}

function ns.Investigation.InspectXPBars()
    print("=== BLIZZARD XP/REP BARS INVESTIGATION ===")

    -- Check StatusTrackingBarManager
    if StatusTrackingBarManager then
        print("StatusTrackingBarManager exists")
        print("  Shown:", StatusTrackingBarManager:IsShown())
        print("  NumChildren:", select("#", StatusTrackingBarManager:GetChildren()))

        local children = {StatusTrackingBarManager:GetChildren()}
        for i, child in ipairs(children) do
            local name = child:GetName() or "Anonymous"
            print("  Child", i, ":", name)
        end
    else
        print("StatusTrackingBarManager NOT FOUND")
    end

    -- Check MainMenuExpBar (legacy)
    if MainMenuExpBar then
        print("\nMainMenuExpBar exists (legacy)")
        print("  Shown:", MainMenuExpBar:IsShown())
    else
        print("\nMainMenuExpBar NOT FOUND")
    end

    -- Check ReputationBar
    if ReputationBar then
        print("\nReputationBar exists")
        print("  Shown:", ReputationBar:IsShown())
    else
        print("\nReputationBar NOT FOUND")
    end

    -- Check player XP data
    print("\n=== PLAYER XP DATA ===")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0
    local level = UnitLevel("player")

    print("Level:", level)
    print("Current XP:", currentXP)
    print("Max XP:", maxXP)
    print("Rested XP:", restedXP)
    print("Percentage:", string.format("%.2f%%", (currentXP / maxXP) * 100))

    -- Check reputation data
    print("\n=== REPUTATION DATA ===")
    local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
    if name then
        print("Watched Faction:", name)
        print("Standing:", _G["FACTION_STANDING_LABEL" .. standing] or standing)
        print("Current:", value)
        print("Min:", minRep)
        print("Max:", maxRep)
        print("Progress:", value - minRep, "/", maxRep - minRep)
    else
        print("No faction being watched")
    end

    print("\n=== END INVESTIGATION ===")
end

-- Slash command to run investigation
SLASH_XPINVESTIGATE1 = "/xpinvestigate"
SlashCmdList["XPINVESTIGATE"] = function()
    ns.Investigation.InspectXPBars()
end

print("XP Investigation loaded. Use /xpinvestigate to inspect XP/Rep bars")
