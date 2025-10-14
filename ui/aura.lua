-- ui/aura.lua - Aura UI Components (following Nihui_ab action bar styling)
local _, ns = ...

-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.Aura = {}

-- ===========================
-- AURA FRAME CREATION (UI ONLY)
-- ===========================

-- Create styled aura frame matching Nihui_ab action bar style
function ns.UI.Aura.CreateAuraFrame(parent, frameType)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(32, 32) -- Default size, will be scaled by config

    -- Main icon texture (exactly like action bars)
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints(frame) -- Fill the entire frame for scaling
    frame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop edges like action bars

    -- IconMask for proper texture masking (following Nihui_ab pattern)
    frame.IconMask = frame:CreateMaskTexture()
    frame.IconMask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    frame.IconMask:SetAllPoints(frame)
    -- Adjust mask texture coordinates for better fit instead of size
    frame.IconMask:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- Slight crop for better alignment
    frame.icon:AddMaskTexture(frame.IconMask)

    -- NormalTexture border (following Nihui_ab pattern)
    frame.NormalTexture = frame:CreateTexture(nil, "OVERLAY")
    frame.NormalTexture:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    frame.NormalTexture:SetAllPoints(frame) -- Match frame size for scaling
    frame.NormalTexture:SetVertexColor(0, 0, 0, 0.8) -- Black overlay instead of white

    -- Additional border texture for extra styling
    frame.border = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.border:SetAllPoints(frame) -- Match frame size for scaling
    frame.border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
    frame.border:SetVertexColor(0, 0, 0, 1) -- Black border

    -- Stack count text
    frame.count = frame:CreateFontString(nil, "OVERLAY", nil, 2)
    frame.count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame.count:SetTextColor(1, 1, 1, 1)

    -- Duration timer text
    frame.duration = frame:CreateFontString(nil, "OVERLAY", nil, 2)
    frame.duration:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.duration:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.duration:SetTextColor(1, 1, 1, 1)

    -- Cooldown frame for duration visualization (following action bar pattern)
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame) -- Fill entire frame for scaling
    frame.cooldown:SetReverse(true)
    frame.cooldown:SetHideCountdownNumbers(true)
    frame.cooldown:SetSwipeTexture("Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe")

    -- Store frame type for identification
    frame.frameType = frameType

    -- Enable mouse for tooltips (Button frame already supports this)
    frame:EnableMouse(true)
    -- Note: No RegisterForClicks needed since we only use OnEnter/OnLeave for tooltips

    -- Set high frame level for proper layering and tooltip interaction
    frame:SetFrameLevel(1001) -- Higher than container
    frame:SetFrameStrata("MEDIUM")

    -- Enable tooltips immediately (scripts set once, data retrieved on-demand)
    ns.UI.Aura.EnableTooltip(frame)

    return frame
end

-- Set aura icon
function ns.UI.Aura.SetIcon(frame, iconTexture)
    if frame.icon then
        frame.icon:SetTexture(iconTexture)
    end
end

-- Set stack count
function ns.UI.Aura.SetCount(frame, count)
    if not frame.count then return end

    if count and count > 1 then
        frame.count:SetText(count)
        frame.count:Show()
    else
        frame.count:Hide()
    end
end

-- Set duration text
function ns.UI.Aura.SetDuration(frame, durationText)
    if not frame.duration then return end

    if durationText and durationText ~= "" then
        frame.duration:SetText(durationText)
        frame.duration:Show()
    else
        frame.duration:Hide()
    end
end

-- Set cooldown animation
function ns.UI.Aura.SetCooldown(frame, startTime, duration)
    if frame.cooldown then
        if startTime and duration and duration > 0 then
            frame.cooldown:SetCooldown(startTime, duration)
        else
            frame.cooldown:Clear()
        end
    end
end

