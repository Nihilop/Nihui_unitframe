-- core/utils.lua - Utility Functions
local _, ns = ...

-- Utils namespace
ns.Utils = ns.Utils or {}

-- ===========================
-- TABLE SERIALIZATION
-- ===========================

-- Convert table to string representation
function ns.Utils.TableToString(t, indent)
    indent = indent or 0
    local indentStr = string.rep("    ", indent)

    if type(t) ~= "table" then
        if type(t) == "string" then
            return string.format("%q", t)
        else
            return tostring(t)
        end
    end

    local result = "{\n"
    for k, v in pairs(t) do
        local keyStr
        if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
            keyStr = k
        else
            keyStr = "[" .. ns.Utils.TableToString(k, 0) .. "]"
        end

        result = result .. indentStr .. "    " .. keyStr .. " = " .. ns.Utils.TableToString(v, indent + 1) .. ",\n"
    end
    result = result .. indentStr .. "}"

    return result
end

-- ===========================
-- TABLE UTILITIES
-- ===========================

-- Deep copy table
function ns.Utils.DeepCopy(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for k, v in next, original, nil do
            copy[ns.Utils.DeepCopy(k)] = ns.Utils.DeepCopy(v)
        end
        setmetatable(copy, ns.Utils.DeepCopy(getmetatable(original)))
    else
        copy = original
    end
    return copy
end

-- Merge tables
function ns.Utils.MergeTables(t1, t2)
    local result = ns.Utils.DeepCopy(t1)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = ns.Utils.MergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end