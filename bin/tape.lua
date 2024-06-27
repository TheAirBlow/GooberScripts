--------------------------------------
-- Computronics Multi-Song Tape CLI --
-- by TheAirBlow             v1.0.0 --
--------------------------------------

local tape = require("tape")
local term = require("term")
local util = require("util")

--------------------------------------------------------
-- Helper methods

-- Progress message
local progress_title = "No title"
function progress(cur, max)
    local _, y = term.getCursor()
    local percent = math.floor(cur / max * 10000) / 100
    term.setCursor(1, y-1)
    term.clearLine()
    term.write(progress_title .. ": " .. tostring(percent) .. "% (" .. tostring(util.format(cur)) .. " out of " .. tostring(util.format(max)) .. ")\n")
end

function cust_progress(title, cur, max)
    local _, y = term.getCursor()
    local percent = math.floor(cur / max * 10000) / 100
    term.setCursor(1, y-1)
    term.clearLine()
    term.write(title .. ": " .. tostring(percent) .. "% (" .. tostring(util.format(cur)) .. " out of " .. tostring(util.format(max)) .. ")\n")
end

--------------------------------------------------------
-- All CLI commands

local cmds = {}

-- Information about the tape
function cmds.info(args)
    if tape.get_label() == "" then
        print("Label: Unnamed Tape")
    else
        print("Label: " .. tape.get_label())
    end
    print("State: " .. tape.get_state())
    print("Size: " .. util.format(tape.get_size()))
end

-- Information about multi-song tape
function cmds.multi(args)
    if tape.get_state() == "PLAYING" then
        print("WARNING: This will disrupt currently playing song!")
        if not util.confirm("Do you want to continue?") then 
            print("Cancelled by user")
            return
        end
    end

    if not tape.is_multi() then
        print("Tape is not multi-song!")
        return
    end

    local list, err = tape.multi_list()
    if not list then
        print(err)
        return
    end

    local pos = 0
    local free = 0
    local miss = 0
    local defrag = false
    for i=1,#list do
        if list[i].is_free then
            free = math.max(free, list[i].length)
            miss = miss + list[i].length
            defrag = true
        end

        pos = pos + list[i].length
    end

    local at_end = tape.get_size() - 1024 - pos
    free = math.max(free, at_end)

    if defrag then
        print("WARNING: You're losing " .. util.format(at_end + miss - free) .. ", consider defragmenting!")
    end

    print("Free " .. util.format(free) .. " out of " .. util.format(tape.get_size()))

    if #list == 0 then
        print("This tape has no songs")
    else
        for i=1, #list do
            if list[i].is_free then
                print(tostring(i) .. ". Free space (" .. util.format(list[i].length) .. ")")
            else
                print(tostring(i) .. ". " .. list[i].title)
            end
        end
    end
end

-- Initializes multi-song casette tape
function cmds.init(args)
    print("WARNING: This will completely wipe the casette tape!")
    if not util.confirm("Do you want to continue?") then 
        print("Cancelled by user")
        return
    end
    
    progress_title = "Wiping casette tape"
    local st, err = tape.multi_init(progress)
    if not st then
        print(err)
        return
    end
end

-- Wipes casette tape
function cmds.wipe(args)
    print("WARNING: This will completely wipe the casette tape!")
    if not util.confirm("Do you want to continue?") then 
        print("Cancelled by user")
        return
    end
    
    progress_title = "Wiping casette tape"
    local st, err = tape.wipe(progress)
    if not st then
        print(err)
        return
    end
end

-- Remove 
function cmds.remove(args)
    if #args < 2 then
        print("Usage: tape remove [index]")
        return
    end

    if not tape.is_multi() then
        print("Tape is not a multi-song tape!")
        return
    end

    print("one moment...")
    local index = tonumber(args[2])
    progress_title = "Removing song"
    local st, err = tape.multi_remove(index, progress)
    if not st then
        print(err)
        return
    end
end

-- Defragment multi-song tape
function cmds.defrag(args)
    if not tape.is_multi() then
        print("Tape is not multi-song tape!")
        return
    end

    print("one moment...")
    tape.multi_defrag(cust_progress)
    return
end

-- Writes a new song on the tape
function cmds.write(args)
    if #args < 2 then
        print("Usage: tape write [path/url] [title] / tape write [path/url]")
        return
    end

    if #args > 2 then
        if not tape.is_multi() then
            print("Tape is not multi-song, title is not allowed!")
            return
        end

        local title = args[3]
        for i=4, #args do
            title = title .. " " .. args[i]
        end

        print("one moment...")
        if string.sub(args[2], 1, math.min(4, string.len(args[2]))) == 'http' then
            progress_title = "Downloading new song to casette tape"
            local st, err = tape.multi_write_url(title, args[2], progress)
            if not st then
                print(err)
                return
            end

            print("Successfully downloaded new song to casette tape!")
        else
            progress_title = "Writing new song to casette tape"
            local st, err = tape.multi_write_file(title, args[2], progress)
            if not st then
                print(err)
                return
            end

            print("Successfully wrote new song to casette tape!")
        end
    else
        if tape.is_multi() then
            print("Tape is multi-song, title is required!")
            return
        end

        print("one moment...")
        if string.sub(args[2], 1, math.min(4, string.len(args[2]))) == 'http' then
            progress_title = "Downloading file to casette tape"
            local st, err = tape.write_url(args[2], progress)
            if not st then
                print(err)
                return
            end

            print("Successfully downloaded file to casette tape!")
        else
            progress_title = "Writing file to casette tape"
            local st, err = tape.write_file(args[2], progress)
            if not st then
                print(err)
                return
            end

            print("Successfully wrote file to casette tape!")
        end
    end
end

-- Seeks to song at index
function cmds.seek(args)
    if #args ~= 2 then
        print("Usage: tape seek [index]")
        return
    end

    if not tape.is_multi() then
        print("Tape is not multi-song!")
        return
    end

    local list = tape.multi_list()
    local index = tonumber(args[2])
    local st, err = tape.multi_seek()
    if not st then
        print(err)
        return
    end
    
    print("Seeked to " .. list[index].title)
    return
end

-- Plays casette tape
function cmds.play(args)
    if #args == 2 then
        if not tape.is_multi() then
            print("Tape is not multi-song, index is not allowed!")
            return
        end

        local list = tape.multi_list()
        local index = tonumber(args[2])
        local st, err = tape.multi_seek(index)
        if not st then
            print(err)
            return
        end

        print("Now playing " .. list[index].title)
        tape.play()
        return
    end

    tape.play()
end

-- Stops casette tape
function cmds.stop(args)
    tape.stop()
end

--------------------------------------------------------
-- Arguments handler

if not tape.has_drive() then
    print("No primary tape drive!")
    return
end

if not tape.has_tape() then
    print("No tape is inserted!")
    return
end

local args = { ... }

if cmds[args[1]] ~= nil then
    cmds[args[1]](args)
else
    print("Multi-song tape:")
    print("tape seek [index] <HH:MM:SS> - seek to specific song")
    print("tape write [path/url] [title] - add new song")
    print("tape play [index] - starts playback of song")
    print("tape remove [index] - remove song at index")
    print("tape defrag - defragments multi-song tape")
    print("tape init - initialize multi-song tape")
    print("")
    print("Normal casette tape:")
    print("tape seek [HH:MM:SS] - seek for specific time")
    print("tape write [path/url] - overwrite tape")
    print("")
    print("Any casette tape:")
    print("tape info - information about tape")
    print("tape wipe - wipes tape completely")
    print("tape play - starts playback")
    print("tape stop - stops playback")
end