-- Enable mouse interactions for tooltips (set once, get data on-demand)
function ns.UI.Aura.EnableTooltip(frame)
    -- Ensure the frame is a Button and can receive mouse events
    if not frame:IsMouseEnabled() then
        frame:EnableMouse(true)
    end

    -- Set scripts ONCE - they will get current data on-demand
    if not frame._tooltipEnabled then
        frame:SetScript("OnEnter", function(self)
            -- Get current aura data from the frame (set during updates)
            local auraData = self.auraData
            local unit = self.unit

            if not auraData or not unit then
                return
            end

            -- Check if unit still exists (target might have changed)
            if not UnitExists(unit) then
                return
            end

            -- Force clear any existing tooltip
            GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            GameTooltip:Hide()
            GameTooltip:ClearLines()

            -- Reset and set proper owner
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 0)

            -- Always try to get fresh aura data since auraInstanceIDs can change when other auras expire
            local freshAuraData = nil

            -- Method 1: Try by auraInstanceID first
            if auraData.auraInstanceID then
                freshAuraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraData.auraInstanceID)
            end

            -- Method 2: If auraInstanceID failed, search by spell ID + source
            if not freshAuraData and auraData.spellId then
                local filter = auraData.isHarmful and "HARMFUL" or "HELPFUL"
                local index = 1
                while true do
                    local currentAuraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
                    if not currentAuraData then break end

                    -- Match by spellId and source (most reliable)
                    if currentAuraData.spellId == auraData.spellId and
                       currentAuraData.sourceUnit == auraData.sourceUnit then
                        freshAuraData = currentAuraData
                        break
                    end
                    index = index + 1
                end
            end

            -- Method 3: Search by name as last resort
            if not freshAuraData and auraData.name then
                local filter = auraData.isHarmful and "HARMFUL" or "HELPFUL"
                local index = 1
                while true do
                    local currentAuraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
                    if not currentAuraData then break end

                    if currentAuraData.name == auraData.name then
                        freshAuraData = currentAuraData
                        break
                    end
                    index = index + 1
                end
            end

            -- Use fresh data if available, fallback to cached data
            local workingData = freshAuraData or auraData

            -- If we couldn't find fresh data, the aura might have expired
            if not freshAuraData then
                -- Don't show tooltip for expired auras
                return
            end

            local success = false

            -- Method 1: SetUnitBuffByAuraInstanceID (modern API for buffs)
            if not workingData.isHarmful and workingData.auraInstanceID then
                local result, error = pcall(function()
                    GameTooltip:SetUnitBuffByAuraInstanceID(unit, workingData.auraInstanceID)
                end)
                if result and GameTooltip:NumLines() > 0 then
                    success = true
                end
            end

            -- Method 2: SetUnitDebuffByAuraInstanceID (modern API for debuffs)
            if not success and workingData.isHarmful and workingData.auraInstanceID then
                GameTooltip:ClearLines()
                local result, error = pcall(function()
                    GameTooltip:SetUnitDebuffByAuraInstanceID(unit, workingData.auraInstanceID)
                end)
                if result and GameTooltip:NumLines() > 0 then
                    success = true
                end
            end

            -- Method 3: SetSpellByID fallback
            if not success and workingData.spellId then
                GameTooltip:ClearLines()
                local result, error = pcall(function()
                    GameTooltip:SetSpellByID(workingData.spellId)
                end)
                if result and GameTooltip:NumLines() > 0 then
                    success = true
                end
            end

            -- Method 4: Simple manual tooltip (guaranteed to work)
            if not success then
                GameTooltip:ClearLines()
                local auraName = workingData.name or "Unknown Aura"
                GameTooltip:SetText(auraName, 1, 1, 1, 1, true)

                -- Add duration info if available
                if workingData.expirationTime and workingData.expirationTime > 0 then
                    local remaining = workingData.expirationTime - GetTime()
                    if remaining > 0 then
                        local duration = ""
                        if remaining >= 86400 then
                            duration = string.format("%d days", math.floor(remaining / 86400))
                        elseif remaining >= 3600 then
                            duration = string.format("%d hours", math.floor(remaining / 3600))
                        elseif remaining >= 60 then
                            duration = string.format("%d minutes", math.floor(remaining / 60))
                        else
                            duration = string.format("%.1f seconds", remaining)
                        end
                        GameTooltip:AddLine("Duration: " .. duration, 1, 1, 1)
                    end
                end

                -- Add stack count if applicable
                if workingData.applications and workingData.applications > 1 then
                    GameTooltip:AddLine("Stacks: " .. workingData.applications, 1, 1, 1)
                end

                success = true
            end

            if success then
                -- Force show and bring to front
                GameTooltip:Show()
                GameTooltip:SetFrameStrata("TOOLTIP")
                GameTooltip:SetFrameLevel(10000)
            end
        end)

        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        frame._tooltipEnabled = true
    end
end

-- Position frames in a grid layout
function ns.UI.Aura.PositionFrames(frames, container, config)
    if #frames == 0 then
        container:SetSize(1, 1)
        return
    end

    local frameSize = 32 * (config.scale or 1)
    local spacing = config.spacing or 2
    local perRow = config.perRow or 8
    local direction = config.direction or "RIGHT"

    local rows = math.ceil(#frames / perRow)
    local cols = math.min(#frames, perRow)

    -- Calculate container size
    local containerWidth = cols * frameSize + (cols - 1) * spacing
    local containerHeight = rows * frameSize + (rows - 1) * spacing
    container:SetSize(containerWidth, containerHeight)

    -- Position each frame
    for i, frame in ipairs(frames) do
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow

        -- Calculate position based on direction
        local x, y
        if direction == "RIGHT" then
            x = col * (frameSize + spacing)
            y = -row * (frameSize + spacing)
        elseif direction == "LEFT" then
            x = (cols - 1 - col) * (frameSize + spacing)
            y = -row * (frameSize + spacing)
        elseif direction == "UP" then
            x = col * (frameSize + spacing)
            y = (rows - 1 - row) * (frameSize + spacing)
        else -- DOWN
            x = col * (frameSize + spacing)
            y = -row * (frameSize + spacing)
        end

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
        frame:SetSize(frameSize, frameSize)

        -- Set unique frame level for each aura (important for mouse events)
        frame:SetFrameLevel(1001 + i) -- Each frame gets a unique level
    end
end

-- Create container frame for auras
function ns.UI.Aura.CreateContainer(parent, name)
    local container = CreateFrame("Frame", name, parent)
    container:SetSize(1, 1) -- Will be resized based on content

    -- Set high frame level to appear above other UI elements
    container:SetFrameLevel(1000)
    container:SetFrameStrata("MEDIUM")

    return container
end

-- Clean up frame (prepare for reuse)
function ns.UI.Aura.CleanFrame(frame)
    if not frame then return end

    -- Clear data
    frame.auraData = nil
    frame.unit = nil

    -- Hide elements
    frame:Hide()
    if frame.count then frame.count:Hide() end
    if frame.duration then frame.duration:Hide() end
    if frame.cooldown then frame.cooldown:Clear() end

    -- Clear positioning
    frame:ClearAllPoints()

    -- Remove scripts and reset tooltip flag
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    frame:SetScript("OnUpdate", nil)
    frame._tooltipEnabled = nil -- Reset so tooltip can be re-enabled
end

-- Show/Hide container with all children
function ns.UI.Aura.SetContainerVisibility(container, visible)
    if not container then return end

    if visible then
        container:Show()
    else
        container:Hide()
    end
end