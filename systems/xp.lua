-- systems/xp.lua - XP and Reputation Bar System
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.XP = {}

-- ===========================
-- XP BAR SYSTEM
-- ===========================

-- Create XP bar system
function ns.Systems.XP.Create(parentFrame, barConfig)
    local xpSystem = {}

    -- Store references
    xpSystem.parentFrame = parentFrame
    xpSystem.config = barConfig or {}

    -- Ensure barConfig.main exists
    if not barConfig.main then
        barConfig.main = {}
    end

    -- Create main XP bar using UI.Bar
    -- Note: Size controlled by parent container via SetAllPoints (Edit Mode)
    local mainBarConfig = {
        main = {
            texture = barConfig.main.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            frameLevel = 1
        },
        background = {
            texture = barConfig.background and barConfig.background.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = barConfig.background and barConfig.background.color or {0.1, 0.1, 0.1, 0.8}
        },
        glass = {
            enabled = barConfig.glass and barConfig.glass.enabled or false,
            texture = barConfig.glass and barConfig.glass.texture or "Interface\\AddOns\\Nihui_uf\\textures\\glass.tga",
            alpha = barConfig.glass and barConfig.glass.alpha or 0.2,
            blendMode = "ADD"
        },
        border = {
            enabled = barConfig.border and barConfig.border.enabled or false,
            edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
            edgeSize = 16,
            color = {0.5, 0.5, 0.5, 1},
            insets = {left = -12, top = 12, right = 12, bottom = -12}
        }
    }

    local mainBar = ns.UI.Bar.CreateCompleteBar(parentFrame, mainBarConfig)
    xpSystem.bar = mainBar.main

    -- Create rested XP overlay (lighter blue bar that shows rested XP)
    if barConfig.rested and barConfig.rested.enabled ~= false then
        xpSystem.restedBar = ns.UI.XP.CreateRestedOverlay(mainBar.main, {
            texture = barConfig.main.texture,
            color = barConfig.rested.color or {0.3, 0.5, 1, 0.5}
        })
    end

    -- Create spark for main XP bar (inspired by Nihui_cb)
    xpSystem.spark = ns.UI.XP.CreateSpark(mainBar.main, {
        texture = "Interface\\AddOns\\Nihui_uf\\textures\\orangespark.tga",
        size = {20, mainBar.main:GetHeight() * 1.58},
        blendMode = "ADD"
    })

    -- Position bar (fill parent frame)
    if mainBar.main then
        mainBar.main:ClearAllPoints()
        mainBar.main:SetAllPoints(parentFrame)
    end

    -- Store barSet reference
    xpSystem.barSet = mainBar

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update XP bar
    function xpSystem:UpdateXP()
        if not self.bar then return end

        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local restedXP = GetXPExhaustion() or 0

        if maxXP == 0 then
            maxXP = 1 -- Prevent division by zero
        end

        -- Update main bar
        ns.UI.Bar.SetValue(self.bar, currentXP, maxXP)
        ns.UI.Bar.SetColor(self.bar, 0.5, 0.3, 1, 1) -- Purple for XP

        -- Update rested bar (shows how much XP is rested)
        if self.restedBar then
            local restedEnd = math.min(currentXP + restedXP, maxXP)
            ns.UI.XP.UpdateRestedBar(self.restedBar, currentXP, restedEnd, maxXP)
        end

        -- Update spark position
        if self.spark then
            ns.UI.XP.UpdateSpark(self.spark, currentXP, maxXP, self.bar)
        end

        -- Update text if attached
        if self.textElement then
            self:UpdateText(currentXP, maxXP, restedXP)
        end
    end

    -- Update text
    function xpSystem:UpdateText(current, max, rested)
        if not self.textElement then return end

        local percentage = (current / max) * 100
        local text = string.format("%.1f%%", percentage)

        if rested and rested > 0 then
            text = text .. " (+)"
        end

        self.textElement:SetText(text)
    end

    -- Attach text element
    function xpSystem:AttachText(textElement)
        self.textElement = textElement
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    function xpSystem:RegisterEvents()
        local frame = CreateFrame("Frame")

        -- Store old XP for animation
        self.lastXP = UnitXP("player")

        frame:RegisterEvent("PLAYER_XP_UPDATE")
        frame:RegisterEvent("UPDATE_EXHAUSTION")
        frame:RegisterEvent("PLAYER_LEVEL_UP")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")

        frame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_XP_UPDATE" then
                -- Simple instant update, no animation
                self:UpdateXP()
                self.lastXP = UnitXP("player")

            elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_ENTERING_WORLD" then
                self:UpdateXP()
                self.lastXP = UnitXP("player")

            elseif event == "PLAYER_LEVEL_UP" then
                -- Reset and update on level up
                self.lastXP = 0
                C_Timer.After(0.5, function()
                    self:UpdateXP()
                end)
            end
        end)

        self.eventFrame = frame
    end

    function xpSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    function xpSystem:Initialize()
        self:RegisterEvents()
        self:UpdateXP()
    end

    function xpSystem:Destroy()
        self:UnregisterEvents()

        if self.bar then
            self.bar:Hide()
            self.bar = nil
        end

        if self.restedBar then
            self.restedBar:Hide()
            self.restedBar = nil
        end

        if self.spark then
            self.spark:Hide()
            self.spark = nil
        end
    end

    -- Update configuration
    function xpSystem:UpdateConfig(newConfig)
        if not newConfig then return end

        self.config = newConfig

        -- Note: Bar size controlled by Edit Mode (parent container), not config

        -- Update glass effect
        if self.barSet and self.barSet.glass and newConfig.glass then
            if newConfig.glass.enabled then
                self.barSet.glass:Show()
                self.barSet.glass:SetAlpha(newConfig.glass.alpha or 0.2)
            else
                self.barSet.glass:Hide()
            end
        end

        -- Update border
        if self.barSet and self.barSet.border and newConfig.border then
            if newConfig.border.enabled then
                self.barSet.border:Show()
            else
                self.barSet.border:Hide()
            end
        end

        -- Force update
        self:UpdateXP()
    end

    return xpSystem
