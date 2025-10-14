-- cores/lifecycle.lua - Component Lifecycle Management System
local _, ns = ...

-- Core namespace
ns.Core = ns.Core or {}
ns.Core.Lifecycle = {}

-- ===========================
-- MODULE UTILITIES
-- ===========================

-- Generic module setup function to reduce code duplication
function ns.CreateModuleSetup(moduleInstance, specialSetupFn)
    return function(customConfig)
        -- Call special setup if provided (for module-specific initialization)
        if specialSetupFn then
            specialSetupFn(customConfig)
        end

        -- NOTE: Initialize() is called by init.lua, not here!
        -- Removed moduleInstance:Initialize() to prevent double initialization
        return moduleInstance
    end
end

-- ===========================
-- COMPONENT REGISTRY
-- ===========================

-- Registry for all active components
local componentRegistry = {}
local componentOrder = {} -- Ordered list for proper initialization/destruction

-- Component states
local COMPONENT_STATES = {
    UNINITIALIZED = "UNINITIALIZED",
    INITIALIZING = "INITIALIZING",
    INITIALIZED = "INITIALIZED",
    DESTROYING = "DESTROYING",
    DESTROYED = "DESTROYED"
}

-- ===========================
-- COMPONENT REGISTRATION
-- ===========================

-- Register a component with lifecycle management
function ns.Core.Lifecycle.RegisterComponent(name, component, dependencies)
    if componentRegistry[name] then
        error("Component already registered: " .. name)
    end

    local componentInfo = {
        name = name,
        component = component,
        dependencies = dependencies or {},
        state = COMPONENT_STATES.UNINITIALIZED,
        dependents = {}
    }

    componentRegistry[name] = componentInfo
    table.insert(componentOrder, name)

    -- Build dependency graph
    for _, dependency in ipairs(dependencies) do
        if componentRegistry[dependency] then
            table.insert(componentRegistry[dependency].dependents, name)
        end
    end

    return componentInfo
end

-- Unregister a component
function ns.Core.Lifecycle.UnregisterComponent(name)
    local componentInfo = componentRegistry[name]
    if not componentInfo then
        return false
    end

    -- Destroy if initialized
    if componentInfo.state == COMPONENT_STATES.INITIALIZED then
        ns.Core.Lifecycle.DestroyComponent(name)
    end

    -- Remove from registry
    componentRegistry[name] = nil

    -- Remove from order
    for i, componentName in ipairs(componentOrder) do
        if componentName == name then
            table.remove(componentOrder, i)
            break
        end
    end

    return true
end

-- ===========================
-- DEPENDENCY RESOLUTION
-- ===========================

-- Check if all dependencies are satisfied
local function CheckDependencies(componentName)
    local componentInfo = componentRegistry[componentName]
    if not componentInfo then
        return false
    end

    for _, dependency in ipairs(componentInfo.dependencies) do
        local depInfo = componentRegistry[dependency]
        if not depInfo or depInfo.state ~= COMPONENT_STATES.INITIALIZED then
            return false, dependency
        end
    end

    return true
end

-- Get initialization order based on dependencies
local function GetInitializationOrder()
    local order = {}
    local visited = {}
    local visiting = {}

    local function visit(componentName)
        if visiting[componentName] then
            error("Circular dependency detected: " .. componentName)
        end

        if visited[componentName] then
            return
        end

        visiting[componentName] = true

        local componentInfo = componentRegistry[componentName]
        if componentInfo then
            for _, dependency in ipairs(componentInfo.dependencies) do
                visit(dependency)
            end
        end

        visiting[componentName] = false
        visited[componentName] = true
        table.insert(order, componentName)
    end

    for _, componentName in ipairs(componentOrder) do
        visit(componentName)
    end

    return order
end

-- ===========================
-- COMPONENT LIFECYCLE
-- ===========================

-- Initialize a single component
function ns.Core.Lifecycle.InitializeComponent(name)
    local componentInfo = componentRegistry[name]
    if not componentInfo then
        error("Component not found: " .. name)
    end

    if componentInfo.state ~= COMPONENT_STATES.UNINITIALIZED then
        return componentInfo.state == COMPONENT_STATES.INITIALIZED
    end

    -- Check dependencies
    local satisfied, missingDep = CheckDependencies(name)
    if not satisfied then
        error("Missing dependency for " .. name .. ": " .. (missingDep or "unknown"))
    end

    componentInfo.state = COMPONENT_STATES.INITIALIZING

    -- Initialize the component
    local success, err = pcall(function()
        if componentInfo.component.Initialize then
            componentInfo.component:Initialize()
        end
    end)

    if success then
        componentInfo.state = COMPONENT_STATES.INITIALIZED
        return true
    else
        componentInfo.state = COMPONENT_STATES.UNINITIALIZED
        error("Failed to initialize component " .. name .. ": " .. tostring(err))
    end
end

