-- modules/party_new.lua - Party Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Party = {}

-- ===========================
-- PARTY MODULE (NEW API)
-- ===========================

local partyModule = {
    members = {},
    initialized = false,
    config = nil,
    debugMode = false,
    memberFrames = {} -- For debug mode
}

-- Initialize party module
function partyModule:Initialize()
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

    -- Get party configuration
    self.config = ns.DB.GetUnitConfig("party")
    if not self.config then
        return
    end

    -- Initialize debug mode if enabled
    if self.config.debug and self.config.debug.enabled then
        self:EnableDebugMode()
    else
        self:InitializeRealParty()
    end

    self.initialized = true
end

-- OPTIMIZED: Initialize real party frames with incremental updates instead of full recreation
function partyModule:InitializeRealParty()
    -- OPTIMIZED: Incremental update strategy instead of CLEAR AND RECREATE
    -- Only create/update frames that actually changed
    -- This prevents massive stuttering from constant frame destruction/recreation

    for i = 1, 4 do
        local unitToken = "party" .. i
        local member = self.members[i]

        if UnitExists(unitToken) then
            -- Unit exists: create if needed, otherwise just update
            if not member or not member.unitFrame then
                -- Create new member frame
                local partyUnit = "Party" .. i

                -- Clear portrait cache only for NEW frames
                if ns.Systems and ns.Systems.Portrait then
                    if ns.Systems.Portrait.ClearPortraitCache then
                        ns.Systems.Portrait.ClearPortraitCache(partyUnit)
                    end
                    if ns.Systems.Portrait.RemovePortraitFrame then
                        ns.Systems.Portrait.RemovePortraitFrame(partyUnit)
                    end
                end

                member = self:CreateMember(i, unitToken, nil)
            end

            -- Update existing frame (much cheaper than recreation)
            if member and member.unitFrame then
                -- Show frame if hidden
                if member.frame then
                    member.frame:Show()
                end

                -- Update all systems (lightweight compared to recreation)
                if member.unitFrame.healthSystem and member.unitFrame.healthSystem.UpdateHealth then
                    member.unitFrame.healthSystem:UpdateHealth()
                end

                if member.unitFrame.powerSystem and member.unitFrame.powerSystem.UpdatePower then
                    member.unitFrame.powerSystem:UpdatePower()
                end

                if member.unitFrame.textSystem and member.unitFrame.textSystem.UpdateAll then
                    member.unitFrame.textSystem:UpdateAll()
                end

                -- Update portrait only if unit GUID changed (cached in portrait system now)
                if member.unitFrame.portraitSystem and member.unitFrame.portraitSystem.UpdatePortrait then
                    member.unitFrame.portraitSystem:UpdatePortrait()
                end
            end
        else
            -- Unit doesn't exist: hide frame instead of destroying
            if member and member.frame then
                member.frame:Hide()
            end
        end
    end
end

-- Enable debug mode (fake party members for testing)
function partyModule:EnableDebugMode()
    self.debugMode = true

    local memberCount = self.config.debug.memberCount or 4

    -- Clear any existing members
    self:ClearMembers()

    -- Create debug frames
    for i = 1, memberCount do
        self:CreateDebugMember(i)
    end

end

-- Create a real party member
function partyModule:CreateMember(index, unitToken, parentFrame)

    -- Try to find the real Blizzard party frame first (might exist now that we're in a group)
    local blizzardFrame = parentFrame
    if not blizzardFrame and _G["PartyFrame"] then
        blizzardFrame = _G["PartyFrame"]["MemberFrame" .. index]
    end

    -- If still no frame, create our fallback and schedule migration attempt
    if not blizzardFrame then
        blizzardFrame = CreateFrame("Frame", "NihuiUF_PartyMember" .. index .. "_Parent", UIParent)
        blizzardFrame:SetSize(120, 40) -- Size similar to party frames
        -- Initial position will be set by PositionMember
        blizzardFrame:Show()

        -- Make the frame look like a party frame for testing
        local bg = blizzardFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3) -- Semi-transparent dark background

        -- Mark it as fallback for potential migration later
        blizzardFrame._nihuiUFFallback = true

        -- Mark for migration when Blizzard frames become available
        self:MarkForBlizzardFrameMigration(index, unitToken)
    end

    -- Create unitframe using API (party1, party2, etc.)
    local unitFrame = ns.API.UnitFrame.Create(blizzardFrame, unitToken)
    if not unitFrame then
        return nil
    end

    -- Store member info
    local member = {
        index = index,
        unitToken = unitToken,
        unitFrame = unitFrame,
        parentFrame = blizzardFrame,
        isOffline = false -- Initialize as online
    }

    self.members[index] = member

    -- Check if member is actually online after creation
    if not UnitIsConnected(unitToken) then
        self:SetMemberOffline(member)
    else
    end

    -- Apply position to control spacing between members
    self:PositionMember(member, index)

    return member
