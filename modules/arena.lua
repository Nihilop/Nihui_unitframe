-- modules/arena.lua - Arena Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Arena = {}

-- ===========================
-- ARENA MODULE (NEW API)
-- ===========================

local arenaModule = {
    arenaFrames = {},
    initialized = false,
    MAX_ARENA_FRAMES = 3
}

-- Initialize arena module
function arenaModule:Initialize()
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

    -- Create arena frames (arena1-arena3)
    for i = 1, self.MAX_ARENA_FRAMES do
        local unitToken = "arena" .. i
        local parentFrame = _G["ArenaEnemyMatchFrame" .. i]

        -- If Blizzard frame doesn't exist, create custom frame
        if not parentFrame then
            parentFrame = CreateFrame("Button", "NihuiUFArena" .. i .. "Frame", UIParent, "SecureUnitButtonTemplate")
            parentFrame:SetAttribute("unit", unitToken)
            parentFrame:RegisterForClicks("AnyUp")
            parentFrame:SetSize(100, 50)

            -- Position frames vertically
            if i == 1 then
                parentFrame:SetPoint("RIGHT", UIParent, "RIGHT", -100, 200)
            else
                parentFrame:SetPoint("TOP", self.arenaFrames[i-1].parentFrame, "BOTTOM", 0, -10)
            end
        end

        -- Create complete arena unitframe using API
        local unitFrame = ns.API.UnitFrame.Create(parentFrame, unitToken)

        if unitFrame then
            unitFrame.parentFrame = parentFrame
            unitFrame.unitToken = unitToken
            self.arenaFrames[i] = unitFrame
        end
    end

    -- Register events for visibility management
    self:RegisterEvents()

    -- Initial visibility update
    self:UpdateVisibility()

    self.initialized = true
end

-- Update all arena frames
function arenaModule:Update()
    if not self.initialized then return end

    for i = 1, self.MAX_ARENA_FRAMES do
        local unitFrame = self.arenaFrames[i]
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

-- Update arena frame visibility based on arena match
function arenaModule:UpdateVisibility()
    if not self.initialized then return end

    for i = 1, self.MAX_ARENA_FRAMES do
        local unitToken = "arena" .. i
        local unitFrame = self.arenaFrames[i]

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

-- Show/hide all arena frames
function arenaModule:SetVisible(visible)
    if not self.initialized then return end

    for i = 1, self.MAX_ARENA_FRAMES do
        local unitFrame = self.arenaFrames[i]
        if unitFrame and unitFrame.parentFrame then
            if visible then
                -- Only show if arena opponent exists
                if UnitExists("arena" .. i) then
                    unitFrame.parentFrame:Show()
                end
            else
                unitFrame.parentFrame:Hide()
            end
        end
    end
end

-- Update config for all arena frames
function arenaModule:UpdateConfig()
    if not self.initialized then return end

    for i = 1, self.MAX_ARENA_FRAMES do
        local unitFrame = self.arenaFrames[i]
        if unitFrame and unitFrame.UpdateConfig then
            unitFrame:UpdateConfig()
        end
    end
end

-- Cleanup
function arenaModule:Destroy()
    self:UnregisterEvents()

    for i = 1, self.MAX_ARENA_FRAMES do
        local unitFrame = self.arenaFrames[i]
        if unitFrame then
            if unitFrame.Destroy then
                unitFrame:Destroy()
            end
            if unitFrame.parentFrame then
                unitFrame.parentFrame:Hide()
            end
        end
    end

    self.arenaFrames = {}
    self.initialized = false
end

-- Get specific arena frame
function arenaModule:GetArenaFrame(index)
    return self.arenaFrames[index]
end

-- ===========================
-- EVENT HANDLING
-- ===========================

function arenaModule:RegisterEvents()
    if self.eventFrame then return end

    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("ARENA_OPPONENT_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_TARGETABLE_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ARENA_OPPONENT_UPDATE" then
            -- Arena opponent appeared/disappeared
            self:UpdateVisibility()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Update visibility when entering/leaving arena
            C_Timer.After(1, function()
                self:UpdateVisibility()
            end)
        elseif event == "UNIT_TARGETABLE_CHANGED" then
            local unit = ...
            if unit and unit:match("^arena%d$") then
                self:UpdateVisibility()
            end
        end
    end)

    self.eventFrame = eventFrame
end

function arenaModule:UnregisterEvents()
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
ns.Modules.Arena.Setup = ns.CreateModuleSetup(arenaModule)

-- Public API
ns.Modules.Arena.Initialize = function()
    return arenaModule:Initialize()
end

ns.Modules.Arena.Update = function()
    return arenaModule:Update()
end

ns.Modules.Arena.UpdateConfig = function()
    return arenaModule:UpdateConfig()
end

ns.Modules.Arena.SetVisible = function(visible)
    return arenaModule:SetVisible(visible)
end

ns.Modules.Arena.Destroy = function()
    return arenaModule:Destroy()
end

ns.Modules.Arena.GetArenaFrame = function(index)
    return arenaModule:GetArenaFrame(index)
end