-- Destroy a single component
function ns.Core.Lifecycle.DestroyComponent(name)
    local componentInfo = componentRegistry[name]
    if not componentInfo then
        return false
    end

    if componentInfo.state ~= COMPONENT_STATES.INITIALIZED then
        return true
    end

    -- Check if any dependents are still active
    for _, dependent in ipairs(componentInfo.dependents) do
        local depInfo = componentRegistry[dependent]
        if depInfo and depInfo.state == COMPONENT_STATES.INITIALIZED then
            error("Cannot destroy " .. name .. " while " .. dependent .. " is still active")
        end
    end

    componentInfo.state = COMPONENT_STATES.DESTROYING

    -- Destroy the component
    local success, err = pcall(function()
        if componentInfo.component.Destroy then
            componentInfo.component:Destroy()
        end
    end)

    if success then
        componentInfo.state = COMPONENT_STATES.DESTROYED
        return true
    else
        componentInfo.state = COMPONENT_STATES.INITIALIZED
        error("Failed to destroy component " .. name .. ": " .. tostring(err))
    end
end

-- ===========================
-- BULK OPERATIONS
-- ===========================

-- Initialize all registered components in dependency order
function ns.Core.Lifecycle.InitializeAll()
    local initOrder = GetInitializationOrder()
    local initialized = {}

    for _, componentName in ipairs(initOrder) do
        if componentRegistry[componentName] then
            local success, err = pcall(ns.Core.Lifecycle.InitializeComponent, componentName)
            if success then
                table.insert(initialized, componentName)
            else
                -- Rollback on failure
                for i = #initialized, 1, -1 do
                    pcall(ns.Core.Lifecycle.DestroyComponent, initialized[i])
                end
                error("Failed to initialize all components: " .. tostring(err))
            end
        end
    end

    return initialized
end

-- Destroy all components in reverse dependency order
function ns.Core.Lifecycle.DestroyAll()
    local initOrder = GetInitializationOrder()
    local destroyed = {}

    -- Destroy in reverse order
    for i = #initOrder, 1, -1 do
        local componentName = initOrder[i]
        if componentRegistry[componentName] then
            local success = pcall(ns.Core.Lifecycle.DestroyComponent, componentName)
            if success then
                table.insert(destroyed, componentName)
            end
        end
    end

    return destroyed
end

-- ===========================
-- QUERY FUNCTIONS
-- ===========================

-- Get component state
function ns.Core.Lifecycle.GetComponentState(name)
    local componentInfo = componentRegistry[name]
    return componentInfo and componentInfo.state or nil
end

-- Check if component is initialized
function ns.Core.Lifecycle.IsComponentInitialized(name)
    return ns.Core.Lifecycle.GetComponentState(name) == COMPONENT_STATES.INITIALIZED
end

-- Get all registered components
function ns.Core.Lifecycle.GetAllComponents()
    local components = {}
    for name, info in pairs(componentRegistry) do
        components[name] = {
            name = info.name,
            state = info.state,
            dependencies = info.dependencies,
            dependents = info.dependents
        }
    end
    return components
end

-- Get initialization statistics
function ns.Core.Lifecycle.GetStats()
    local stats = {
        total = 0,
        uninitialized = 0,
        initializing = 0,
        initialized = 0,
        destroying = 0,
        destroyed = 0
    }

    for _, info in pairs(componentRegistry) do
        stats.total = stats.total + 1
        if info.state == COMPONENT_STATES.UNINITIALIZED then
            stats.uninitialized = stats.uninitialized + 1
        elseif info.state == COMPONENT_STATES.INITIALIZING then
            stats.initializing = stats.initializing + 1
        elseif info.state == COMPONENT_STATES.INITIALIZED then
            stats.initialized = stats.initialized + 1
        elseif info.state == COMPONENT_STATES.DESTROYING then
            stats.destroying = stats.destroying + 1
        elseif info.state == COMPONENT_STATES.DESTROYED then
            stats.destroyed = stats.destroyed + 1
        end
    end

    return stats
end

-- ===========================
-- HELPER FUNCTIONS
-- ===========================

-- Validate component interface
local function ValidateComponent(component)
    if type(component) ~= "table" then
        return false, "Component must be a table"
    end

    -- Check for required methods (optional but recommended)
    local optionalMethods = {"Initialize", "Destroy"}
    for _, methodName in ipairs(optionalMethods) do
        if component[methodName] and type(component[methodName]) ~= "function" then
            return false, methodName .. " must be a function"
        end
    end

    return true
end

-- Register component with validation
function ns.Core.Lifecycle.RegisterValidatedComponent(name, component, dependencies)
    local valid, error = ValidateComponent(component)
    if not valid then
        error("Invalid component " .. name .. ": " .. error)
    end

    return ns.Core.Lifecycle.RegisterComponent(name, component, dependencies)
end

-- ===========================
-- CONSTANTS EXPORT
-- ===========================

ns.Core.Lifecycle.States = COMPONENT_STATES