end

-- Mark member for migration when Blizzard frames become available
function partyModule:MarkForBlizzardFrameMigration(index, unitToken)
    -- Simply mark - actual migration happens on GROUP_ROSTER_UPDATE event
    if not self.pendingMigrations then
        self.pendingMigrations = {}
    end
    self.pendingMigrations[index] = unitToken
end

-- Try to migrate all pending members to real Blizzard frames
function partyModule:TryPendingMigrations()
    if not self.pendingMigrations then
        return
    end

    for index, unitToken in pairs(self.pendingMigrations) do
        local realBlizzardFrame = nil
        if _G["PartyFrame"] and _G["PartyFrame"]["MemberFrame" .. index] then
            realBlizzardFrame = _G["PartyFrame"]["MemberFrame" .. index]
        end

        if realBlizzardFrame then
            self:MigrateToBlizzardFrame(index, unitToken, realBlizzardFrame)
            self.pendingMigrations[index] = nil -- Remove from pending
        end
    end
end

-- Migrate existing member from fallback frame to real Blizzard frame
function partyModule:MigrateToBlizzardFrame(index, unitToken, realBlizzardFrame)
    local member = self.members[index]
    if not member or not member.parentFrame or not member.parentFrame._nihuiUFFallback then
        return
    end

    -- Hide and destroy old fallback frame
    if member.parentFrame then
        member.parentFrame:Hide()
        member.parentFrame = nil
    end

    -- Create new unitframe with real Blizzard parent
    local newUnitFrame = ns.API.UnitFrame.Create(realBlizzardFrame, unitToken)
    if not newUnitFrame then
        return
    end

    -- Update member reference
    member.unitFrame = newUnitFrame
    member.parentFrame = realBlizzardFrame
    member.parentFrame._nihuiUFFallback = nil -- No longer a fallback

    -- Apply position to control spacing between members
    self:PositionMember(member, index)

    -- Check connection status and update accordingly
    if not UnitIsConnected(unitToken) then
        self:SetMemberOffline(member)
    else
        self:SetMemberOnline(member)
    end
end

-- Create a debug member (fake frame for testing)
function partyModule:CreateDebugMember(index)

    -- Create a mock frame for debug mode
    local mockFrame = CreateFrame("Frame", "NihuiUF_DebugPartyMember" .. index, UIParent)
    mockFrame:SetSize(200, 50)
    -- Initial position will be set by PositionMember

    -- Create unitframe using API with "party" as base type
    local unitFrame = ns.API.UnitFrame.Create(mockFrame, "party")
    if not unitFrame then
        return nil
    end

    -- Store member info
    local member = {
        index = index,
        unitToken = "party" .. index, -- For reference, but uses "party" config
        unitFrame = unitFrame,
        parentFrame = mockFrame,
        isDebug = true
    }

    self.members[index] = member
    self.memberFrames[index] = mockFrame

    -- Apply position from config
    self:PositionMember(member, index)

    -- Enable dragging in debug mode
    if self.config.debug.dragMode then
        self:EnableMemberDragging(member)
    end

    return member
end

