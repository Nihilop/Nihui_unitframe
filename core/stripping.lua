-- cores/stripping.lua - Global Blizzard Frame Stripping System
local _, ns = ...

-- Core namespace
ns.Core = ns.Core or {}
ns.Core.Stripping = {}

-- ===========================
-- GLOBAL STRIPPING HELPERS
-- ===========================

-- Enhanced HideAndSuppress function
local function HideAndSuppress(frame)
    if not frame then return end

    frame:Hide()
    frame:SetAlpha(0)

    if frame.SetTexture then
        frame:SetTexture(nil)
    end

    if frame.SetText then
        frame:SetText("")
    end

    -- Hook to keep hidden permanently
    if frame.Show and not frame._hideHooked then
        frame:HookScript("OnShow", function(self)
            self:Hide()
            self:SetAlpha(0)
        end)
        frame._hideHooked = true
    end

    -- Disable mouse interaction
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
end

-- Utility: Kill any OnUpdate logic
local function KillOnUpdate(frame)
    if frame and frame.SetScript and frame.GetScript then
        if frame:GetScript("OnUpdate") then
            frame:SetScript("OnUpdate", nil)
        end
    end
end

-- Utility: Disable default Blizzard health/power bar logic
local function StripFrameHealthPower(healthBar, powerBar)
    if healthBar then
        healthBar:UnregisterAllEvents()
        healthBar:SetAlpha(0)
        KillOnUpdate(healthBar)
    end
    if powerBar then
        powerBar:UnregisterAllEvents()
        powerBar:SetAlpha(0)
        KillOnUpdate(powerBar)
    end
end

-- ===========================
-- SPECIALIZED STRIPPING FUNCTIONS
-- ===========================

