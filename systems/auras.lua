-- systems/auras.lua - Aura System Logic (using UI/aura.lua)
local _, ns = ...

-- Systems namespace
ns.Systems = ns.Systems or {}
ns.Systems.Auras = {}

-- Format duration text
local function FormatDuration(duration)
    if duration >= 86400 then
        return string.format("%dd", math.floor(duration / 86400))
    elseif duration >= 3600 then
        return string.format("%dh", math.floor(duration / 3600))
    elseif duration >= 60 then
        return string.format("%dm", math.floor(duration / 60))
    elseif duration >= 10 then
        return string.format("%d", math.floor(duration))
    elseif duration >= 1 then
        return string.format("%.1f", duration)
    else
        return ""
    end
end

-- ===========================
-- AURA FRAME POOL SYSTEM
-- ===========================

local auraFramePool = {}
local activeAuraFrames = {}

-- Get frame from pool or create new one
local function GetAuraFrame(parent, frameType)
    local poolKey = frameType
    if not auraFramePool[poolKey] then
        auraFramePool[poolKey] = {}
    end

    local frame = table.remove(auraFramePool[poolKey])
    if not frame then
        frame = ns.UI.Aura.CreateAuraFrame(parent, frameType)
    end

    frame:SetParent(parent)
    frame:Show()

    if not activeAuraFrames[poolKey] then
        activeAuraFrames[poolKey] = {}
    end
    table.insert(activeAuraFrames[poolKey], frame)

    return frame
end

-- Return frame to pool
local function ReturnAuraFrame(frame)
    if not frame or not frame.frameType then return end

    local poolKey = frame.frameType

    -- Remove from active frames
    if activeAuraFrames[poolKey] then
        for i, activeFrame in ipairs(activeAuraFrames[poolKey]) do
            if activeFrame == frame then
                table.remove(activeAuraFrames[poolKey], i)
                break
            end
        end
    end

    -- Clean frame using UI function
    ns.UI.Aura.CleanFrame(frame)

    -- Return to pool
    if not auraFramePool[poolKey] then
        auraFramePool[poolKey] = {}
    end
    table.insert(auraFramePool[poolKey], frame)
end

-- ===========================
-- AURA SYSTEM CREATION
-- ===========================

