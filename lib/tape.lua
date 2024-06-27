------------------------------------------
-- Computronics Multi-Song Tape Library --
-- by TheAirBlow               | v1.0.0 --
------------------------------------------

local component = require("component")
local computer = require("computer")
local internet = require("internet")
local fs = require("filesystem")
local int32 = require("int32")
local util = require("util")

local tape = {}

--------------------------------------------------------
-- Primitive helper methods

-- Checks if a tape drive is connected
function tape.has_drive()
    return component.isAvailable("tape_drive")
end

-- Get primary tape drive
function tape.get_drive()
    if not tape.has_drive() then
        return nil
    end

    return component.getPrimary("tape_drive")
end

-- Checks if a casette tape is inserted
function tape.has_tape()
    if not tape.has_drive() then
        return false
    end

    local drive = tape.get_drive()
    return drive.isReady()
end

-- Set casette tape label
function tape.set_label(str)
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    drive.setLabel(str)
    return true
end

-- Get casette tape label
function tape.get_label()
    if not tape.has_tape() then
        return nil
    end

    local drive = tape.get_drive()
    return drive.getLabel()
end

-- Get casette tape label
-- Returns: PLAYING, REWINDING, FORWARDING, STOPPED
function tape.get_state()
    if not tape.has_tape() then
        return nil
    end

    local drive = tape.get_drive()
    return drive.getState()
end

-- Set tape playback speed
function tape.set_speed(speed)
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    drive.setSpeed(speed)
    return true
end

-- Set tape playback volume
function tape.set_volume(volume)
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    drive.setVolume(volume)
    return true
end

-- Stop casette tape
function tape.stop()
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    drive.stop()
    return true
end

-- Play casette tape
function tape.play()
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    return drive.play()
end

-- Write arbitrary data to casette tape
function tape.write(str)
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    drive.write(str)

    return true
end

-- Download file to casette tape
function tape.write_url(url, progress)
    if not tape.has_tape() then
        return false
    end

    local req = internet.request(url, nil, nil, "HEAD")
    local _, _, headers = getmetatable(req).__index.response()
    local length = tonumber(headers["Content-Length"][1])

    local pos = 0
    for chunk in internet.request(url) do
        progress(pos, length)
        tape.write(chunk, chunk_progress)
        pos = pos + string.len(chunk)
    end

    return true
end

-- Write file contents to casette tape
function tape.write_file(path, progress)
    if not tape.has_tape() then
        return false
    end

    local drive = tape.get_drive()
    local length = fs.size(path)
    local size = computer.freeMemory() / 2

    local pos = 0
    local handle = fs.open(path)
    local chunk = handle:read(size)
    while chunk ~= nil do
        progress(pos, length)
        drive.write(chunk)
        pos = pos + string.len(chunk)
        chunk = handle:read(size)
    end

    handle:close()
    return true
end

-- Wipes casette tape
function tape.wipe(progress)
    if not tape.has_tape() then
        return false
    end

    tape.seek(-tape.get_size())
    local drive = tape.get_drive()
    local size = tape.get_size()
    local chunk = math.floor(computer.freeMemory() / 2)
    local str = string.rep("\xAA", chunk)
    for i = 1, size + chunk - 1, chunk do
        tape.write(str)
        if progress then
            progress(math.min(i+1, size), size)
        end
    end

    tape.seek(-tape.get_size())
    return true
end

-- Read string from drive
function tape.read(len)
    if not tape.has_tape() then
        return nil
    end

    local bytes = {}
    local drive = tape.get_drive()
    return drive.read(len)
end

-- Seek len bytes
function tape.seek(len)
    if not tape.has_tape() then
        return nil
    end

    local drive = tape.get_drive()
    return drive.seek(len)
end

-- Get casette tape size in bytes
function tape.get_size()
    if not tape.has_tape() then
        return nil
    end

    local drive = tape.get_drive()
    return drive.getSize()
end

--------------------------------------------------------
-- Internal methods for multi-song support

-- Writes song list to casette tape
local function write_list(headers)
    local drive = tape.get_drive()
    drive.seek(drive.getSize())
    drive.seek(-1024)
    drive.write('MULTI')

    for i=1,#headers do
        local header = headers[i]
        if header.is_free then
            drive.write('F')
        else
            drive.write('S')
        end
        drive.write(int32.write_uint32(header.length))
        if not header.is_free then
            drive.write(int32.write_uint32(string.len(header.title)))
            drive.write(header.title)
        end
    end

    drive.write('E')
    drive.seek(-drive.getSize())
end