-- Strip player frame completely (preserves portrait for our system)
local function StripPlayerFrame()
    if not PlayerFrame then return 0 end

    local count = 0

    -- Modern player frame structure
    local container = PlayerFrame.PlayerFrameContainer
    local content = PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local contextual = content and content.PlayerFrameContentContextual

    -- Strip modern health bar structure
    if main and main.HealthBarsContainer then
        local healthContainer = main.HealthBarsContainer
        StripFrameHealthPower(healthContainer.HealthBar, nil)
        HideAndSuppress(healthContainer.HealthBar)
        HideAndSuppress(healthContainer.HealthBarTexture)
        HideAndSuppress(healthContainer.HealthBarMask)
        HideAndSuppress(healthContainer.TempMaxHealthLoss)
        HideAndSuppress(healthContainer.HealthBarText)
        HideAndSuppress(healthContainer.PlayerFrameTempMaxHealthLoss)
        HideAndSuppress(healthContainer.PlayerFrameHealthBarAnimatedLoss)
        HideAndSuppress(healthContainer.AbsorbBar)
        HideAndSuppress(healthContainer.HealPredictionBar)
        HideAndSuppress(healthContainer.MyHealPredictionBar)
        HideAndSuppress(healthContainer.OtherHealPredictionBar)
        HideAndSuppress(healthContainer.HealAbsorbBar)
        HideAndSuppress(healthContainer.OverAbsorbGlow)
        HideAndSuppress(healthContainer.OverHealAbsorbGlow)
        -- Hide divider
        if healthContainer.TempMaxHealthLossDivider then
            healthContainer.TempMaxHealthLossDivider:SetAlpha(0)
        end
        count = count + 15
    end

    -- Handle class/spec specific power bars
    local playerClass = select(2, UnitClass("player"))
    local specID = GetSpecialization()
    local shouldHideAlternatePowerBar = false

    if playerClass == "PRIEST" and specID == 3 then -- Shadow Priest
        shouldHideAlternatePowerBar = true
    elseif playerClass == "SHAMAN" and specID == 1 then -- Elemental Shaman
        shouldHideAlternatePowerBar = true
    elseif playerClass == "DRUID" then -- Balance Druid
        shouldHideAlternatePowerBar = true
    end

    -- Strip power bar based on class/spec
    local manaBar
    if shouldHideAlternatePowerBar then
        if AlternatePowerBar then
            AlternatePowerBar:UnregisterAllEvents()
            HideAndSuppress(AlternatePowerBar)
        end
        manaBar = main and main.ManaBarArea and main.ManaBarArea.ManaBar
    else
        manaBar = (main and main.ManaBarArea and main.ManaBarArea.ManaBar) or AlternatePowerBar
    end

    if manaBar then
        StripFrameHealthPower(nil, manaBar)
        HideAndSuppress(manaBar)
        if manaBar.ManaBarMask then
            HideAndSuppress(manaBar.ManaBarMask)
        end
        if manaBar.ManaBarTexture then
            HideAndSuppress(manaBar.ManaBarTexture)
        end
        count = count + 3
    end

    -- Strip modern mana bar area
    if main and main.ManaBarArea and not C_AddOns.IsAddOnLoaded("BetterBlizzFrames") then
        HideAndSuppress(main.ManaBarArea)
        count = count + 1
    end

    -- Strip frame textures and backgrounds
    if container then
        HideAndSuppress(container.FrameTexture)
        HideAndSuppress(container.FrameFlash) -- Combat red glow
        HideAndSuppress(container.AlternatePowerFrameTexture)
        HideAndSuppress(container.VehicleFrameTexture)
        count = count + 4
    end

    -- Additional combat flash elements that might appear elsewhere
    HideAndSuppress(PlayerFrame.PlayerFrameFlash)
    HideAndSuppress(_G["PlayerFrameFlash"])

    -- Try to find and hide hit indicator red flash elements
    if main and main.HitIndicator then
        -- Keep the hit indicator for damage numbers, but strip any red flash
        if main.HitIndicator.RedFlash then
            HideAndSuppress(main.HitIndicator.RedFlash)
        end
        if main.HitIndicator.Flash then
            HideAndSuppress(main.HitIndicator.Flash)
        end
    end

    -- IMPORTANT: DO NOT hide the HitIndicator itself, we relocate it to custom portrait
    -- HideAndSuppress(_G["PlayerFrameHitIndicator"])  -- COMMENTED: We need this for damage numbers
    -- HideAndSuppress(_G["PlayerHitIndicator"])       -- COMMENTED: We need this for damage numbers

    -- Check for any flash textures in container
    if container then
        local children = {container:GetChildren()}
        for _, child in ipairs(children) do
            if child.GetName then
                local name = child:GetName()
                if name and (name:find("Flash") or name:find("Hit") or name:find("Red")) then
                    HideAndSuppress(child)
                end
            end
        end
    end

    count = count + 4

    -- Strip contextual elements AND Blizzard portrait (we have our own custom portrait)
    if contextual then
        HideAndSuppress(contextual.PlayerName)
        HideAndSuppress(contextual.PlayerLevelText)
        HideAndSuppress(contextual.PlayerRestLoop)
        HideAndSuppress(contextual.PrestigeBadge)
        HideAndSuppress(contextual.PrestigePortrait)
        HideAndSuppress(contextual.PlayerPortraitCornerIcon)
        HideAndSuppress(contextual.GroupIndicator)
        if contextual.PlayerRestLoop then
            HideAndSuppress(contextual.PlayerRestLoop.RestTexture)
            count = count + 1
        end
        count = count + 7
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if container and container.PlayerPortrait then
        HideAndSuppress(container.PlayerPortrait)
        HideAndSuppress(container.PlayerPortraitMask)
        count = count + 2
    end

    -- Strip global prestige elements
    HideAndSuppress(_G["PlayerFramePrestigeBadge"])
    HideAndSuppress(_G["PlayerFramePrestigePortrait"])
    count = count + 2

    -- Strip global text elements
    HideAndSuppress(_G["PlayerName"])
    HideAndSuppress(_G["PlayerLevelText"])
    count = count + 2

    -- Strip main frame text elements and status textures
    if main then
        HideAndSuppress(main.Name)
        HideAndSuppress(main.LevelText)
        HideAndSuppress(main.StatusTexture) -- This is the red combat glow!
        count = count + 3
    end

    -- Strip contextual elements using rnxmUI approach (simplified and more reliable)
    local function HidePlayerContextualElements()
        -- Direct path to contextual frame
        local contextualFrame = PlayerFrame and PlayerFrame.PlayerFrameContentContextual

        if contextualFrame then
            HideAndSuppress(contextualFrame.PrestigeBadge)
            HideAndSuppress(contextualFrame.PrestigePortrait)
            HideAndSuppress(contextualFrame.PlayerPortraitCornerIcon)
            HideAndSuppress(contextualFrame.GroupIndicator)
            count = count + 4
        end

        -- Nested path (most common)
        local nestedContextual = PlayerFrame and PlayerFrame.PlayerFrameContent and
                                 PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual

        if nestedContextual then
            HideAndSuppress(nestedContextual.PrestigeBadge)
            HideAndSuppress(nestedContextual.PrestigePortrait)
            HideAndSuppress(nestedContextual.PlayerPortraitCornerIcon)
            HideAndSuppress(nestedContextual.PlayerRestLoop)
            if nestedContextual.PlayerRestLoop then
                HideAndSuppress(nestedContextual.PlayerRestLoop.RestTexture)
            end
            HideAndSuppress(nestedContextual.GroupIndicator)
            count = count + 6
        end

        -- Global prestige elements
        if _G["PlayerFramePrestigeBadge"] then
            HideAndSuppress(_G["PlayerFramePrestigeBadge"])
            count = count + 1
        end

        if _G["PlayerFramePrestigePortrait"] then
            HideAndSuppress(_G["PlayerFramePrestigePortrait"])
            count = count + 1
        end
    end

    -- Apply contextual element stripping
    HidePlayerContextualElements()

    -- Set up event-driven re-stripping for combat state elements (rnxmUI approach)
    if not ns.Core.Stripping._playerContextualWatcher then
        local contextualWatcher = CreateFrame("Frame")
        contextualWatcher:RegisterEvent("HONOR_LEVEL_UPDATE")
        contextualWatcher:RegisterEvent("PVP_RATED_STATS_UPDATE")
        contextualWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        contextualWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        contextualWatcher:RegisterEvent("UNIT_ENTERED_VEHICLE")
        contextualWatcher:RegisterEvent("UNIT_EXITED_VEHICLE")
        contextualWatcher:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
        contextualWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat

        -- OPTIMIZED: Throttle updates to avoid spam
        local lastUpdate = 0
        contextualWatcher:SetScript("OnEvent", function(self, event, unit)
            -- Only process player-related events
            if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
                return
            end

            -- OPTIMIZED: Throttle to max once per 0.2s to avoid excessive updates
            local now = GetTime()
            if now - lastUpdate < 0.2 then return end
            lastUpdate = now

            -- OPTIMIZED: Execute immediately instead of creating timer objects
            HidePlayerContextualElements()

            -- Also re-strip combat flash elements aggressively
            if container then
                HideAndSuppress(container.FrameFlash)
                -- Check all children for flash elements
                local children = {container:GetChildren()}
                for _, child in ipairs(children) do
                    if child.GetName then
                        local name = child:GetName()
                        if name and (name:find("Flash") or name:find("Hit") or name:find("Red")) then
                            HideAndSuppress(child)
                        end
                    end
                    -- Also check if it's a texture with red color
                    if child.GetTexture and child:GetTexture() then
                        local r, g, b, a = child:GetVertexColor()
                        if r and r > 0.8 and g < 0.3 and b < 0.3 then -- Detect red flash
                            HideAndSuppress(child)
                        end
                    end
                end
            end
            HideAndSuppress(PlayerFrame.PlayerFrameFlash)
            HideAndSuppress(_G["PlayerFrameFlash"])
            HideAndSuppress(_G["PlayerFrameHitIndicator"])

            -- Re-hide HitIndicator flash elements and StatusTexture
            if main and main.HitIndicator then
                if main.HitIndicator.RedFlash then
                    HideAndSuppress(main.HitIndicator.RedFlash)
                end
                if main.HitIndicator.Flash then
                    HideAndSuppress(main.HitIndicator.Flash)
                end
            end

            -- Re-hide the StatusTexture (red combat glow)
            if main and main.StatusTexture then
                HideAndSuppress(main.StatusTexture)
            end
        end)

        ns.Core.Stripping._playerContextualWatcher = contextualWatcher
    end

    -- Strip legacy elements as fallback
    HideAndSuppress(PlayerFrame.healthbar)
    HideAndSuppress(PlayerFrame.manabar)
    HideAndSuppress(PlayerFrame.name)
    HideAndSuppress(PlayerFrame.levelText)
    count = count + 4

    return count
