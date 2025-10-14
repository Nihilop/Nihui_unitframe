-- modules/raid.lua - Raid Module using Unified API
local _, ns = ...

-- Module namespace
ns.Modules = ns.Modules or {}
ns.Modules.Raid = {}

-- ===========================
-- RAID MODULE (NEW API)
-- ===========================

local raidModule = {
    members = {},      -- Flat array of all members (raid1-raid40)
    groups = {},       -- Organized by groups: groups[1-8][1-5]
    initialized = false,
    config = nil,
    debugMode = false,
    memberFrames = {} -- For debug mode
}

-- Hide Blizzard raid frame manager (but preserve container and member frames for click handlers)
function raidModule:HideBlizzardRaidManager()
    if CompactRaidFrameManager then
        if CompactRaidFrameManager.displayFrame then
            CompactRaidFrameManager.displayFrame:Hide()
        end
        if CompactRaidFrameManager.container then
            CompactRaidFrameManager.container:Hide()
        end
        CompactRaidFrameManager:SetAlpha(0)
    end
end

-- Initialize raid module
function raidModule:Initialize()
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

    -- Get raid configuration
    self.config = ns.DB.GetUnitConfig("raid")
    if not self.config then
        print("|cffff0000Nihui_uf RAID ERROR:|r No config found!")
        return
    end

    -- Hide Blizzard raid frame manager (we only use individual frames)
    self:HideBlizzardRaidManager()

    -- Initialize debug mode if enabled
    if self.config.debug and self.config.debug.enabled then
        self:EnableDebugMode()
    else
        self:InitializeRealRaid()
    end

    self.initialized = true

    -- Hide party frames when raid is active
    if ns.Modules and ns.Modules.Party and ns.Modules.Party.UpdateVisibility then
        ns.Modules.Party.UpdateVisibility()
    end
end

-- Initialize real raid frames (when actually in a raid)
function raidModule:InitializeRealRaid()
    -- Detect Blizzard raid frame layout mode by checking which frames exist
    local hasCombinedFrames = _G["CompactRaidFrame1"] ~= nil
    local hasSeparatedFrames = _G["CompactRaidGroup1Member1"] ~= nil

    local useCombinedMode
    if hasSeparatedFrames then
        useCombinedMode = false
    elseif hasCombinedFrames then
        useCombinedMode = true
    else
        useCombinedMode = true  -- Default to Combined mode
    end

    self.useCombinedMode = useCombinedMode

    -- Strip group containers in Separated mode (remove borders/backgrounds)
    if not useCombinedMode then
        for i = 1, 8 do
            local groupFrame = _G["CompactRaidGroup" .. i]
            if groupFrame then
                self:StripBlizzardGroupContainer(groupFrame)
            end
        end
    end

    -- Force Blizzard to create raid frames if they don't exist yet
    if not CompactRaidFrameContainer or not CompactRaidFrameContainer:IsShown() then
        -- Force Blizzard to show raid frames
        if CompactRaidFrameManager_SetSetting then
            CompactRaidFrameManager_SetSetting("IsShown", "1")
        end

        if CompactRaidFrameContainer then
            CompactRaidFrameContainer:Show()
        end

        -- Retry after frames are created
        C_Timer.After(0.5, function()
            self:InitializeRealRaid()
        end)
        return
    end

    -- Check existing members and update their status
    for i = 1, 40 do
        local unitToken = "raid" .. i
        local existingMember = self.members[i]
        local unitExists = UnitExists(unitToken)

        if unitExists then
            local isConnected = UnitIsConnected(unitToken)

            if existingMember then
                -- Member exists - check connection status
                if isConnected and existingMember.isOffline then
                    self:SetMemberOnline(existingMember)
                elseif not isConnected and not existingMember.isOffline then
                    self:SetMemberOffline(existingMember)
                end
            else
                -- New member - create frame
                self:CreateMember(i, unitToken, nil)
            end
        else
            if existingMember and not existingMember.isOffline then
                -- Member doesn't exist anymore - mark as offline
                self:SetMemberOffline(existingMember)
            end
        end
    end
end

