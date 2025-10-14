-- modules/boss.lua - Boss Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Boss = {}

-- ===========================
-- BOSS MODULE (NEW API)
-- ===========================

local bossModule = {
    bossFrames = {},
    initialized = false,
    MAX_BOSS_FRAMES = 5
}

-- Initialize boss module
function bossModule:Initialize()
    if self.initialized then
        return
    end

    -- Wait for API if not available yet
    if not (ns.API and ns.API.UnitFrame and ns.API.UnitFrame.Create) then
        C_Timer.After(0.1, function()
            self:Initialize()
        end)
        return
    end

    -- Create boss frames (boss1-boss5)
    for i = 1, self.MAX_BOSS_FRAMES do
        local unitToken = "boss" .. i
        local parentFrame = _G["Boss" .. i .. "TargetFrame"]

        -- If Blizzard frame doesn't exist, create custom frame
        if not parentFrame then
            parentFrame = CreateFrame("Button", "NihuiUFBoss" .. i .. "Frame", UIParent, "SecureUnitButtonTemplate")
            parentFrame:SetAttribute("unit", unitToken)
            parentFrame:RegisterForClicks("AnyUp")
            parentFrame:SetSize(100, 50)

            -- Position frames vertically
            if i == 1 then
                parentFrame:SetPoint("RIGHT", UIParent, "RIGHT", -100, 100)
            else
                parentFrame:SetPoint("TOP", self.bossFrames[i-1].parentFrame, "BOTTOM", 0, -10)
            end
        end

        -- Create complete boss unitframe using API
        local unitFrame = ns.API.UnitFrame.Create(parentFrame, unitToken)

        if unitFrame then
            unitFrame.parentFrame = parentFrame
            unitFrame.unitToken = unitToken
            self.bossFrames[i] = unitFrame
        end
    end

    -- Register events for visibility management
    self:RegisterEvents()

    -- Initial visibility update
    self:UpdateVisibility()

    self.initialized = true
end

-- Update all boss frames
function bossModule:Update()
    if not self.initialized then return end

    for i = 1, self.MAX_BOSS_FRAMES do
        local unitFrame = self.bossFrames[i]
        if unitFrame then
            if unitFrame.healthSystem then
                unitFrame.healthSystem:UpdateHealth()
            end
            if unitFrame.powerSystem then
                unitFrame.powerSystem:UpdatePower()
            end
            if unitFrame.portraitSystem then
                unitFrame.portraitSystem:UpdatePortrait()
            end
        end
    end
end

-- Update boss frame visibility based on encounter
function bossModule:UpdateVisibility()
    if not self.initialized then return end

    for i = 1, self.MAX_BOSS_FRAMES do
        local unitToken = "boss" .. i
        local unitFrame = self.bossFrames[i]

        if unitFrame and unitFrame.parentFrame then
            if UnitExists(unitToken) then
                unitFrame.parentFrame:Show()
                -- Trigger immediate update
                if unitFrame.healthSystem then
                    unitFrame.healthSystem:UpdateHealth()
                end
                if unitFrame.powerSystem then
                    unitFrame.powerSystem:UpdatePower()
                end
                if unitFrame.portraitSystem then
                    unitFrame.portraitSystem:UpdatePortrait()
                end
            else
                unitFrame.parentFrame:Hide()
            end
        end
    end
end

-- Show/hide all boss frames
function bossModule:SetVisible(visible)
    if not self.initialized then return end

    for i = 1, self.MAX_BOSS_FRAMES do
        local unitFrame = self.bossFrames[i]
        if unitFrame and unitFrame.parentFrame then
            if visible then
                -- Only show if boss exists
                if UnitExists("boss" .. i) then
                    unitFrame.parentFrame:Show()
                end
            else
                unitFrame.parentFrame:Hide()
            end
        end
    end
end

-- Update config for all boss frames
function bossModule:UpdateConfig()
    if not self.initialized then return end

    for i = 1, self.MAX_BOSS_FRAMES do
        local unitFrame = self.bossFrames[i]
        if unitFrame and unitFrame.UpdateConfig then
            unitFrame:UpdateConfig()
        end
    end
end

-- Cleanup
function bossModule:Destroy()
    self:UnregisterEvents()

    for i = 1, self.MAX_BOSS_FRAMES do
        local unitFrame = self.bossFrames[i]
        if unitFrame then
            if unitFrame.Destroy then
                unitFrame:Destroy()
            end
            if unitFrame.parentFrame then
                unitFrame.parentFrame:Hide()
            end
        end
    end

    self.bossFrames = {}
    self.initialized = false
end

-- Get specific boss frame
function bossModule:GetBossFrame(index)
    return self.bossFrames[index]
end

-- ===========================
-- EVENT HANDLING
-- ===========================

function bossModule:RegisterEvents()
    if self.eventFrame then return end

    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
            -- Boss frames appeared/disappeared
            self:UpdateVisibility()
        elseif event == "UNIT_TARGETABLE_CHANGED" then
            local unit = ...
            if unit and unit:match("^boss%d$") then
                self:UpdateVisibility()
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- Update boss frames when player changes target
            self:Update()
        end
    end)

    self.eventFrame = eventFrame
end

function bossModule:UnregisterEvents()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Boss.Setup = ns.CreateModuleSetup(bossModule)

-- Public API
ns.Modules.Boss.Initialize = function()
    return bossModule:Initialize()
end

ns.Modules.Boss.Update = function()
    return bossModule:Update()
end

ns.Modules.Boss.UpdateConfig = function()
    return bossModule:UpdateConfig()
end

ns.Modules.Boss.SetVisible = function(visible)
    return bossModule:SetVisible(visible)
end

ns.Modules.Boss.Destroy = function()
    return bossModule:Destroy()
end

ns.Modules.Boss.GetBossFrame = function(index)
    return bossModule:GetBossFrame(index)
end