end

-- Strip target frame completely (preserves portrait for our system)
local function StripTargetFrame()
    if not TargetFrame then return 0 end

    local count = 0

    -- Modern target frame structure
    local container = TargetFrame.TargetFrameContainer
    local content = TargetFrame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    local contextual = content and content.TargetFrameContentContextual

    -- Strip modern health bar structure
    if main and main.HealthBarsContainer then
        local healthContainer = main.HealthBarsContainer
        StripFrameHealthPower(healthContainer.HealthBar, nil)
        HideAndSuppress(healthContainer.HealthBar)
        HideAndSuppress(healthContainer.HealthBarTexture)
        HideAndSuppress(healthContainer.HealthBarMask)
        HideAndSuppress(healthContainer.TempMaxHealthLoss)
        HideAndSuppress(healthContainer.HealthBarText)
        HideAndSuppress(healthContainer.AbsorbBar)
        HideAndSuppress(healthContainer.HealPredictionBar)
        HideAndSuppress(healthContainer.MyHealPredictionBar)
        HideAndSuppress(healthContainer.OtherHealPredictionBar)
        HideAndSuppress(healthContainer.HealAbsorbBar)
        HideAndSuppress(healthContainer.OverAbsorbGlow)
        HideAndSuppress(healthContainer.OverHealAbsorbGlow)
        count = count + 13
    end

    -- Strip modern mana bar structure
    if main and main.ManaBar then
        StripFrameHealthPower(nil, main.ManaBar)
        HideAndSuppress(main.ManaBar)
        HideAndSuppress(main.ManaBar.ManaBarMask)
        HideAndSuppress(main.ManaBar.ManaBarTexture)
        count = count + 4
    end

    -- Strip frame textures and backgrounds
    if container then
        HideAndSuppress(container.FrameTexture)
        HideAndSuppress(container.FrameFlash)
        HideAndSuppress(container.Flash)
        HideAndSuppress(container.BossPortraitFrameTexture)
        HideAndSuppress(container.PortraitMask)
        count = count + 5
    end

    -- Strip contextual elements AND Blizzard portrait (we have our own custom portrait)
    if contextual then
        HideAndSuppress(contextual.TargetName)
        HideAndSuppress(contextual.LevelText)
        HideAndSuppress(contextual.PrestigeBadge)
        HideAndSuppress(contextual.PrestigePortrait)
        HideAndSuppress(contextual.PvpIcon)
        HideAndSuppress(contextual.QuestIcon)
        HideAndSuppress(contextual.ThreatIndicator)
        HideAndSuppress(contextual.HighLevelTexture)
        count = count + 8
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if container and container.Portrait then
        HideAndSuppress(container.Portrait)
        HideAndSuppress(container.TargetPortraitMask)
        count = count + 2
    end

    -- Strip main frame text elements
    if main then
        HideAndSuppress(main.Name)
        HideAndSuppress(main.LevelText)
        HideAndSuppress(main.ReputationColor)
        count = count + 3
    end

    -- Strip frame text elements
    HideAndSuppress(TargetFrame.Name)
    HideAndSuppress(TargetFrame.LevelText)
    count = count + 2

    -- Strip Blizzard auras (buffs and debuffs) - Aggressive approach
    -- Hide the main spellbar anchor that controls aura positioning
    if TargetFrame.spellbarAnchor then
        HideAndSuppress(TargetFrame.spellbarAnchor)

        -- Also hide all its children recursively
        local function HideAllChildren(frame)
            if not frame then return end
            local children = {frame:GetChildren()}
            for _, child in ipairs(children) do
                HideAndSuppress(child)
                HideAllChildren(child) -- Recursive
            end
        end
        HideAllChildren(TargetFrame.spellbarAnchor)
        count = count + 10 -- Approximate count
    end

    -- Enhanced Blizzard aura system suppression
    if not ns.Core.Stripping._targetAuraSystemDisabled then

        -- Unregister UNIT_AURA events to prevent aura updates
        if TargetFrame then
            TargetFrame:UnregisterEvent("UNIT_AURA")
        end

        if FocusFrame then
            FocusFrame:UnregisterEvent("UNIT_AURA")
        end

        -- Enhanced function to aggressively clear all auras
        local function ReleaseAllAuras(self)
            -- Ultra fast path: direct pool release
            if self.auraPools then
                self.auraPools:ReleaseAll()
            end

            -- Also manually hide any aura frames that might still be visible
            local children = {self:GetChildren()}
            for _, child in ipairs(children) do
                if child:GetName() then
                    local name = child:GetName()
                    if name and (name:find("Buff") or name:find("Debuff") or name:find("Aura")) then
                        child:Hide()
                        child:SetAlpha(0)
                    end
                end
            end
        end

        -- More aggressive periodic clearing
        local function PeriodicAuraClear()
            if TargetFrame and TargetFrame.auraPools then
                TargetFrame.auraPools:ReleaseAll()
            end
            if FocusFrame and FocusFrame.auraPools then
                FocusFrame.auraPools:ReleaseAll()
            end
        end

        -- Hook UpdateAuras functions to immediately clear any auras
        if TargetFrame and TargetFrame.UpdateAuras then
            hooksecurefunc(TargetFrame, "UpdateAuras", ReleaseAllAuras)
        end

        if FocusFrame and FocusFrame.UpdateAuras then
            hooksecurefunc(FocusFrame, "UpdateAuras", ReleaseAllAuras)
        end

        -- OPTIMIZED: Removed continuous 0.5s ticker (wasteful CPU usage)
        -- The hooksecurefunc above already handles clearing reactively when needed
        -- No need for a constant background timer

        ns.Core.Stripping._targetAuraSystemDisabled = true
        -- Removed: ns.Core.Stripping._auraClearTimer = clearTimer
    end

    -- Legacy fallback
    for i = 1, 40 do
        local buffFrame = _G["TargetFrameBuff" .. i]
        if buffFrame then
            HideAndSuppress(buffFrame)
            count = count + 1
        end
        local debuffFrame = _G["TargetFrameDebuff" .. i]
        if debuffFrame then
            HideAndSuppress(debuffFrame)
            count = count + 1
        end
    end

    -- Strip legacy elements as fallback
    HideAndSuppress(TargetFrame.healthbar)
    HideAndSuppress(TargetFrame.manabar)
    HideAndSuppress(TargetFrame.name)
    HideAndSuppress(TargetFrame.levelText)
    HideAndSuppress(TargetFrame.deadText)
    HideAndSuppress(TargetFrame.pvpIcon)
    HideAndSuppress(TargetFrame.prestigePortrait)
    HideAndSuppress(TargetFrame.threatIndicator)
    count = count + 8

    return count
