-- systems/portrait/classification.lua - Classification Overlay System (API Pure)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Portrait = ns.Systems.Portrait or {}
ns.Systems.Portrait.Classification = {}

-- ===========================
-- CLASSIFICATION SYSTEM CORE
-- ===========================

-- Create classification overlay system
function ns.Systems.Portrait.Classification.Create(parentFrame, unitToken, config)
    local classificationSystem = {}

    -- Store references
    classificationSystem.parent = parentFrame
    classificationSystem.unit = unitToken
    classificationSystem.config = config or {}
    classificationSystem.overlays = {}

    -- ===========================
    -- OVERLAY CREATION
    -- ===========================

    -- Create overlay for specific classification
    function classificationSystem:CreateOverlay(classificationType)
        if self.overlays[classificationType] then
            return self.overlays[classificationType]
        end

        -- Get configuration for this classification type
        local overlayConfig = self.config[classificationType]
        if not overlayConfig or not overlayConfig.enabled then
            return nil
        end

        -- Create overlay using UI.Effects
        local overlay = ns.UI.Effects.CreateClassificationOverlay(self.parent, overlayConfig)
        self.overlays[classificationType] = overlay

        return overlay
    end

    -- Remove overlay for specific classification
    function classificationSystem:RemoveOverlay(classificationType)
        local overlay = self.overlays[classificationType]
        if overlay then
            overlay:Hide()
            overlay.frame:SetParent(nil)
            self.overlays[classificationType] = nil
        end
    end

    -- ===========================
    -- CLASSIFICATION DETECTION
    -- ===========================

    -- Get unit classification
    function classificationSystem:GetUnitClassification()
        if not UnitExists(self.unit) then
            return nil
        end

        local classification = UnitClassification(self.unit)

        -- Handle special cases
        if classification == "worldboss" then
            return "worldboss"
        elseif classification == "rareelite" then
            return "rareelite"
        elseif classification == "rare" then
            return "rare"
        elseif classification == "elite" then
            return "elite"
        end

        return "normal"
    end

    -- Check if unit is a boss
    function classificationSystem:IsBoss()
        if not UnitExists(self.unit) then
            return false
        end

        -- Check various boss indicators
        local classification = UnitClassification(self.unit)
        local level = UnitLevel(self.unit)

        return classification == "worldboss" or
               classification == "boss" or
               level == -1 or
               (UnitIsPlayer(self.unit) == false and UnitLevel(self.unit) > (UnitLevel("player") + 10))
    end

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update classification display
    function classificationSystem:UpdateClassification()
        if not UnitExists(self.unit) then
            self:HideAllOverlays()
            return
        end

        local classification = self:GetUnitClassification()

        -- Hide all overlays first
        self:HideAllOverlays()

        -- Show appropriate overlay
        if classification and classification ~= "normal" then
            local overlay = self:CreateOverlay(classification)
            if overlay then
                overlay:Show()

                -- Apply any dynamic effects based on config
                if self.config.dynamicEffects then
                    self:ApplyDynamicEffects(classification, overlay)
                end
            end
        end
    end

    -- Apply dynamic effects to overlay
    function classificationSystem:ApplyDynamicEffects(classification, overlay)
        local effectsConfig = self.config.dynamicEffects[classification]
        if not effectsConfig then
            return
        end

        -- Apply color variations based on unit level difference
        if effectsConfig.levelBasedColor and UnitExists(self.unit) then
            local unitLevel = UnitLevel(self.unit)
            local playerLevel = UnitLevel("player")

            if unitLevel > 0 and playerLevel > 0 then
                local levelDiff = unitLevel - playerLevel

                if levelDiff >= 10 then
                    -- Very high level - red tint
                    overlay:SetColor(1.0, 0.2, 0.2, 1.0)
                elseif levelDiff >= 5 then
                    -- High level - orange tint
                    overlay:SetColor(1.0, 0.6, 0.2, 1.0)
                elseif levelDiff <= -10 then
                    -- Very low level - gray tint
                    overlay:SetColor(0.5, 0.5, 0.5, 0.8)
                end
            end
        end

        -- Apply faction-based effects
        if effectsConfig.factionBasedColor and UnitExists(self.unit) then
            local reaction = UnitReaction(self.unit, "player")
            if reaction then
                if reaction <= 3 then
                    -- Hostile - red
                    overlay:SetColor(1.0, 0.0, 0.0, 1.0)
                elseif reaction == 4 then
                    -- Neutral - yellow
                    overlay:SetColor(1.0, 1.0, 0.0, 1.0)
                elseif reaction >= 5 then
                    -- Friendly - green
                    overlay:SetColor(0.0, 1.0, 0.0, 1.0)
                end
            end
        end
    end

    -- Hide all overlays
    function classificationSystem:HideAllOverlays()
        for _, overlay in pairs(self.overlays) do
            overlay:Hide()
        end
    end

    -- Show all relevant overlays
    function classificationSystem:ShowRelevantOverlays()
        self:UpdateClassification()
    end

    -- ===========================
    -- CONFIGURATION METHODS
    -- ===========================

    -- Enable/disable classification for specific type
    function classificationSystem:SetClassificationEnabled(classificationType, enabled)
        if not self.config[classificationType] then
            self.config[classificationType] = {}
        end

        self.config[classificationType].enabled = enabled

        if not enabled then
            self:RemoveOverlay(classificationType)
        else
            self:UpdateClassification()
        end
    end

    -- Set overlay configuration for classification type
    function classificationSystem:SetOverlayConfig(classificationType, overlayConfig)
        if not self.config[classificationType] then
            self.config[classificationType] = {}
        end

        -- Merge configuration
        for key, value in pairs(overlayConfig) do
            self.config[classificationType][key] = value
        end

        -- Recreate overlay if it exists
        if self.overlays[classificationType] then
            self:RemoveOverlay(classificationType)
            self:UpdateClassification()
        end
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for classification update events
    function classificationSystem:RegisterEvents()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
        frame:RegisterEvent("UNIT_LEVEL")

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                C_Timer.After(0.1, function()
                    self:UpdateClassification()
                end)
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                C_Timer.After(0.1, function()
                    self:UpdateClassification()
                end)
            elseif event == "UNIT_CLASSIFICATION_CHANGED" and eventUnit == self.unit then
                self:UpdateClassification()
            elseif event == "UNIT_LEVEL" and eventUnit == self.unit then
                self:UpdateClassification()
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function classificationSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the classification system
    function classificationSystem:Initialize()
        self:RegisterEvents()
        self:UpdateClassification()
    end

    -- Destroy the classification system
    function classificationSystem:Destroy()
        self:UnregisterEvents()
        self:HideAllOverlays()

        -- Clean up overlays
        for classificationType, overlay in pairs(self.overlays) do
            if overlay.frame then
                overlay.frame:SetParent(nil)
            end
        end

        self.overlays = {}
        self.parent = nil
    end

    return classificationSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function for simple cases