-- Strip Blizzard raid group container (CompactRaidGroup1, CompactRaidGroup2, etc.)
function raidModule:StripBlizzardGroupContainer(groupFrame)
    if not groupFrame then return end

    if groupFrame.title then groupFrame.title:Hide() end
    if groupFrame.background and groupFrame.background.SetAlpha then groupFrame.background:SetAlpha(0) end
    if groupFrame.borderFrame and groupFrame.borderFrame.SetAlpha then groupFrame.borderFrame:SetAlpha(0) end

    -- Hide any other visual elements
    for _, region in pairs({groupFrame:GetRegions()}) do
        if region:IsObjectType("Texture") and region ~= groupFrame then
            region:SetAlpha(0)
        end
    end
end

-- Strip Blizzard raid frame elements (preserve frame structure and click handlers)
function raidModule:StripBlizzardRaidFrame(frame)
    if not frame then return end

    -- Hide health/power bars
    if frame.healthBar then
        if frame.healthBar.SetAlpha then frame.healthBar:SetAlpha(0) end
        if frame.healthBar.UnregisterAllEvents then frame.healthBar:UnregisterAllEvents() end
    end

    if frame.powerBar then
        if frame.powerBar.SetAlpha then frame.powerBar:SetAlpha(0) end
        if frame.powerBar.UnregisterAllEvents then frame.powerBar:UnregisterAllEvents() end
    end

    -- Hide text elements
    if frame.name then
        if frame.name.Hide then frame.name:Hide() end
        if frame.name.SetAlpha then frame.name:SetAlpha(0) end
    end
    if frame.statusText and frame.statusText.Hide then frame.statusText:Hide() end

    -- Hide background and borders
    if frame.background and frame.background.SetAlpha then frame.background:SetAlpha(0) end
    if frame.border and frame.border.SetAlpha then frame.border:SetAlpha(0) end

    -- Hide role icon (we create our own)
    if frame.roleIcon and frame.roleIcon.Hide then frame.roleIcon:Hide() end
end

-- Enable debug mode (fake raid members for testing)
function raidModule:EnableDebugMode()
    self.debugMode = true

    local memberCount = self.config.debug.memberCount or 10

    -- Clear any existing members
    self:ClearMembers()

    -- Create debug frames
    for i = 1, memberCount do
        self:CreateDebugMember(i)
    end
end

-- Create a real raid member
function raidModule:CreateMember(index, unitToken, parentFrame)
    -- Try to find the real Blizzard raid frame first using direct naming
    local blizzardFrame = parentFrame
    if not blizzardFrame then
        local frameName

        if self.useCombinedMode then
            -- Combined Groups mode: CompactRaidFrame1, CompactRaidFrame2, etc.
            frameName = "CompactRaidFrame" .. index
        else
            -- Separated Groups mode: CompactRaidGroup1Member1, CompactRaidGroup2Member3, etc.
            local layout = self.config.layout or {}
            local membersPerGroup = layout.membersPerGroup or 5
            local groupIndex = math.floor((index - 1) / membersPerGroup) + 1
            local memberIndexInGroup = ((index - 1) % membersPerGroup) + 1
            frameName = "CompactRaidGroup" .. groupIndex .. "Member" .. memberIndexInGroup
        end

        blizzardFrame = _G[frameName]
    end

    -- If still no frame, create our fallback (for testing when not in raid or raid frames not loaded)
    if not blizzardFrame then
        local frameWidth = self.config.health and self.config.health.width or 80
        local frameHeight = self.config.health and self.config.health.height or 24

        blizzardFrame = CreateFrame("Frame", "NihuiUF_RaidMember" .. index .. "_Parent", UIParent)
        blizzardFrame:SetSize(frameWidth, frameHeight)
        blizzardFrame:Show()

        -- Make the frame look like a raid frame for testing
        local bg = blizzardFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0.2, 0, 0.3)

        -- Mark it as fallback for potential migration later
        blizzardFrame._nihuiUFFallback = true
        blizzardFrame.unit = unitToken

        -- Mark for migration when Blizzard frames become available
        self:MarkForBlizzardFrameMigration(index, unitToken)
    else
        -- Found real Blizzard frame - strip visual elements
        self:StripBlizzardRaidFrame(blizzardFrame)
    end

    -- Create unitframe using API
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
        isOffline = false,
        isBlizzardFrame = (blizzardFrame._nihuiUFFallback ~= true)
    }

    self.members[index] = member

    -- Check if member is actually online after creation
    if not UnitIsConnected(unitToken) then
        self:SetMemberOffline(member)
    end

    return member