end

-- Strip focus frame (similar to target)
local function StripFocusFrame()
    if not FocusFrame then return 0 end

    local count = 0

    -- Modern focus frame structure (similar to target)
    local container = FocusFrame.TargetFrameContainer
    local content = FocusFrame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    local contextual = content and content.TargetFrameContentContextual

    -- Strip modern health bar structure
    if main and main.HealthBarsContainer then
        local healthContainer = main.HealthBarsContainer
        StripFrameHealthPower(healthContainer.HealthBar, nil)
        HideAndSuppress(healthContainer.HealthBar)
        HideAndSuppress(healthContainer.HealthBarTexture)
        HideAndSuppress(healthContainer.HealthBarMask)
        HideAndSuppress(healthContainer.TempMaxHealthLoss)
        HideAndSuppress(healthContainer.HealthBarText)
        count = count + 6
    end

    -- Strip modern mana bar structure
    if main and main.ManaBar then
        StripFrameHealthPower(nil, main.ManaBar)
        HideAndSuppress(main.ManaBar)
        HideAndSuppress(main.ManaBar.ManaBarMask)
        HideAndSuppress(main.ManaBar.ManaBarTexture)
        count = count + 4
    end

    -- Strip frame textures and backgrounds
    if container then
        HideAndSuppress(container.FrameTexture)
        HideAndSuppress(container.FrameFlash)
        HideAndSuppress(container.Flash)
        HideAndSuppress(container.PortraitMask)
        count = count + 4
    end

    -- Strip contextual elements AND Blizzard portrait (we have our own custom portrait)
    if contextual then
        HideAndSuppress(contextual.TargetName)
        HideAndSuppress(contextual.LevelText)
        HideAndSuppress(contextual.PrestigeBadge)
        HideAndSuppress(contextual.PrestigePortrait)
        HideAndSuppress(contextual.HighLevelTexture)
        count = count + 5
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if container and container.Portrait then
        HideAndSuppress(container.Portrait)
        HideAndSuppress(container.FocusPortraitMask)
        count = count + 2
    end

    -- Strip main frame text elements
    if main then
        HideAndSuppress(main.Name)
        HideAndSuppress(main.LevelText)
        HideAndSuppress(main.ReputationColor)
        count = count + 3
    end

    -- Strip frame text elements
    HideAndSuppress(FocusFrame.Name)
    HideAndSuppress(FocusFrame.LevelText)
    count = count + 2

    -- Focus frame doesn't have native buff/debuff frames (unlike Target)

    -- Strip legacy elements as fallback
    HideAndSuppress(FocusFrame.healthbar)
    HideAndSuppress(FocusFrame.manabar)
    HideAndSuppress(FocusFrame.name)
    HideAndSuppress(FocusFrame.levelText)
    HideAndSuppress(FocusFrame.deadText)
    count = count + 5

    return count