end

-- ===========================
-- REPUTATION BAR SYSTEM
-- ===========================

-- Create Reputation bar system (secondary bar)
function ns.Systems.XP.CreateReputation(parentFrame, barConfig)
    local repSystem = {}

    repSystem.parentFrame = parentFrame
    repSystem.config = barConfig or {}

    -- Ensure barConfig.main exists
    if not barConfig.main then
        barConfig.main = {}
    end

    -- Create reputation bar (similar to XP bar)
    -- Note: Size controlled by parent container via SetAllPoints (Edit Mode)
    local repBarConfig = {
        main = {
            texture = barConfig.main.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            frameLevel = 1
        },
        background = {
            texture = barConfig.background and barConfig.background.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga",
            color = {0.1, 0.1, 0.1, 0.8}
        },
        glass = {
            enabled = barConfig.glass and barConfig.glass.enabled or false,
            texture = barConfig.glass and barConfig.glass.texture or "Interface\\AddOns\\Nihui_uf\\textures\\glass.tga",
            alpha = barConfig.glass and barConfig.glass.alpha or 0.2,
            blendMode = "ADD"
        },
        border = {
            enabled = barConfig.border and barConfig.border.enabled or false,
            edgeFile = "Interface\\AddOns\\Nihui_uf\\textures\\MirroredFrameSingleUF.tga",
            edgeSize = 16,
            color = {0.5, 0.5, 0.5, 1},
            insets = {left = -12, top = 12, right = 12, bottom = -12}
        }
    }

    local repBar = ns.UI.Bar.CreateCompleteBar(parentFrame, repBarConfig)
    repSystem.bar = repBar.main

    -- Position bar (fill parent frame)
    if repBar.main then
        repBar.main:ClearAllPoints()
        repBar.main:SetAllPoints(parentFrame)
    end

    -- Store barSet reference
    repSystem.barSet = repBar

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update reputation bar
    function repSystem:UpdateReputation()
        if not self.bar then return end

        -- Use modern API
        local factionData = C_Reputation.GetWatchedFactionData()

        if not factionData or not factionData.name then
            -- No faction being watched, hide bar and parent container
            self.bar:Hide()
            if self.parentFrame then
                self.parentFrame:Hide()
            end
            return
        end

        -- Show parent container and bar when faction is tracked
        if self.parentFrame then
            self.parentFrame:Show()
        end
        self.bar:Show()

        -- Extract data from new API
        local name = factionData.name
        local standing = factionData.reaction
        local minRep = factionData.currentReactionThreshold
        local maxRep = factionData.nextReactionThreshold
        local value = factionData.currentStanding

        -- Calculate progress within current standing
        local current = value - minRep
        local max = maxRep - minRep

        if max == 0 then
            max = 1
        end

        -- Update bar
        ns.UI.Bar.SetValue(self.bar, current, max)

        -- Color based on standing
        local color = self:GetStandingColor(standing)
        ns.UI.Bar.SetColor(self.bar, unpack(color))

        -- Update text if attached
        if self.textElement then
            self:UpdateText(name, standing, current, max)
        end
    end

    -- Get color for reputation standing
    function repSystem:GetStandingColor(standing)
        local colors = {
            [1] = {0.8, 0.1, 0.1, 1}, -- Hated
            [2] = {0.9, 0.2, 0.2, 1}, -- Hostile
            [3] = {0.9, 0.5, 0.2, 1}, -- Unfriendly
            [4] = {1, 1, 0, 1},       -- Neutral
            [5] = {0.2, 0.9, 0.2, 1}, -- Friendly
            [6] = {0.1, 0.8, 0.1, 1}, -- Honored
            [7] = {0.1, 0.7, 0.1, 1}, -- Revered
            [8] = {0.1, 0.6, 0.9, 1}  -- Exalted
        }
        return colors[standing] or {1, 1, 1, 1}
    end

    -- Update text
    function repSystem:UpdateText(name, standing, current, max)
        if not self.textElement then return end

        local standingLabel = _G["FACTION_STANDING_LABEL" .. standing] or "Unknown"
        local percentage = (current / max) * 100
        local text = string.format("%s - %s (%.1f%%)", name, standingLabel, percentage)

        self.textElement:SetText(text)
    end

    -- Attach text element
    function repSystem:AttachText(textElement)
        self.textElement = textElement
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    function repSystem:RegisterEvents()
        local frame = CreateFrame("Frame")

        frame:RegisterEvent("UPDATE_FACTION")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")

        frame:SetScript("OnEvent", function()
            self:UpdateReputation()
        end)

        self.eventFrame = frame
    end

    function repSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    function repSystem:Initialize()
        self:RegisterEvents()
        self:UpdateReputation()
    end

    function repSystem:Destroy()
        self:UnregisterEvents()

        if self.bar then
            self.bar:Hide()
            self.bar = nil
        end
    end

    function repSystem:UpdateConfig(newConfig)
        if not newConfig then return end

        self.config = newConfig

        -- Note: Bar size controlled by Edit Mode (parent container), not config

        -- Force update
        self:UpdateReputation()
    end

    return repSystem
end
