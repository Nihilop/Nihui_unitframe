-- ui/xp.lua - XP Bar UI Effects (Rested overlay, Preview animation)
local _, ns = ...

-- UI Components namespace
ns.UI = ns.UI or {}
ns.UI.XP = {}

-- ===========================
-- RESTED XP OVERLAY
-- ===========================

-- Create rested XP overlay (lighter blue bar showing rested XP range)
function ns.UI.XP.CreateRestedOverlay(mainBar, config)
    if not mainBar then return nil end

    local restedBar = CreateFrame("StatusBar", nil, mainBar)
    restedBar:SetAllPoints(mainBar)
    restedBar:SetStatusBarTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    restedBar:SetFrameLevel(mainBar:GetFrameLevel() + 1)
    restedBar:SetMinMaxValues(0, 100)
    restedBar:SetValue(0)

    -- Set color (lighter blue for rested)
    local color = config.color or {0.3, 0.5, 1, 0.5}
    restedBar:SetStatusBarColor(color[1], color[2], color[3], color[4])

    -- Initially hide (will show when rested XP exists)
    restedBar:Hide()

    return restedBar
end

-- Update rested bar position and size
function ns.UI.XP.UpdateRestedBar(restedBar, currentXP, restedEndXP, maxXP)
    if not restedBar then return end

    if currentXP >= restedEndXP or currentXP >= maxXP then
        -- No rested XP to show
        restedBar:Hide()
        return
    end

    -- Show rested bar
    restedBar:Show()

    -- Calculate rested bar position and size
    -- The rested bar should start at currentXP and end at restedEndXP
    local barWidth = restedBar:GetParent():GetWidth()
    local currentPercent = currentXP / maxXP
    local restedPercent = restedEndXP / maxXP

    -- Position the rested bar to start at current XP position
    restedBar:ClearAllPoints()
    restedBar:SetPoint("LEFT", restedBar:GetParent(), "LEFT", barWidth * currentPercent, 0)
    restedBar:SetPoint("TOP", restedBar:GetParent(), "TOP", 0, 0)
    restedBar:SetPoint("BOTTOM", restedBar:GetParent(), "BOTTOM", 0, 0)
    restedBar:SetPoint("RIGHT", restedBar:GetParent(), "LEFT", barWidth * restedPercent, 0)

    -- Set value to fill the rested section
    restedBar:SetMinMaxValues(0, 1)
    restedBar:SetValue(1)
end

-- ===========================
-- PREVIEW BAR (XP Gain Animation)
-- ===========================

-- Create preview bar (shows where XP will go before main bar animates)
function ns.UI.XP.CreatePreviewBar(mainBar, config)
    if not mainBar then return nil end

    local previewData = {
        config = config
    }

    -- Create preview bar (shows target XP position)
    local previewBar = CreateFrame("StatusBar", nil, mainBar)
    previewBar:SetAllPoints(mainBar)
    previewBar:SetStatusBarTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\g1.tga")
    previewBar:SetFrameLevel(mainBar:GetFrameLevel() + 2)
    previewBar:SetMinMaxValues(0, 100)
    previewBar:SetValue(0)

    -- Set color (bright green for preview)
    local color = config.color or {0.5, 1, 0.5, 0.6}
    previewBar:SetStatusBarColor(color[1], color[2], color[3], color[4])

    -- Initially hide
    previewBar:Hide()

    previewData.bar = previewBar
    return previewData
end

-- Show preview bar at target XP position
function ns.UI.XP.ShowPreview(previewData, targetXP, maxXP)
    if not previewData or not previewData.bar then return end

    local previewBar = previewData.bar
    local config = previewData.config

    -- Cancel any existing fade ticker to prevent multiple animations
    if previewData.fadeTicker then
        previewData.fadeTicker:Cancel()
        previewData.fadeTicker = nil
    end

    -- Set preview bar to show target position
    previewBar:SetMinMaxValues(0, maxXP)
    previewBar:SetValue(targetXP)

    -- Show with fade-in animation
    previewBar:Show()
    previewBar:SetAlpha(0)

    -- Fade in
    local startTime = GetTime()
    local duration = config.duration or 0.3

    -- OPTIMIZED: 0.033s (~30 FPS) instead of 0.01s (100 FPS)
    previewData.fadeTicker = C_Timer.NewTicker(0.033, function()
        local elapsed = GetTime() - startTime
        local progress = math.min(elapsed / duration, 1)

        previewBar:SetAlpha(progress)

        if progress >= 1 then
            previewData.fadeTicker = nil
            return true -- Cancel ticker
        end
    end)
end

-- Hide preview bar with fade-out
function ns.UI.XP.HidePreview(previewData)
    if not previewData or not previewData.bar then return end

    local previewBar = previewData.bar
    local config = previewData.config

    -- Cancel any existing fade ticker to prevent multiple animations
    if previewData.fadeTicker then
        previewData.fadeTicker:Cancel()
        previewData.fadeTicker = nil
    end

    -- Fade out
    local startTime = GetTime()
    local duration = (config.duration or 0.3) * 0.5 -- Fade out faster

    -- OPTIMIZED: 0.033s (~30 FPS) instead of 0.01s (100 FPS)
    previewData.fadeTicker = C_Timer.NewTicker(0.033, function()
        local elapsed = GetTime() - startTime
        local progress = math.min(elapsed / duration, 1)

        previewBar:SetAlpha(1 - progress)

        if progress >= 1 then
            previewBar:Hide()
            previewData.fadeTicker = nil
            return true -- Cancel ticker
        end
    end)
end

-- ===========================
-- SPARK EFFECTS (Inspired by Nihui_cb)
-- ===========================

-- Create spark for XP bar
function ns.UI.XP.CreateSpark(mainBar, config)
    if not mainBar then return nil end

    local spark = mainBar:CreateTexture(nil, "OVERLAY", nil, 6)
    spark:SetTexture(config.texture or "Interface\\AddOns\\Nihui_uf\\textures\\orangespark.tga")
    spark:SetSize(config.size and config.size[1] or 20, config.size and config.size[2] or mainBar:GetHeight() * 1.58)
    spark:SetBlendMode(config.blendMode or "ADD")
    spark:Show()

    return spark
end

-- Update spark position based on XP progress
function ns.UI.XP.UpdateSpark(spark, currentXP, maxXP, barFrame)
    if not spark or not barFrame then return end

    local progress = currentXP / maxXP
    local barWidth = barFrame:GetWidth()
    local sparkPos = barWidth * progress

    spark:ClearAllPoints()
    spark:SetPoint("CENTER", barFrame, "LEFT", sparkPos, 0)
end

-- ===========================
-- REPUTATION BAR EFFECTS
-- ===========================

-- Note: Reputation bars use the same ns.UI.Bar components
-- No special effects needed (no rested, no preview)
-- Just standing-based colors handled in systems/xp.lua