end

-- Strip pet frame
local function StripPetFrame()
    if not PetFrame then return 0 end

    local count = 0

    -- Strip pet health and power bars
    if PetFrameHealthBar then
        StripFrameHealthPower(PetFrameHealthBar, nil)
        HideAndSuppress(PetFrameHealthBar)
        count = count + 1
    end

    if PetFrameManaBar then
        StripFrameHealthPower(nil, PetFrameManaBar)
        HideAndSuppress(PetFrameManaBar)
        count = count + 1
    end

    -- Hide pet frame textures and decorations
    HideAndSuppress(_G["PetFrameTexture"])
    HideAndSuppress(_G["PetFrameFlash"])
    HideAndSuppress(_G["PetAttackModeTexture"])
    count = count + 3

    -- Hide pet name if it exists
    if _G["PetName"] then
        HideAndSuppress(_G["PetName"])
        count = count + 1
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if PetFrame.portrait then
        HideAndSuppress(PetFrame.portrait)
        HideAndSuppress(PetFrame.PortraitMask)
        count = count + 2
    end

    -- Strip legacy elements as fallback
    HideAndSuppress(PetFrame.healthbar)
    HideAndSuppress(PetFrame.manabar)
    HideAndSuppress(PetFrame.name)
    count = count + 3

    return count
end

-- Strip target of target frame
local function StripTargetOfTargetFrame()
    if not TargetFrameToT then return 0 end

    local count = 0

    -- Strip ToT health bar
    if TargetFrameToT.HealthBar then
        StripFrameHealthPower(TargetFrameToT.HealthBar, nil)
        HideAndSuppress(TargetFrameToT.HealthBar)
        count = count + 1
    end

    -- Strip ToT mana bar and its texture
    if TargetFrameToT.ManaBar then
        StripFrameHealthPower(nil, TargetFrameToT.ManaBar)
        HideAndSuppress(TargetFrameToT.ManaBar)
        -- Hide the mana bar texture specifically
        if TargetFrameToT.ManaBar.texture then
            HideAndSuppress(TargetFrameToT.ManaBar.texture)
        end
        count = count + 2
    end

    -- Try alternate paths for health bar
    if _G["TargetFrameToTHealthBar"] then
        StripFrameHealthPower(_G["TargetFrameToTHealthBar"], nil)
        HideAndSuppress(_G["TargetFrameToTHealthBar"])
        count = count + 1
    end

    -- Hide ToT frame textures
    HideAndSuppress(TargetFrameToT.FrameTexture)
    HideAndSuppress(TargetFrameToT.Flash)
    count = count + 2

    -- Hide ToT name if it exists
    if TargetFrameToT.Name then
        HideAndSuppress(TargetFrameToT.Name)
        count = count + 1
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if TargetFrameToT.Portrait then
        HideAndSuppress(TargetFrameToT.Portrait)
        HideAndSuppress(TargetFrameToT.PortraitMask)
        HideAndSuppress(TargetFrameToT.TargetPortraitMask)
        count = count + 3
    end

    -- Strip legacy elements as fallback
    HideAndSuppress(TargetFrameToT.healthbar)
    HideAndSuppress(TargetFrameToT.manabar)
    HideAndSuppress(TargetFrameToT.name)
    count = count + 3

    return count
end