end

-- Mark member for migration when Blizzard frames become available
function raidModule:MarkForBlizzardFrameMigration(index, unitToken)
    if not self.pendingMigrations then
        self.pendingMigrations = {}
    end
    self.pendingMigrations[index] = unitToken
end

-- Try to migrate all pending members to real Blizzard frames
function raidModule:TryPendingMigrations()
    if not self.pendingMigrations then
        return
    end

    local layout = self.config.layout or {}
    local membersPerGroup = layout.membersPerGroup or 5

    for index, unitToken in pairs(self.pendingMigrations) do
        local realBlizzardFrame = nil

        -- Calculate group and member position
        local groupIndex = math.floor((index - 1) / membersPerGroup) + 1
        local memberIndexInGroup = ((index - 1) % membersPerGroup) + 1

        -- Use CompactRaid frame naming: CompactRaidGroup1Member1, etc.
        local frameName = "CompactRaidGroup" .. groupIndex .. "Member" .. memberIndexInGroup
        realBlizzardFrame = _G[frameName]

        if realBlizzardFrame then
            print("Nihui_uf RAID: Migrating", unitToken, "to", frameName)
            self:MigrateToBlizzardFrame(index, unitToken, realBlizzardFrame)
            self.pendingMigrations[index] = nil
        end
    end
end

-- Migrate existing member from fallback frame to real Blizzard frame
function raidModule:MigrateToBlizzardFrame(index, unitToken, realBlizzardFrame)
    local member = self.members[index]
    if not member or not member.parentFrame or not member.parentFrame._nihuiUFFallback then
        return
    end

    -- Hide and destroy old fallback frame
    if member.parentFrame then
        member.parentFrame:Hide()
        member.parentFrame = nil
    end

    -- Strip Blizzard frame elements before using it
    self:StripBlizzardRaidFrame(realBlizzardFrame)

    -- Create new unitframe with real Blizzard parent
    local newUnitFrame = ns.API.UnitFrame.Create(realBlizzardFrame, unitToken)
    if not newUnitFrame then
        return
    end

    -- Update member reference
    member.unitFrame = newUnitFrame
    member.parentFrame = realBlizzardFrame
    member.isBlizzardFrame = true

    -- Check connection status and update accordingly
    if not UnitIsConnected(unitToken) then
        self:SetMemberOffline(member)
    else
        self:SetMemberOnline(member)
    end
end

-- Create a debug member (fake frame for testing)
function raidModule:CreateDebugMember(index)
    local frameWidth = self.config.health and self.config.health.width or 80
    local frameHeight = self.config.health and self.config.health.height or 24

    -- Create a mock frame for debug mode
    local mockFrame = CreateFrame("Frame", "NihuiUF_DebugRaidMember" .. index, UIParent)
    mockFrame:SetSize(frameWidth, frameHeight)

    -- Create unitframe using API with "raid" as base type
    local unitFrame = ns.API.UnitFrame.Create(mockFrame, "raid")
    if not unitFrame then
        return nil
    end

    -- Store member info
    local member = {
        index = index,
        unitToken = "raid" .. index,
        unitFrame = unitFrame,
        parentFrame = mockFrame,
        isDebug = true
    }

    self.members[index] = member
    self.memberFrames[index] = mockFrame

    -- Position for debug
    mockFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50 + ((index-1) % 5) * 85, -200 - math.floor((index-1) / 5) * 30)

    -- Enable dragging in debug mode
    if self.config.debug.dragMode then
        self:EnableMemberDragging(member)
    end

    return member
end

-- Refresh all raid members with updated config (called from config panel)
function raidModule:RefreshAllMembers()
    self.config = ns.DB.GetUnitConfig("raid")

    -- Refresh each member's unitframe
    for index, member in pairs(self.members) do
        if member.unitFrame and member.unitFrame.UpdateConfig then
            member.unitFrame:UpdateConfig()
        end
    end
end

