-- core/stripping_xp.lua - Strip Blizzard XP/Rep bars
local _, ns = ...

-- Stripping namespace
ns.Core = ns.Core or {}
ns.Core.StrippingXP = {}

-- Recursive function to strip all elements from a frame (including nested children)
local function StripFrameCompletely(frame, keepContainer)
    if not frame then return end

    -- Unregister all events
    if frame.UnregisterAllEvents then
        frame:UnregisterAllEvents()
    end

    -- Disable all scripts that could show elements
    if frame.SetScript then
        frame:SetScript("OnShow", nil)
        frame:SetScript("OnHide", nil)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:SetScript("OnUpdate", nil)
        frame:SetScript("OnEvent", nil)
    end

    -- Hide all regions (textures, fonts, etc.) recursively
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.Hide then
            region:Hide()
            region:SetAlpha(0)
            if region.SetTexture then
                region:SetTexture(nil)
            end
        end
    end

    -- Hide all children recursively
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child then
            local childName = child:GetName()
            -- Only hide Blizzard children, not our custom bars
            if not childName or not childName:match("NihuiUF") then
                if child.Hide then
                    child:Hide()
                end
                if child.SetAlpha then
                    child:SetAlpha(0)
                end
                if child.UnregisterAllEvents then
                    child:UnregisterAllEvents()
                end
                -- Recursively strip child's children
                StripFrameCompletely(child, false)
            end
        end
    end

    -- Set the frame itself to invisible if not the main container
    if not keepContainer and frame.SetAlpha then
        frame:SetAlpha(0)
    end
end

-- Strip Main Status Tracking Bar (XP bar)
function ns.Core.StrippingXP.StripMainBar()
    if not MainStatusTrackingBarContainer then
        return
    end

    -- Keep container visible for Edit Mode, but hide Blizzard's content
    -- Container alpha stays at 1.0 so Edit Mode works
    MainStatusTrackingBarContainer:UnregisterAllEvents()

    -- Completely strip all Blizzard elements (recursive)
    StripFrameCompletely(MainStatusTrackingBarContainer, true)
end

-- Strip Secondary Status Tracking Bar (Rep/Honor bar - conditional)
function ns.Core.StrippingXP.StripSecondaryBar()
    if not SecondaryStatusTrackingBarContainer then
        return -- Not always present, skip if doesn't exist
    end

    -- Keep container visible for Edit Mode, but hide Blizzard's content
    -- Container alpha stays at 1.0 so Edit Mode works
    SecondaryStatusTrackingBarContainer:UnregisterAllEvents()

    -- Completely strip all Blizzard elements (recursive)
    StripFrameCompletely(SecondaryStatusTrackingBarContainer, true)
end

-- Strip StatusTrackingBarManager (parent container)
function ns.Core.StrippingXP.StripBarManager()
    if not StatusTrackingBarManager then
        return
    end

    -- Keep manager visible for Edit Mode integration
    -- Just unregister events to prevent Blizzard updates
    StatusTrackingBarManager:UnregisterAllEvents()
end

-- Strip all XP/Rep bars
function ns.Core.StrippingXP.StripAll()
    ns.Core.StrippingXP.StripBarManager()
    ns.Core.StrippingXP.StripMainBar()
    ns.Core.StrippingXP.StripSecondaryBar()
end

-- Restore Blizzard XP/Rep bars (for testing/debugging)
function ns.Core.StrippingXP.RestoreAll()
    if StatusTrackingBarManager then
        StatusTrackingBarManager:SetAlpha(1)
        -- Re-register key events for the manager
        StatusTrackingBarManager:RegisterEvent("PLAYER_ENTERING_WORLD")
        StatusTrackingBarManager:RegisterEvent("PLAYER_XP_UPDATE")
        StatusTrackingBarManager:RegisterEvent("UPDATE_FACTION")
        StatusTrackingBarManager:RegisterEvent("UPDATE_EXHAUSTION")
        StatusTrackingBarManager:RegisterEvent("PLAYER_LEVEL_UP")

        -- Trigger update if it has one
        if StatusTrackingBarManager.UpdateBarsShown then
            StatusTrackingBarManager:UpdateBarsShown()
        end
    end

    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:SetAlpha(1)
        MainStatusTrackingBarContainer:Show()

        -- Show all children that were hidden
        local children = {MainStatusTrackingBarContainer:GetChildren()}
        for _, child in ipairs(children) do
            local childName = child and child:GetName()
            if child and (not childName or not childName:match("NihuiUF")) then
                if child.Show then
                    child:Show()
                end
            end
        end

        -- Show all regions
        local regions = {MainStatusTrackingBarContainer:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.Show then
                region:Show()
            end
        end

        -- Re-register events if the container has any
        if MainStatusTrackingBarContainer.RegisterEvent then
            MainStatusTrackingBarContainer:RegisterEvent("PLAYER_XP_UPDATE")
            MainStatusTrackingBarContainer:RegisterEvent("UPDATE_EXHAUSTION")
            MainStatusTrackingBarContainer:RegisterEvent("PLAYER_LEVEL_UP")
        end
    end

    if SecondaryStatusTrackingBarContainer then
        SecondaryStatusTrackingBarContainer:SetAlpha(1)
        SecondaryStatusTrackingBarContainer:Show()

        -- Show all children that were hidden
        local children = {SecondaryStatusTrackingBarContainer:GetChildren()}
        for _, child in ipairs(children) do
            local childName = child and child:GetName()
            if child and (not childName or not childName:match("NihuiUF")) then
                if child.Show then
                    child:Show()
                end
            end
        end

        -- Show all regions
        local regions = {SecondaryStatusTrackingBarContainer:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.Show then
                region:Show()
            end
        end

        -- Re-register events if the container has any
        if SecondaryStatusTrackingBarContainer.RegisterEvent then
            SecondaryStatusTrackingBarContainer:RegisterEvent("UPDATE_FACTION")
        end
    end

    -- Reload UI to fully restore (Blizzard may need a reload for complete restoration)
    print("|cff00ff00Nihui_uf:|r Blizzard XP/Rep bars restored. /reload recommended for full restoration.")
end

-- Slash command for testing
SLASH_STRIPXP1 = "/stripxp"
SlashCmdList["STRIPXP"] = function(msg)
    if msg == "restore" then
        ns.Core.StrippingXP.RestoreAll()
    else
        ns.Core.StrippingXP.StripAll()
        print("|cff00ff00Nihui_uf:|r XP/Rep bars stripped. Use '/stripxp restore' to restore.")
    end
end