-- Strip focus of target frame
local function StripFocusOfTargetFrame()
    if not FocusFrameToT then return 0 end

    local count = 0

    -- Strip FoT health bar
    if FocusFrameToT.HealthBar then
        StripFrameHealthPower(FocusFrameToT.HealthBar, nil)
        HideAndSuppress(FocusFrameToT.HealthBar)
        count = count + 1
    end

    -- Strip FoT mana bar and its texture
    if FocusFrameToT.ManaBar then
        StripFrameHealthPower(nil, FocusFrameToT.ManaBar)
        HideAndSuppress(FocusFrameToT.ManaBar)
        -- Hide the mana bar texture specifically
        if FocusFrameToT.ManaBar.texture then
            HideAndSuppress(FocusFrameToT.ManaBar.texture)
        end
        count = count + 2
    end

    -- Try alternate paths for health bar
    if _G["FocusFrameToTHealthBar"] then
        StripFrameHealthPower(_G["FocusFrameToTHealthBar"], nil)
        HideAndSuppress(_G["FocusFrameToTHealthBar"])
        count = count + 1
    end

    -- Hide FoT frame textures
    HideAndSuppress(FocusFrameToT.FrameTexture)
    HideAndSuppress(FocusFrameToT.Flash)
    count = count + 2

    -- Hide FoT name if it exists
    if FocusFrameToT.Name then
        HideAndSuppress(FocusFrameToT.Name)
        count = count + 1
    end

    -- Hide Blizzard portrait (we use our own custom portrait)
    if FocusFrameToT.Portrait then
        HideAndSuppress(FocusFrameToT.Portrait)
        HideAndSuppress(FocusFrameToT.PortraitMask)
        HideAndSuppress(FocusFrameToT.FocusPortraitMask)
        count = count + 3
    end

    return count
end

-- Strip party frames (both old and modern types)
local function StripPartyFrames()
    local count = 0

    -- DEBUG: List all party-related frames

    -- Check if party frames are managed by the raid system
    if CompactRaidFrameManager then
        HideAndSuppress(CompactRaidFrameManager)
        count = count + 1
    end

    if CompactPartyFrame then
        HideAndSuppress(CompactPartyFrame)
        count = count + 1
    end

    -- Check various party frame possibilities
    local framePatterns = {
        "PartyMemberFrame",
        "CompactPartyFrameMember",
        "CompactRaidFrameMember",
        "PartyFrame",
        "CompactPartyFrame"
    }

    for _, pattern in ipairs(framePatterns) do
        for i = 1, 5 do
            local frameName = pattern .. i
            local frame = _G[frameName]
            if frame then
            end
        end
    end

    -- Check PartyFrame with MemberFrame children
    if _G["PartyFrame"] then
        for i = 1, 4 do
            local memberFrame = _G["PartyFrame"]["MemberFrame" .. i]
            if memberFrame then
            end
        end
    end

    -- Strip legacy PartyFrame.MemberFrame1-4
    if _G["PartyFrame"] then
        for i = 1, 4 do
            local memberFrame = _G["PartyFrame"]["MemberFrame" .. i]
            if memberFrame then

                -- Strip health and power bars with proper event handling
                StripFrameHealthPower(memberFrame.healthbar or memberFrame.healthBar,
                                     memberFrame.manabar or memberFrame.manaBar or memberFrame.powerbar or memberFrame.powerBar)

                HideAndSuppress(memberFrame.healthbar)
                HideAndSuppress(memberFrame.healthBar)
                HideAndSuppress(memberFrame.manabar)
                HideAndSuppress(memberFrame.manaBar)
                HideAndSuppress(memberFrame.powerbar)
                HideAndSuppress(memberFrame.powerBar)
                HideAndSuppress(memberFrame.name)
                HideAndSuppress(memberFrame.background)
                HideAndSuppress(memberFrame.border)

                -- Strip the textures you found with Frame Inspector
                HideAndSuppress(memberFrame.Texture)
                HideAndSuppress(memberFrame.VehicleTexture)

                -- Strip portrait textures but preserve portrait frame for our system
                HideAndSuppress(memberFrame.portrait)

                -- Strip Blizzard disconnect overlay (we have our own)
                if memberFrame.PartyMemberOverlay then
                    HideAndSuppress(memberFrame.PartyMemberOverlay.Disconnect)
                end
                HideAndSuppress(memberFrame.Portrait)
                HideAndSuppress(memberFrame.PortraitMask)

                count = count + 12
            end
        end
    end

    -- Strip modern CompactPartyFrameMember1-5 (modern party frames)
    for i = 1, 5 do
        local compactFrame = _G["CompactPartyFrameMember" .. i]
        if compactFrame then

            -- Strip health and power bars with all sub-elements
            if compactFrame.healthBar then
                StripFrameHealthPower(compactFrame.healthBar, nil)
                HideAndSuppress(compactFrame.healthBar)
                -- Strip health bar texture and mask
                if compactFrame.healthBar.texture then
                    HideAndSuppress(compactFrame.healthBar.texture)
                end
                if compactFrame.healthBar.mask then
                    HideAndSuppress(compactFrame.healthBar.mask)
                end
                count = count + 3
            end
            if compactFrame.powerBar then
                StripFrameHealthPower(nil, compactFrame.powerBar)
                HideAndSuppress(compactFrame.powerBar)
                -- Strip power bar texture and mask
                if compactFrame.powerBar.texture then
                    HideAndSuppress(compactFrame.powerBar.texture)
                end
                if compactFrame.powerBar.mask then
                    HideAndSuppress(compactFrame.powerBar.mask)
                end
                count = count + 3
            end

            -- Strip compact frame elements (comprehensive)
            HideAndSuppress(compactFrame.name)
            HideAndSuppress(compactFrame.background)
            HideAndSuppress(compactFrame.border)
            HideAndSuppress(compactFrame.texture)
            HideAndSuppress(compactFrame.aggroHighlight)
            HideAndSuppress(compactFrame.selectionHighlight)
            HideAndSuppress(compactFrame.myHealPrediction)
            HideAndSuppress(compactFrame.otherHealPrediction)
            HideAndSuppress(compactFrame.totalAbsorb)
            HideAndSuppress(compactFrame.myHealAbsorb)
            HideAndSuppress(compactFrame.myHealAbsorbLeftShadow)
            HideAndSuppress(compactFrame.myHealAbsorbRightShadow)
            HideAndSuppress(compactFrame.overAbsorbGlow)
            HideAndSuppress(compactFrame.overHealAbsorbGlow)
            HideAndSuppress(compactFrame.roleIcon)
            HideAndSuppress(compactFrame.readyCheckIcon)
            HideAndSuppress(compactFrame.centerStatusIcon)
            HideAndSuppress(compactFrame.statusText)

            -- Strip frame backgrounds and containers
            HideAndSuppress(compactFrame.Background)
            HideAndSuppress(compactFrame.backgroundTexture)
            HideAndSuppress(compactFrame.BorderBackground)
            HideAndSuppress(compactFrame.border)
            HideAndSuppress(compactFrame.Border)
            HideAndSuppress(compactFrame.BorderTexture)
            HideAndSuppress(compactFrame.FrameTexture)
            HideAndSuppress(compactFrame.frameTexture)

            -- Try to hide specific background regions without hiding the entire frame
            for _, regionName in ipairs({"Background", "backgroundTexture", "BorderBackground", "FrameTexture"}) do
                local region = compactFrame[regionName]
                if region then
                    HideAndSuppress(region)
                end
            end

            -- Try additional common elements
            if compactFrame.buffFrames then
                for j = 1, #compactFrame.buffFrames do
                    HideAndSuppress(compactFrame.buffFrames[j])
                end
            end

            if compactFrame.debuffFrames then
                for j = 1, #compactFrame.debuffFrames do
                    HideAndSuppress(compactFrame.debuffFrames[j])
                end
            end

            count = count + 15
        end

        -- Strip compact party pets (comprehensive)
        local petFrame = _G["CompactPartyFramePet" .. i]
        if petFrame then
            if petFrame.healthBar then
                StripFrameHealthPower(petFrame.healthBar, nil)
                HideAndSuppress(petFrame.healthBar)
                if petFrame.healthBar.texture then
                    HideAndSuppress(petFrame.healthBar.texture)
                end
                count = count + 2
            end
            HideAndSuppress(petFrame.name)
            HideAndSuppress(petFrame.background)
            HideAndSuppress(petFrame.border)
            HideAndSuppress(petFrame.texture)
            HideAndSuppress(petFrame.aggroHighlight)
            HideAndSuppress(petFrame.statusText)
            count = count + 6
        end
    end

    return count