-- Create complete aura system for a unit
function ns.Systems.Auras.Create(parent, unitToken, config)
    local auraSystem = {}

    -- Store references
    auraSystem.unit = unitToken
    auraSystem.parent = parent
    auraSystem.config = config or {}
    auraSystem.buffFrames = {}
    auraSystem.debuffFrames = {}
    auraSystem.powerBarReference = nil

    -- Default configuration
    auraSystem.config.scale = auraSystem.config.scale or 1
    auraSystem.config.perRow = auraSystem.config.perRow or 8
    auraSystem.config.maxRows = auraSystem.config.maxRows or nil  -- No limit by default
    auraSystem.config.direction = auraSystem.config.direction or "RIGHT"
    auraSystem.config.showTimer = auraSystem.config.showTimer ~= false
    auraSystem.config.spacing = auraSystem.config.spacing or 2
    auraSystem.config.offsetX = auraSystem.config.offsetX or 0
    auraSystem.config.offsetY = auraSystem.config.offsetY or -5
    auraSystem.config.showOnlyPlayerDebuffs = auraSystem.config.showOnlyPlayerDebuffs or false
    auraSystem.config.stackSimilarAuras = auraSystem.config.stackSimilarAuras or false

    -- Create containers using UI function
    auraSystem.buffContainer = ns.UI.Aura.CreateContainer(parent, nil)
    auraSystem.debuffContainer = ns.UI.Aura.CreateContainer(parent, nil)

    -- Initial positioning (will be updated by UpdateContainerPositions)
    auraSystem.buffContainer:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", auraSystem.config.offsetX, auraSystem.config.offsetY)
    auraSystem.debuffContainer:SetPoint("TOPLEFT", auraSystem.buffContainer, "BOTTOMLEFT", 0, -5)

    -- ===========================
    -- UPDATE METHODS
    -- ===========================

    -- Update aura display
    function auraSystem:UpdateAuras()
        if not UnitExists(self.unit) then
            self:ClearAllAuras()
            return
        end

        -- Clear existing frames
        self:ClearAllAuras()

        -- Get buffs
        local buffIndex = 1
        while true do
            local auraData = C_UnitAuras.GetAuraDataByIndex(self.unit, buffIndex, "HELPFUL")
            if not auraData then break end

            local frame = GetAuraFrame(self.buffContainer, "buff")
            frame.auraData = auraData
            frame.unit = self.unit

            -- Set icon using UI function
            ns.UI.Aura.SetIcon(frame, auraData.icon)

            -- Set stack count using UI function
            ns.UI.Aura.SetCount(frame, auraData.applications)

            -- Set duration using UI functions
            if auraData.duration and auraData.duration > 0 and auraData.expirationTime then
                ns.UI.Aura.SetCooldown(frame, auraData.expirationTime - auraData.duration, auraData.duration)

                if self.config.showTimer then
                    -- OPTIMIZED: Throttled timer update (0.1s instead of every frame) with early return
                    frame.timeSinceLastUpdate = 0
                    frame:SetScript("OnUpdate", function(self, elapsed)
                        self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
                        if self.timeSinceLastUpdate < 0.1 then return end  -- OPTIMIZED: Early return skips rest of code

                        self.timeSinceLastUpdate = 0
                        if self.auraData and self.auraData.expirationTime then
                            local remaining = self.auraData.expirationTime - GetTime()
                            if remaining > 0 then
                                ns.UI.Aura.SetDuration(self, FormatDuration(remaining))
                            else
                                ns.UI.Aura.SetDuration(self, "")
                                self:SetScript("OnUpdate", nil)  -- Stop updating when expired
                            end
                        end
                    end)
                else
                    frame:SetScript("OnUpdate", nil)  -- Disable OnUpdate if timer not shown
                    ns.UI.Aura.SetDuration(frame, "")
                end
            else
                ns.UI.Aura.SetCooldown(frame, nil, nil)
                ns.UI.Aura.SetDuration(frame, "")
            end

            -- Enable tooltip using UI function (set once, gets data on-demand)
            ns.UI.Aura.EnableTooltip(frame)

            table.insert(self.buffFrames, frame)
            buffIndex = buffIndex + 1
        end

        -- Calculate max auras to display based on maxRows
        local maxAuras = nil
        if self.config.maxRows and self.config.maxRows > 0 then
            maxAuras = self.config.maxRows * self.config.perRow
            -- DEBUG: Uncomment to see values
            -- print(string.format("DEBUG Auras: maxRows=%s, perRow=%s, maxAuras=%s", tostring(self.config.maxRows), tostring(self.config.perRow), tostring(maxAuras)))
        end

        -- STEP 1: Collect all debuffs
        local allDebuffs = {}
        local debuffIndex = 1
        while true do
            local auraData = C_UnitAuras.GetAuraDataByIndex(self.unit, debuffIndex, "HARMFUL")
            if not auraData then break end

            -- Filter: Only show player's debuffs if option is enabled
            local shouldShow = true
            if self.config.showOnlyPlayerDebuffs then
                shouldShow = (auraData.sourceUnit == "player" or auraData.sourceUnit == "pet")
            end

            if shouldShow then
                table.insert(allDebuffs, auraData)
            end

            debuffIndex = debuffIndex + 1
        end

        -- STEP 2: Group similar auras if enabled
        local debuffsToDisplay = {}
        if self.config.stackSimilarAuras then
            -- Group by spellId
            local grouped = {}
            for _, auraData in ipairs(allDebuffs) do
                local spellId = auraData.spellId
                if not grouped[spellId] then
                    grouped[spellId] = {
                        auraData = auraData,
                        count = 1,
                        shortestExpiration = auraData.expirationTime or math.huge
                    }
                else
                    grouped[spellId].count = grouped[spellId].count + 1
                    -- Keep aura with shortest expiration time
                    if auraData.expirationTime and auraData.expirationTime < grouped[spellId].shortestExpiration then
                        grouped[spellId].auraData = auraData
                        grouped[spellId].shortestExpiration = auraData.expirationTime
                    end
                end
            end

            -- Convert to display list
            for _, groupData in pairs(grouped) do
                table.insert(debuffsToDisplay, {
                    auraData = groupData.auraData,
                    stackCount = groupData.count
                })
            end
        else
            -- No grouping - use original count
            for _, auraData in ipairs(allDebuffs) do
                table.insert(debuffsToDisplay, {
                    auraData = auraData,
                    stackCount = auraData.applications  -- Original stack count
                })
            end
        end

        -- STEP 3: Display auras (respecting max limit)
        for i, displayData in ipairs(debuffsToDisplay) do
            -- Check if we've reached the max auras limit
            if maxAuras and #self.debuffFrames >= maxAuras then
                break
            end

            local auraData = displayData.auraData
            local frame = GetAuraFrame(self.debuffContainer, "debuff")
            frame.auraData = auraData
            frame.unit = self.unit

            -- Set icon using UI function
            ns.UI.Aura.SetIcon(frame, auraData.icon)

            -- Set stack count (either grouped count or original stacks)
            ns.UI.Aura.SetCount(frame, displayData.stackCount)

            -- Set duration using UI functions
            if auraData.duration and auraData.duration > 0 and auraData.expirationTime then
                ns.UI.Aura.SetCooldown(frame, auraData.expirationTime - auraData.duration, auraData.duration)

                if self.config.showTimer then
                    -- OPTIMIZED: Throttled timer update (0.1s instead of every frame) with early return
                    frame.timeSinceLastUpdate = 0
                    frame:SetScript("OnUpdate", function(self, elapsed)
                        self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
                        if self.timeSinceLastUpdate < 0.1 then return end  -- OPTIMIZED: Early return skips rest of code

                        self.timeSinceLastUpdate = 0
                        if self.auraData and self.auraData.expirationTime then
                            local remaining = self.auraData.expirationTime - GetTime()
                            if remaining > 0 then
                                ns.UI.Aura.SetDuration(self, FormatDuration(remaining))
                            else
                                ns.UI.Aura.SetDuration(self, "")
                                self:SetScript("OnUpdate", nil)  -- Stop updating when expired
                            end
                        end
                    end)
                else
                    frame:SetScript("OnUpdate", nil)  -- Disable OnUpdate if timer not shown
                    ns.UI.Aura.SetDuration(frame, "")
                end
            else
                ns.UI.Aura.SetCooldown(frame, nil, nil)
                ns.UI.Aura.SetDuration(frame, "")
            end

            -- Enable tooltip using UI function (set once, gets data on-demand)
            ns.UI.Aura.EnableTooltip(frame)

            table.insert(self.debuffFrames, frame)
        end

        -- Position frames using UI function
        ns.UI.Aura.PositionFrames(self.buffFrames, self.buffContainer, self.config)
        ns.UI.Aura.PositionFrames(self.debuffFrames, self.debuffContainer, self.config)
    end

    -- Clear all aura frames
    function auraSystem:ClearAllAuras()
        -- Return buff frames to pool
        for _, frame in ipairs(self.buffFrames) do
            ReturnAuraFrame(frame)
        end
        self.buffFrames = {}

        -- Return debuff frames to pool
        for _, frame in ipairs(self.debuffFrames) do
            ReturnAuraFrame(frame)
        end
        self.debuffFrames = {}
    end

    -- Set power bar reference for relative positioning
    function auraSystem:SetPowerBarReference(powerBar)
        self.powerBarReference = powerBar
        self:UpdateContainerPositions()
    end

    -- Update container positions relative to power bar
    function auraSystem:UpdateContainerPositions()
        local offsetX = self.config.offsetX or 0
        local offsetY = self.config.offsetY or -5

        if not self.powerBarReference then
            -- Fallback to parent positioning
            self.buffContainer:ClearAllPoints()
            self.buffContainer:SetPoint("TOPLEFT", self.parent, "BOTTOMLEFT", offsetX, offsetY)
        else
            -- Position relative to power bar
            self.buffContainer:ClearAllPoints()
            self.buffContainer:SetPoint("TOPLEFT", self.powerBarReference, "BOTTOMLEFT", offsetX, offsetY)
        end

        -- Debuffs always positioned relative to buffs
        self.debuffContainer:ClearAllPoints()
        self.debuffContainer:SetPoint("TOPLEFT", self.buffContainer, "BOTTOMLEFT", 0, -5)
    end

    -- Update configuration
    function auraSystem:UpdateConfig(newConfig)
        if not newConfig or type(newConfig) ~= "table" then
            return
        end

        -- Handle enable/disable toggle
        if newConfig.enabled == false then
            ns.UI.Aura.SetContainerVisibility(self.buffContainer, false)
            ns.UI.Aura.SetContainerVisibility(self.debuffContainer, false)
            self:ClearAllAuras()
            return
        else
            ns.UI.Aura.SetContainerVisibility(self.buffContainer, true)
            ns.UI.Aura.SetContainerVisibility(self.debuffContainer, true)
        end

        -- Update config values
        for key, value in pairs(newConfig) do
            self.config[key] = value
        end

        -- Update container positions if offsets changed
        if newConfig.offsetX ~= nil or newConfig.offsetY ~= nil then
            self:UpdateContainerPositions()
        end

        -- Refresh display
        self:UpdateAuras()
    end

    -- ===========================
    -- EVENT HANDLING
    -- ===========================

    -- Register for aura events
    function auraSystem:RegisterEvents()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("UNIT_AURA")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        frame:RegisterEvent("PLAYER_FOCUS_CHANGED")

        frame:SetScript("OnEvent", function(_, event, eventUnit)
            if event == "UNIT_AURA" and eventUnit == self.unit then
                self:UpdateAuras()
            elseif event == "PLAYER_TARGET_CHANGED" and self.unit == "target" then
                self:UpdateAuras()
            elseif event == "PLAYER_FOCUS_CHANGED" and self.unit == "focus" then
                self:UpdateAuras()
            end
        end)

        self.eventFrame = frame
    end

    -- Unregister events
    function auraSystem:UnregisterEvents()
        if self.eventFrame then
            self.eventFrame:UnregisterAllEvents()
            self.eventFrame:SetScript("OnEvent", nil)
            self.eventFrame = nil
        end
    end

    -- ===========================
    -- LIFECYCLE
    -- ===========================

    -- Initialize the system
    function auraSystem:Initialize()
        self:RegisterEvents()
        self:UpdateAuras()
    end

    -- Destroy the system
    function auraSystem:Destroy()
        self:UnregisterEvents()
        self:ClearAllAuras()
    end

    return auraSystem
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Quick setup function
function ns.Systems.Auras.Setup(parent, unitToken, config)
    local system = ns.Systems.Auras.Create(parent, unitToken, config)
    system:Initialize()
    return system
end