-- Position a party member frame using relative positioning with gap
function partyModule:PositionMember(member, index)
    if not member or not member.parentFrame then return end

    local gap = self.config.gap or 60

    -- For MemberFrame1: keep Blizzard's default position (don't reposition)
    -- For others: anchor relative to previous ACTIVE member with configurable gap
    if index == 1 then
        -- Don't reposition party1, let Blizzard handle it
        -- (unless it's a debug/fallback frame)
        if member.isDebug or member.parentFrame._nihuiUFFallback then
            member.parentFrame:ClearAllPoints()
            member.parentFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -200)
        end
    else
        -- Find the first active (non-offline) member before this one
        local anchorMember = nil
        for i = index - 1, 1, -1 do
            local candidateMember = self.members[i]
            if candidateMember and candidateMember.parentFrame and not candidateMember.isOffline then
                anchorMember = candidateMember
                break
            end
        end

        -- Position relative to the found active member, or to party1's position if none found
        if anchorMember and anchorMember.parentFrame then
            member.parentFrame:ClearAllPoints()
            member.parentFrame:SetPoint("TOP", anchorMember.parentFrame, "BOTTOM", 0, -gap)
        elseif index > 1 then
            -- Fallback: anchor to first member's position if no active member found before us
            local firstMember = self.members[1]
            if firstMember and firstMember.parentFrame then
                member.parentFrame:ClearAllPoints()
                member.parentFrame:SetPoint("TOP", firstMember.parentFrame, "BOTTOM", 0, -gap)
            end
        end
    end
end

-- Reposition all party members (called after member goes offline/online)
function partyModule:RepositionAllMembers()
    -- Reposition all existing members in order
    for index = 1, 4 do
        local member = self.members[index]
        if member then
            self:PositionMember(member, index)
        end
    end
end

-- Apply gap changes to all party members
function partyModule:ApplyGap()
    -- Get updated config
    self.config = ns.DB.GetUnitConfig("party")

    -- Reposition all existing members
    self:RepositionAllMembers()
end

-- Enable dragging for a member (debug mode)
function partyModule:EnableMemberDragging(member)
    if not member or not member.parentFrame then return end

    member.parentFrame:SetMovable(true)
    member.parentFrame:EnableMouse(true)
    member.parentFrame:RegisterForDrag("LeftButton")

    member.parentFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    member.parentFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

end

-- Set member as offline instead of destroying
function partyModule:SetMemberOffline(member)
    if not member then
        return
    end

    if not member.unitFrame then
        return
    end


    -- Grey out health and power bars using Bar API
    if member.unitFrame.healthSystem and member.unitFrame.healthSystem.bar then
        -- Set value to 0 first, then apply grey color
        ns.UI.Bar.SetValue(member.unitFrame.healthSystem.bar, 0)
        ns.UI.Bar.SetColor(member.unitFrame.healthSystem.bar, 0.5, 0.5, 0.5, 0.8)
    else
    end

    if member.unitFrame.powerSystem and member.unitFrame.powerSystem.bar then
        -- Set value to 0 first, then apply dark grey color
        ns.UI.Bar.SetValue(member.unitFrame.powerSystem.bar, 0)
        ns.UI.Bar.SetColor(member.unitFrame.powerSystem.bar, 0.3, 0.3, 0.3, 0.8)
    else
    end

    -- Show offline icon (red X) properly centered
    if not member.offlineIcon then
        local healthFrame = member.unitFrame.healthSystem and member.unitFrame.healthSystem.bar
        if healthFrame then
            -- Create icon as child of health bar for proper centering
            member.offlineIcon = healthFrame:CreateTexture(nil, "OVERLAY", nil, 7) -- High sublevel
            member.offlineIcon:SetSize(32, 32) -- Bigger for better visibility
            member.offlineIcon:SetPoint("CENTER", healthFrame, "CENTER", 0, 0) -- Perfectly centered

            -- Use a better offline icon
            member.offlineIcon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
            member.offlineIcon:SetVertexColor(1, 0.3, 0.3, 1) -- Red tint

        end
    end

    if member.offlineIcon then
        member.offlineIcon:Show()
    end

    -- Hide the frame when offline (instead of just greying out)
    if member.parentFrame then
        member.parentFrame:Hide()
    end

    -- Mark as offline
    member.isOffline = true

    -- Reposition all members after this one to fill the gap
    self:RepositionAllMembers()