end

-- Strip boss frames (boss1-boss5)
local function StripBossFrames()
    local count = 0

    for i = 1, 5 do
        local bossFrame = _G["Boss" .. i .. "TargetFrame"]
        if bossFrame then
            -- Strip health bar
            if bossFrame.healthbar or bossFrame.HealthBar then
                StripFrameHealthPower(bossFrame.healthbar or bossFrame.HealthBar, nil)
                HideAndSuppress(bossFrame.healthbar)
                HideAndSuppress(bossFrame.HealthBar)
                count = count + 2
            end

            -- Strip mana/power bar
            if bossFrame.manabar or bossFrame.ManaBar then
                StripFrameHealthPower(nil, bossFrame.manabar or bossFrame.ManaBar)
                HideAndSuppress(bossFrame.manabar)
                HideAndSuppress(bossFrame.ManaBar)
                count = count + 2
            end

            -- Strip textures and decorations
            HideAndSuppress(bossFrame.texture)
            HideAndSuppress(bossFrame.Texture)
            HideAndSuppress(bossFrame.background)
            HideAndSuppress(bossFrame.Background)
            HideAndSuppress(bossFrame.border)
            HideAndSuppress(bossFrame.Border)

            -- Strip name and level text
            HideAndSuppress(bossFrame.name)
            HideAndSuppress(bossFrame.Name)
            HideAndSuppress(bossFrame.levelText)
            HideAndSuppress(bossFrame.LevelText)

            -- Hide Blizzard portrait (we use our own)
            HideAndSuppress(bossFrame.portrait)
            HideAndSuppress(bossFrame.Portrait)
            HideAndSuppress(bossFrame.PortraitMask)

            count = count + 13
        end
    end

    return count
end

