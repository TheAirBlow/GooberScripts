----------------------------
-- Binary Integer Library --
-- by TheAirBlow | v1.0.0 --
----------------------------

local bit32 = require("bit32")

local int32 = {}

-- Writes a signed 32-bit integer to a string
function int32.write_int32(num)
    local b1 = bit32.band(num, 0xFF)
    local b2 = bit32.band(bit32.rshift(num, 8), 0xFF)
    local b3 = bit32.band(bit32.rshift(num, 16), 0xFF)
    local b4 = bit32.band(bit32.rshift(num, 24), 0xFF)
    return string.char(b1, b2, b3, b4)
end

-- Writes an unsigned 32-bit integer to a string
function int32.write_uint32(num)
    return int32.write_int32(num)
end

-- Reads a signed 32-bit integer from a string
function int32.read_int32(str, pos)
    pos = pos or 1
    local b1, b2, b3, b4 = string.byte(str, pos, pos + 3)
    local num = bit32.bor(b1, bit32.lshift(b2, 8), bit32.lshift(b3, 16), bit32.lshift(b4, 24))
    if num >= 0x80000000 then
        num = num - 0x100000000
    end
    return num
end

-- Reads an unsigned 32-bit integer from a string
function int32.read_uint32(str, pos)
    pos = pos or 1
    local b1, b2, b3, b4 = string.byte(str, pos, pos + 3)
    return bit32.bor(b1, bit32.lshift(b2, 8), bit32.lshift(b3, 16), bit32.lshift(b4, 24))
end

-- Writes a boolean value to a single byte string
function int32.write_bool(value)
    if value then
        return string.char(1)
    else
        return string.char(0)
    end
end

-- Reads a boolean value from a single byte string
function int32.read_bool(str, pos)
    pos = pos or 1
    local byte = string.byte(str, pos)
    if byte == 1 then
        return true
    else
        return false
    end
end

return int32