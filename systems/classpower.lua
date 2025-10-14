-- systems/classpower_blizzard.lua - ClassPower System using Blizzard frames
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.ClassPower = {}

-- ===========================
-- BLIZZARD CLASSPOWER SYSTEM
-- ===========================

-- Check if current class uses discrete class power
function ns.Systems.ClassPower.IsDiscreteClass()
    local _, class = UnitClass("player")
    local discreteClasses = {
        ROGUE = true,     -- Combo Points
        PALADIN = true,   -- Holy Power
        WARLOCK = true,   -- Soul Shards
        MONK = true,      -- Chi
        DEATHKNIGHT = true, -- Runes
        DRUID = true,     -- Combo Points (feral)
        MAGE = true,      -- Arcane Charges
        EVOKER = true,    -- Essence
    }
    return discreteClasses[class] or false
end

-- Find Blizzard class power frames
local function FindBlizzardClassPowerFrames()
    local frames = {}

    -- Common locations to check (based on backup/classpower.lua)
    local possibleFrames = {
        -- Generic location
        PlayerFrame and PlayerFrame.classPowerBar,
        -- Class-specific frames
        _G["WarlockPowerFrame"],           -- Warlock soul shards
        _G["RoguePowerBar"],               -- Rogue combo points
        _G["PaladinPowerBar"],             -- Paladin holy power
        _G["MonkHarmonyBar"],              -- Monk chi
        _G["DeathKnightResourceOverlay"],  -- Death Knight runes
        _G["RuneFrame"],                   -- Death Knight runes (alternative)
        _G["ComboFrame"],                  -- Generic combo points
        _G["EssencePlayerFrame"],          -- Evoker essence
        _G["MageArcaneChargesFrame"],      -- Mage arcane charges
    }

    -- Add them to our list if they exist
    for _, frame in ipairs(possibleFrames) do
        if frame and frame:IsObjectType("Frame") then
            table.insert(frames, frame)
        end
    end

    -- Also search dynamically for frames with "Power" in the name
    for i = 1, 20 do
        local frameName = "ClassPowerBar" .. i
        local frame = _G[frameName]
        if frame then
            table.insert(frames, frame)
        end
    end

    return frames
end

-- Create class power system that repositions Blizzard frames
function ns.Systems.ClassPower.Create(parentFrame, config)
    local classPowerSystem = {}

    -- Store references
    classPowerSystem.parentFrame = parentFrame
    classPowerSystem.frames = {}

    -- Find and store Blizzard class power frames
    function classPowerSystem:FindFrames()
        local newFrames = FindBlizzardClassPowerFrames()
        local foundNew = #newFrames > #self.frames
        self.frames = newFrames
        return #self.frames > 0, foundNew
    end

    -- Apply positioning and scale to all class power frames
    function classPowerSystem:ApplySettings()
        if #self.frames == 0 then
            return
        end

        -- Get config from DB like other systems
        local unitConfig = ns.DB.GetUnitConfig("player")
        local classpowerConfig = unitConfig and unitConfig.classpower or {}

        local scale = classpowerConfig.scale or 1
        local offsetX = classpowerConfig.offsetX or 0
        local offsetY = classpowerConfig.offsetY or -5

        for i, frame in ipairs(self.frames) do
            -- Clear all points first
            frame:ClearAllPoints()

            -- Position relative to power bar (like in backup)
            frame:SetPoint("TOP", self.parentFrame, "BOTTOM", offsetX, offsetY)

            -- Apply scale
            frame:SetScale(scale)

            -- Store custom positioning flags (like in backup)
            frame._nihuiCustomPositioned = true
            frame._nihuiDesiredX = offsetX
            frame._nihuiDesiredY = offsetY
            frame._nihuiDesiredScale = scale
            frame._nihuiDesiredParent = self.parentFrame
        end
    end

    -- Update configuration (like other systems - powerSystem, healthSystem, etc.)
    function classPowerSystem:UpdateConfig(newClasspowerConfig)
        if not newClasspowerConfig or type(newClasspowerConfig) ~= "table" then
            return
        end

        -- If disabled, reset frames
        if newClasspowerConfig.enabled == false then
            self:ResetFrames()
            return
        end

        -- Find frames if we don't have any yet
        if #self.frames == 0 then
            self:FindFrames()
        end

        -- Update existing frames directly (like powerSystem does)
        local scale = newClasspowerConfig.scale or 1
        local offsetX = newClasspowerConfig.offsetX or 0
        local offsetY = newClasspowerConfig.offsetY or -5

        for i, frame in ipairs(self.frames) do
            if frame then
                -- Clear and reposition (like powerSystem does)
                frame:ClearAllPoints()
                frame:SetPoint("TOP", self.parentFrame, "BOTTOM", offsetX, offsetY)
                frame:SetScale(scale)

                -- Store positioning info
                frame._nihuiCustomPositioned = true
                frame._nihuiDesiredX = offsetX
                frame._nihuiDesiredY = offsetY
                frame._nihuiDesiredScale = scale
                frame._nihuiDesiredParent = self.parentFrame
            end
        end
    end

    -- Reset frames to Blizzard defaults
    function classPowerSystem:ResetFrames()
        for _, frame in ipairs(self.frames) do
            if frame._nihuiCustomPositioned then
                frame._nihuiCustomPositioned = false
                frame._nihuiDesiredX = nil
                frame._nihuiDesiredY = nil
                frame._nihuiDesiredScale = nil
                frame._nihuiDesiredParent = nil

                -- Reset to default scale and let Blizzard handle positioning
                frame:SetScale(1.0)
            end
        end
        self.frames = {}
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    function classPowerSystem:Initialize()
        if not ns.Systems.ClassPower.IsDiscreteClass() then
            return false
        end

        local foundFrames, foundNew = self:FindFrames()
        if foundFrames then
            self:ApplySettings()
            return true
        end

        return false
    end

    function classPowerSystem:Destroy()
        self:ResetFrames()
    end

    return classPowerSystem
end

-- Quick setup function
function ns.Systems.ClassPower.Setup(parentFrame, config)
    local system = ns.Systems.ClassPower.Create(parentFrame, config)
    if system:Initialize() then
        return system
    end
    return nil
end