-- Strip arena frames (arena1-arena3)
local function StripArenaFrames()
    local count = 0

    for i = 1, 3 do
        local arenaFrame = _G["ArenaEnemyMatchFrame" .. i] or _G["ArenaEnemyFrame" .. i]
        if arenaFrame then
            -- Strip health bar
            if arenaFrame.healthbar or arenaFrame.HealthBar then
                StripFrameHealthPower(arenaFrame.healthbar or arenaFrame.HealthBar, nil)
                HideAndSuppress(arenaFrame.healthbar)
                HideAndSuppress(arenaFrame.HealthBar)
                count = count + 2
            end

            -- Strip mana/power bar
            if arenaFrame.manabar or arenaFrame.ManaBar then
                StripFrameHealthPower(nil, arenaFrame.manabar or arenaFrame.ManaBar)
                HideAndSuppress(arenaFrame.manabar)
                HideAndSuppress(arenaFrame.ManaBar)
                count = count + 2
            end

            -- Strip textures and decorations
            HideAndSuppress(arenaFrame.texture)
            HideAndSuppress(arenaFrame.Texture)
            HideAndSuppress(arenaFrame.background)
            HideAndSuppress(arenaFrame.Background)
            HideAndSuppress(arenaFrame.border)
            HideAndSuppress(arenaFrame.Border)

            -- Strip name and level text
            HideAndSuppress(arenaFrame.name)
            HideAndSuppress(arenaFrame.Name)
            HideAndSuppress(arenaFrame.levelText)
            HideAndSuppress(arenaFrame.LevelText)

            -- Strip class icon (we have our own)
            HideAndSuppress(arenaFrame.classPortrait)
            HideAndSuppress(arenaFrame.ClassPortrait)

            -- Hide Blizzard portrait (we use our own)
            HideAndSuppress(arenaFrame.portrait)
            HideAndSuppress(arenaFrame.Portrait)
            HideAndSuppress(arenaFrame.PortraitMask)

            -- Strip spec text
            HideAndSuppress(arenaFrame.specText)
            HideAndSuppress(arenaFrame.SpecText)

            count = count + 16
        end
    end

    return count
end

-- ===========================
-- PARTY FRAME MONITORING
-- ===========================

-- OPTIMIZED: Monitor party frames and keep them hidden with hooks instead of constant re-stripping
local function SetupPartyFrameMonitoring()
    local partyWatcher = CreateFrame("Frame")
    partyWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")

    local isInitialized = false

    partyWatcher:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" and not isInitialized then
            isInitialized = true

            -- Strip once on initialization
            C_Timer.After(0.5, function()
                StripPartyFrames()

                -- OPTIMIZED: Use hooks to keep frames hidden instead of re-stripping
                -- This prevents them from showing again without constant CPU usage
                for i = 1, 5 do
                    local partyFrame = _G["CompactPartyFrameMember" .. i]
                    if partyFrame then
                        partyFrame:HookScript("OnShow", function(self)
                            self:Hide()
                        end)
                        if partyFrame.healthBar then
                            partyFrame.healthBar:HookScript("OnShow", function(self)
                                self:Hide()
                            end)
                        end
                    end
                end
            end)
        end
    end)
end

-- ===========================
-- PUBLIC API
-- ===========================

-- Initialize global stripping (called from init.lua)
function ns.Core.Stripping.Initialize()
    local totalCount = 0

    totalCount = totalCount + StripPlayerFrame()
    totalCount = totalCount + StripTargetFrame()
    totalCount = totalCount + StripFocusFrame()
    totalCount = totalCount + StripPetFrame()
    totalCount = totalCount + StripTargetOfTargetFrame()
    totalCount = totalCount + StripFocusOfTargetFrame()
    totalCount = totalCount + StripPartyFrames()
    totalCount = totalCount + StripBossFrames()
    totalCount = totalCount + StripArenaFrames()

    -- Setup party frame monitoring for re-stripping
    SetupPartyFrameMonitoring()

    return totalCount
end

-- Hide Blizzard portrait for a specific frame
function ns.Core.Stripping.HideBlizzardPortrait(parentFrame)
    if not parentFrame then return end

    -- Try different portrait paths based on frame type
    local portraitPaths = {
        "Portrait",
        "portrait",
        "PortraitContainer",
        "PlayerFrameContentContextual.PlayerPortrait",
        "TargetFrameContentContextual.TargetPortrait",
        "TargetFrameContent.TargetFrameContentContextual.Portrait"
    }

    for _, path in ipairs(portraitPaths) do
        local portrait = parentFrame
        for part in path:gmatch("[^.]+") do
            if portrait then
                portrait = portrait[part]
            end
        end
        if portrait then
            HideAndSuppress(portrait)
        end
    end
end

-- Individual stripping functions for manual use
ns.Core.Stripping.StripPlayer = StripPlayerFrame
ns.Core.Stripping.StripTarget = StripTargetFrame
ns.Core.Stripping.StripFocus = StripFocusFrame
ns.Core.Stripping.StripPet = StripPetFrame
ns.Core.Stripping.StripTargetOfTarget = StripTargetOfTargetFrame
ns.Core.Stripping.StripFocusOfTarget = StripFocusOfTargetFrame
ns.Core.Stripping.StripParty = StripPartyFrames
ns.Core.Stripping.StripBoss = StripBossFrames
ns.Core.Stripping.StripArena = StripArenaFrames