-- Enable dragging for a member (debug mode)
function raidModule:EnableMemberDragging(member)
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
function raidModule:SetMemberOffline(member)
    if not member or not member.unitFrame then
        return
    end

    -- Grey out health and power bars using Bar API
    if member.unitFrame.healthSystem and member.unitFrame.healthSystem.bar then
        ns.UI.Bar.SetValue(member.unitFrame.healthSystem.bar, 0)
        ns.UI.Bar.SetColor(member.unitFrame.healthSystem.bar, 0.5, 0.5, 0.5, 0.8)
    end

    if member.unitFrame.powerSystem and member.unitFrame.powerSystem.bar then
        ns.UI.Bar.SetValue(member.unitFrame.powerSystem.bar, 0)
        ns.UI.Bar.SetColor(member.unitFrame.powerSystem.bar, 0.3, 0.3, 0.3, 0.8)
    end

    -- Show offline icon
    if not member.offlineIcon then
        local healthFrame = member.unitFrame.healthSystem and member.unitFrame.healthSystem.bar
        if healthFrame then
            member.offlineIcon = healthFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            member.offlineIcon:SetSize(24, 24) -- Smaller for raid frames
            member.offlineIcon:SetPoint("CENTER", healthFrame, "CENTER", 0, 0)
            member.offlineIcon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
            member.offlineIcon:SetVertexColor(1, 0.3, 0.3, 1)
        end
    end

    if member.offlineIcon then
        member.offlineIcon:Show()
    end

    member.isOffline = true
end

-- Set member as online
function raidModule:SetMemberOnline(member)
    if not member or not member.unitFrame then return end

    -- Hide offline icon
    if member.offlineIcon then
        member.offlineIcon:Hide()
    end

    member.isOffline = false

    -- Force immediate update to restore colors and values
    if member.unitFrame.healthSystem then
        member.unitFrame.healthSystem:UpdateHealth()
    end

    if member.unitFrame.powerSystem then
        member.unitFrame.powerSystem:UpdatePower()
    end
end

-- Clear all members
function raidModule:ClearMembers()
    for index, member in pairs(self.members) do
        if member.unitFrame then
            self:SetMemberOffline(member)
        end

        -- Clean up role indicator
        if member.roleIcon then
            member.roleIcon:Hide()
            member.roleIcon = nil
        end

        -- Only destroy debug frames
        if member.isDebug and self.memberFrames[index] then
            self.memberFrames[index]:Hide()
            self.memberFrames[index] = nil
        end
    end

    self.members = {}
end

-- Update all raid members
function raidModule:Update()
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

-- Refresh raid frames (for config changes)
function raidModule:RefreshFrames()
    -- Update config
    self.config = ns.DB.GetUnitConfig("raid")

    -- Recreate frames with new config
    if self.debugMode or (self.config.debug and self.config.debug.enabled) then
        self:EnableDebugMode()
    else
        self:InitializeRealRaid()
    end
end

-- Toggle debug mode
function raidModule:ToggleTestMode(enabled)
    self.debugMode = enabled

    if enabled then
        self:EnableDebugMode()
    else
        self:InitializeRealRaid()
    end
end

-- Toggle drag mode for debug frames
function raidModule:ToggleDragMode(enabled)
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
function raidModule:UpdateVisibility()
    if self.debugMode then
        -- In debug mode, always show
        for _, member in pairs(self.members) do
            if member.parentFrame then
                member.parentFrame:Show()
            end
        end
        return
    end

    -- In real mode, show/hide based on raid membership
    local inRaid = IsInRaid()

    for index, member in pairs(self.members) do
        if member.parentFrame then
            local unitExists = UnitExists(member.unitToken)
            if inRaid and unitExists then
                member.parentFrame:Show()
            else
                member.parentFrame:Hide()
            end
        end
    end
end

-- Cleanup
function raidModule:Destroy()
    self:ClearMembers()
    self.config = nil
    self.debugMode = false
    self.initialized = false
end

-- Get raid member by index
function raidModule:GetMember(index)
    return self.members[index]
end

-- Get all members
function raidModule:GetMembers()
    return self.members
end

-- ===========================
-- MODULE INTERFACE
-- ===========================

-- Setup method for lifecycle compatibility
ns.Modules.Raid.Setup = ns.CreateModuleSetup(raidModule)

-- Public API
ns.Modules.Raid.Initialize = function()
    return raidModule:Initialize()
end

ns.Modules.Raid.Update = function()
    return raidModule:Update()