end

-- Set member as online
function partyModule:SetMemberOnline(member)
    if not member or not member.unitFrame then return end


    -- Hide offline icon
    if member.offlineIcon then
        member.offlineIcon:Hide()
    end

    -- Show the frame when online
    if member.parentFrame then
        member.parentFrame:Show()
    end

    -- Mark as online
    member.isOffline = false

    -- Force immediate update to restore colors and values
    if member.unitFrame.healthSystem then
        member.unitFrame.healthSystem:UpdateHealth()
    end

    if member.unitFrame.powerSystem then
        member.unitFrame.powerSystem:UpdatePower()
    end

    -- Reposition all members to account for this member coming back online
    self:RepositionAllMembers()

end

-- BRUTAL CLEAN: Destroy all UI elements we created on parent frame
function partyModule:BrutalCleanParentFrame(parentFrame)
    if not parentFrame then return end

    -- Get all children frames
    local children = {parentFrame:GetChildren()}
    for _, child in ipairs(children) do
        local childName = child:GetName()
        -- Destroy frames we created (Nihui prefix or anonymous frames we made)
        -- BUT preserve Blizzard's native frames (no Nihui prefix and has a Blizzard name)
        if not childName or childName:match("^Nihui") then
            child:Hide()
            child:SetParent(nil)
            child:ClearAllPoints()
        end
    end

    -- Get all regions (textures, fontstrings)
    local regions = {parentFrame:GetRegions()}
    for _, region in ipairs(regions) do
        if region:IsObjectType("Texture") or region:IsObjectType("FontString") then
            -- Don't destroy regions that are part of Blizzard's frame structure
            local parent = region:GetParent()
            if parent == parentFrame then
                region:Hide()
                if region.SetAlpha then
                    region:SetAlpha(0)
                end
            end
        end
    end
end

