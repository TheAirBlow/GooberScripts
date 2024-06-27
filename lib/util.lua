-------------------------------
-- Generic Utilities Library --
-- by TheAirBlow    | v1.0.0 --
-------------------------------

local term = require("term")
local utils = {}

-- Convert bytes to human-readable string
local units = {"B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"}

function utils.format(bytes)
    if type(bytes) ~= "number" or bytes < 0 then
        error("Input must be a non-negative number")
    end

    local index = 1
    local value = bytes
    while value >= 1024 and index < #units do
        value = value / 1024
        index = index + 1
    end

    local formatted_value = string.format("%.1f", value)
    return formatted_value .. " " .. units[index]
end

-- Convvert bytes to time string
function utils.time(bytes)
    if type(bytes) ~= "number" or bytes < 0 then
        error("Input must be a non-negative number")
    end

    local seconds = math.floor(bytes / 48000)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remaining_seconds = seconds % 60

    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remaining_seconds)
    else
        return string.format("%02d:%02d", minutes, remaining_seconds)
    end
end

-- Convert time string to bytes
function utils.bytes(time)
    if type(time) ~= "string" then
        error("Input must be a string")
    end

    local parts = {}
    for part in time_str:gmatch("[^:]+") do
        table.insert(parts, tonumber(part))
    end

    local seconds = 0
    if #parts == 3 then
        seconds = parts[1] * 3600 + parts[2] * 60 + parts[3]
    elseif #parts == 2 then
        seconds = parts[1] * 60 + parts[2]
    else
        seconds = parts[1]
    end

    return seconds * 48000
end

-- Ask for confirmation
function utils.confirm(msg)
    term.write(msg .. " [y/N] ")
    repeat
        local response = io.read()
        if response and response:lower():sub(1, 1) == "n" then
            return false
        end
    until response and response:lower():sub(1, 1) == "y"
    return true
end

return utils