end

ns.Modules.Raid.Destroy = function()
    return raidModule:Destroy()
end

ns.Modules.Raid.RefreshFrames = function()
    return raidModule:RefreshFrames()
end

ns.Modules.Raid.ToggleTestMode = function(enabled)
    return raidModule:ToggleTestMode(enabled)
end

ns.Modules.Raid.ToggleDragMode = function(enabled)
    return raidModule:ToggleDragMode(enabled)
end

ns.Modules.Raid.UpdateVisibility = function()
    return raidModule:UpdateVisibility()
end

ns.Modules.Raid.GetMember = function(index)
    return raidModule:GetMember(index)
end

ns.Modules.Raid.GetMembers = function()
    return raidModule:GetMembers()
end

ns.Modules.Raid.RefreshAllMembers = function()
    return raidModule:RefreshAllMembers()
end

-- ===========================
-- EVENT HANDLING
-- ===========================

-- Event frame for raid-specific events
local eventFrame = CreateFrame("Frame")

-- Handle raid-specific events
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_CONNECTION")
eventFrame:RegisterEvent("COMPACT_UNIT_FRAME_PROFILES_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Auto-update when group changes
        if raidModule.initialized then
            if not raidModule.debugMode then
                raidModule:InitializeRealRaid()
            end
            raidModule:UpdateVisibility()
            -- Try pending migrations after group changes
            raidModule:TryPendingMigrations()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Try pending migrations when UI is fully initialized
        C_Timer.After(1, function()
            if raidModule.initialized then
                raidModule:TryPendingMigrations()
            end
        end)
    elseif event == "UNIT_CONNECTION" then
        local unitToken = ...

        -- Check if it's a raid member
        if unitToken and unitToken:match("^raid%d+$") and raidModule.initialized and not raidModule.debugMode then
            raidModule:InitializeRealRaid()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Auto-update on world enter
        C_Timer.After(1, function()
            if raidModule.initialized then
                raidModule:UpdateVisibility()
                raidModule:Update()
            end
        end)
    elseif event == "COMPACT_UNIT_FRAME_PROFILES_LOADED" then
        -- Blizzard raid frame settings changed - reinitialize to detect new layout mode
        print("Nihui_uf RAID: Blizzard profile settings changed, reinitializing...")
        if raidModule.initialized and not raidModule.debugMode then
            -- Clear existing members and reinitialize
            raidModule:ClearMembers()
            raidModule:InitializeRealRaid()
        end
    end
end)

-- Track current layout mode to detect changes
local lastDetectedMode = nil
local layoutCheckTimer = nil

local function CheckLayoutModeChange()
    if not raidModule.initialized or raidModule.debugMode then
        return
    end

    -- Detect current mode by checking which frames exist
    local hasCombinedFrames = _G["CompactRaidFrame1"] ~= nil
    local hasSeparatedFrames = _G["CompactRaidGroup1Member1"] ~= nil

    local currentMode
    if hasSeparatedFrames then
        currentMode = "separated"
    elseif hasCombinedFrames then
        currentMode = "combined"
    else
        currentMode = nil
    end

    -- If mode changed, reinitialize
    if currentMode and lastDetectedMode and currentMode ~= lastDetectedMode then
        local modeNames = {separated = "Separated Groups", combined = "Combined Groups"}
        print("|cff00ff00Nihui_uf RAID:|r Layout changed to " .. (modeNames[currentMode] or currentMode))
        raidModule:ClearMembers()
        raidModule:InitializeRealRaid()
    end

    lastDetectedMode = currentMode
end

-- Start/stop periodic check only when in Edit Mode
local function StartLayoutModeCheck()
    if not layoutCheckTimer then
        layoutCheckTimer = C_Timer.NewTicker(0.5, CheckLayoutModeChange)
    end
end

local function StopLayoutModeCheck()
    if layoutCheckTimer then
        layoutCheckTimer:Cancel()
        layoutCheckTimer = nil
    end
end

-- Hook Edit Mode enter/exit
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function()
        StartLayoutModeCheck()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        StopLayoutModeCheck()
    end)

    -- If already in Edit Mode on addon load, start timer
    if EditModeManagerFrame:IsShown() then
        StartLayoutModeCheck()
    end
end