-- Destroy all members completely (for real party refresh)
function partyModule:DestroyAllMembers()
    for index, member in pairs(self.members) do
        -- BRUTAL CLEAN: Destroy ALL our UI elements from parent frame
        if member.parentFrame then
            self:BrutalCleanParentFrame(member.parentFrame)
        end

        -- Clear offline icon if exists
        if member.offlineIcon then
            member.offlineIcon:Hide()
            member.offlineIcon = nil
        end

        -- Hide parent frame (don't destroy Blizzard frames)
        if member.parentFrame then
            member.parentFrame:Hide()
            -- Only destroy fallback frames we created
            if member.parentFrame._nihuiUFFallback then
                member.parentFrame:SetParent(nil)
                member.parentFrame = nil
            end
        end

        -- Clear unitFrame reference
        member.unitFrame = nil
    end

    -- Clear members table
    self.members = {}
end

-- Clear all members - now sets them offline instead of destroying
function partyModule:ClearMembers()
    for index, member in pairs(self.members) do
        if member.unitFrame then
            self:SetMemberOffline(member)
        end

        -- Only destroy debug frames
        if member.isDebug and self.memberFrames[index] then
            self.memberFrames[index]:Hide()
            self.memberFrames[index] = nil
        end
    end

    self.members = {}
end

-- Update all party members
function partyModule:Update()
    if not self.initialized then return end

    for _, member in pairs(self.members) do
        if member.unitFrame then
            if member.unitFrame.healthSystem then
                member.unitFrame.healthSystem:UpdateHealth()
            end
            if member.unitFrame.powerSystem then
                member.unitFrame.powerSystem:UpdatePower()
            end
        end
    end

end

-- Refresh party frames (for config changes)
function partyModule:RefreshFrames()

    -- Update config
    self.config = ns.DB.GetUnitConfig("party")

    -- Recreate frames with new config
    if self.debugMode or (self.config.debug and self.config.debug.enabled) then
        self:EnableDebugMode()
    else
        self:InitializeRealParty()
    end
end

-- Toggle debug mode
function partyModule:ToggleTestMode(enabled)
    self.debugMode = enabled

    if enabled then
        self:EnableDebugMode()
    else
        self:InitializeRealParty()
    end

end

-- Toggle drag mode for debug frames
function partyModule:ToggleDragMode(enabled)
    if not self.debugMode then return end

    for _, member in pairs(self.members) do
        if member.isDebug then
            if enabled then
                self:EnableMemberDragging(member)
            else
                if member.parentFrame then
                    member.parentFrame:SetScript("OnDragStart", nil)
                    member.parentFrame:SetScript("OnDragStop", nil)
                    member.parentFrame:EnableMouse(false)
                end
            end
        end
    end

end

-- Update visibility based on group status
function partyModule:UpdateVisibility()
    if self.debugMode then
        -- In debug mode, always show
        for _, member in pairs(self.members) do
            if member.parentFrame then
                member.parentFrame:Show()
            end
        end
        return
    end

    -- In real mode, show/hide based on group membership
    -- IMPORTANT: Hide party when in raid (raid frames take over)
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()

    for index, member in pairs(self.members) do
        if member.parentFrame then
            local unitExists = UnitExists(member.unitToken)
            -- Hide if in raid OR if not in group OR if unit doesn't exist
            if inRaid or not inGroup or not unitExists then
                member.parentFrame:Hide()
            else
                member.parentFrame:Show()
            end
        end
    end

end

-- Cleanup
function partyModule:Destroy()
    self:DestroyAllMembers()
    self.config = nil
    self.debugMode = false
    self.initialized = false
end

-- Get party member by index
function partyModule:GetMember(index)
    return self.members[index]
end

-- Get all members
function partyModule:GetMembers()
    return self.members
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Party.Setup = ns.CreateModuleSetup(partyModule)

-- Public API
ns.Modules.Party.Initialize = function()
    return partyModule:Initialize()
end

ns.Modules.Party.Update = function()
    return partyModule:Update()
end

ns.Modules.Party.Destroy = function()
    return partyModule:Destroy()
end

ns.Modules.Party.RefreshFrames = function()
    return partyModule:RefreshFrames()
end

ns.Modules.Party.ToggleTestMode = function(enabled)
    return partyModule:ToggleTestMode(enabled)
end

ns.Modules.Party.ToggleDragMode = function(enabled)
    return partyModule:ToggleDragMode(enabled)
end

ns.Modules.Party.UpdateVisibility = function()
    return partyModule:UpdateVisibility()
end

ns.Modules.Party.GetMember = function(index)
    return partyModule:GetMember(index)
end

ns.Modules.Party.GetMembers = function()
    return partyModule:GetMembers()
end

ns.Modules.Party.ApplyGap = function()
    return partyModule:ApplyGap()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for party-specific events
local eventFrame = CreateFrame("Frame")

-- Handle party-specific events only (ADDON_LOADED managed by init.lua)
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGIN")  -- For initial UI setup when PartyFrame is available
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_CONNECTION")  -- For connection changes

-- OPTIMIZED: Throttle GROUP_ROSTER_UPDATE to prevent spam
local lastRosterUpdate = 0
local ROSTER_UPDATE_THROTTLE = 0.1  -- Max once per 0.1s

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        -- OPTIMIZED: Throttle to prevent excessive updates during roster spam
        local now = GetTime()
        if now - lastRosterUpdate < ROSTER_UPDATE_THROTTLE then
            return
        end
        lastRosterUpdate = now

        -- Auto-update when group changes
        if partyModule.initialized then
            if not partyModule.debugMode then
                partyModule:InitializeRealParty()
            end
            partyModule:UpdateVisibility()
            -- Try pending migrations after group changes
            partyModule:TryPendingMigrations()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Try pending migrations when UI is fully initialized and PartyFrame is available
        C_Timer.After(1, function()
            if partyModule.initialized then
                partyModule:TryPendingMigrations()
            end
        end)
    elseif event == "UNIT_CONNECTION" then
        local unitToken = ...

        -- Check if it's a party member
        if unitToken and unitToken:match("^party%d$") and partyModule.initialized and not partyModule.debugMode then
            partyModule:InitializeRealParty()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Auto-update on world enter
        C_Timer.After(1, function()
            if partyModule.initialized then
                partyModule:UpdateVisibility()
                partyModule:Update()
            end
        end)
    end
end)