function ns.Systems.Portrait.Classification.Setup(parentFrame, unitToken, config)
    local system = ns.Systems.Portrait.Classification.Create(parentFrame, unitToken, config)
    system:Initialize()
    return system
end

-- Get default classification configuration
function ns.Systems.Portrait.Classification.GetDefaultConfig()
    return {
        elite = {
            enabled = true,
            atlas = "nameplates-icon-elite-gold",
            color = {1, 0.8, 0, 1},
            blendMode = "BLEND"
        },
        rare = {
            enabled = true,
            atlas = "nameplates-icon-elite-silver",
            color = {0.8, 0.8, 1, 1},
            blendMode = "BLEND"
        },
        rareelite = {
            enabled = true,
            atlas = "nameplates-icon-elite-silver",
            color = {1, 0.4, 1, 1},
            blendMode = "BLEND"
        },
        worldboss = {
            enabled = true,
            atlas = "nameplates-icon-elite-gold",
            color = {1, 0, 0, 1},
            blendMode = "BLEND"
        },
        dynamicEffects = {
            elite = {
                levelBasedColor = true,
                factionBasedColor = false
            },
            rare = {
                levelBasedColor = true,
                factionBasedColor = false
            },
            rareelite = {
                levelBasedColor = true,
                factionBasedColor = false
            },
            worldboss = {
                levelBasedColor = false,
                factionBasedColor = true
            }
        }
    }
end

-- Check if unit supports classification overlays
function ns.Systems.Portrait.Classification.SupportsClassification(unitToken)
    local supportedUnits = {
        target = true,
        focus = true,
        mouseover = true
    }

    return supportedUnits[unitToken] or false
end