-- Reads song list from casette tape
local function read_list()
    local drive = tape.get_drive()
    drive.seek(drive.getSize())
    drive.seek(-1019)

    local pos = 0
    local list = {}
    while true do
        local type = drive.read(1)
        if type == "E" then
            drive.seek(-drive.getSize())
            return list
        end

        local header = {}
        header.position = pos
        header.is_free = type == "F"
        header.length = int32.read_uint32(drive.read(4))
        if not header.is_free then
            local length = int32.read_uint32(drive.read(4))
            header.title = drive.read(length)
        end

        list[#list + 1] = header
        pos = pos + header.length
    end
end

-- Find free space for new song
local function find_free_space(header)
    local list = read_list()
    
    local pos = 0
    for i=1,#list do
        if list[i].is_free and list[i].length >= header.length then
            for j=i+1,#list do
                list[j] = list[j-1]
            end
            list[i] = header
            write_list(list)
            return true, pos
        end

        pos = pos + list[i].length
    end

    local left = tape.get_size() - 1024 - pos
    if left >= header.length then
        list[#list + 1] = header
        write_list(list)
        return true, pos
    end

    return false
end

--------------------------------------------------------
-- Multi-song tape implementation

-- Is casette tape multi-song
function tape.is_multi()
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    tape.seek(tape.get_size())
    tape.seek(-1024)
    if tape.read(5) ~= "MULTI" then
        return false, "No MULTI magic"
    end

    tape.seek(-tape.get_size())
    return true
end

-- Initializes multi-song casette tape
-- WARNING: Will wipe casette completely!
function tape.multi_init(progress)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if tape.is_multi() then
        return false, "Tape is already initialized to be multi-song"
    end

    tape.wipe(progress)
    tape.set_label("Multi-Song Tape")
    tape.seek(tape.get_size())
    tape.seek(-1024)
    write_list({})
    tape.seek(-tape.get_size())
    return true
end

-- Lists all songs on the tape
function tape.multi_list()
    if not tape.has_tape() then
        return nil, "No tape inserted"
    end

    if not tape.is_multi() then
        return nil, "Tape is not multi-song"
    end

    return read_list()
end

-- Download a new song
function tape.multi_write_url(title, url, progress)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    local length = 0
    local req = internet.request(url, nil, nil, "HEAD")
    local _, _, headers = getmetatable(req).__index.response()
    local length = tonumber(headers["Content-Length"][1])

    local found, pos = find_free_space({ ["is_free"] = false, ["title"] = title, ["length"] = length })
    if not found then
        return false, "Not enough space for " .. util.format(length) ..  ", try defragmenting"
    end

    tape.seek(pos)
    tape.write_url(url, progress)
    return true
end

-- Writes a new song from file
function tape.multi_write_file(title, path, progress)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    if not fs.exists(path) then
        return false, "File does not exist"
    end

    local length = fs.size(path)
    local found, pos = find_free_space({ ["is_free"] = false, ["title"] = title, ["length"] = length })
    if not found then
        return false, "Not enough space for " .. util.format(length) ..  ", try defragmenting"
    end

    tape.seek(pos)
    tape.write_file(path, progress)
    return true
end

-- Writes a new song
function tape.multi_write(title, data)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    local length = string.len(data)
    local found, pos = find_free_space({ ["is_free"] = false, ["title"] = title, ["length"] = length })
    if not found then
        return false, "Not enough space for " .. util.format(length) ..  ", try defragmenting"
    end

    tape.seek(pos)
    tape.write(data)
    return true
end

-- Removes a song at index
function tape.multi_remove(index, progress)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    local list = read_list()
    if index > #list then
        return false, "No song with that index exists"
    end

    tape.seek(list[index].position)
    local size = list[index].length
    local chunk = math.floor(computer.freeMemory() / 2)
    local str = string.rep("\xAA", chunk)
    for i = 1, size + chunk, chunk do
        tape.write(string.sub(str, 1, math.min(chunk, size - i)))
        if progress then
            progress(math.min(i+1, size), size)
        end
    end

    if index == #list then
        list[index] = nil
    else
        list[index].is_free = true
    end

    write_list(list)
    return true
end

-- Seek to start of a song at index
function tape.multi_seek(index)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    local list = read_list()
    if index > #list then
        return false, "No song with that index exists"
    end

    tape.seek(list[index].position)
    return true
end

-- Defragment casette tape
function tape.multi_defrag(progress)
    if not tape.has_tape() then
        return false, "No tape inserted"
    end

    if not tape.is_multi() then
        return false, "Tape is not multi-song"
    end

    local drive = tape.get_drive()
    local list = read_list()

    for i=1,#list-1 do
        if list[i].is_free then
            local distance = list[i+1].position - list[i].position
            local chunk = math.min(math.floor(computer.freeMemory() / 2), distance)
            drive.seek(list[i+1].position)
            for j=1,list[i+1].length+chunk,chunk do
                progress("Moving #" .. tostring(i+1) .. " to #" .. tostring(i), math.min(j, list[i+1].length), list[i+1].length)
                local bytes = drive.read(math.min(chunk, list[i+1].length - j))
                drive.seek(-distance)
                drive.write(bytes)
                drive.seek(distance)
            end
            
            local old = list[i]
            list[i] = { ["is_free"] = false, ["title"] = list[i+1].title, ["length"] = list[i+1].length, ["position"] = list[i].position }
            if i == #list - 1 then
                list[i+1] = nil
            else
                list[i+1] = { ["is_free"] = true, ["length"] = old.length, ["position"] = list[i+1].position }
            end

            write_list(list)
        end
    end

    drive.seek(-drive.getSize())
    return true
end

return tape
