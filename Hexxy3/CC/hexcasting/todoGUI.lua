local path = fs.getDir(shell.getRunningProgram())

local ccui = require("ccui")
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
monitor.clear()
local monW, monH = monitor.getSize()
local ui = ccui.setMonitor(monitor)

-- Variables

local dataFile = path .. "/todoData.json"
local data = {}
local tab = "spells"
local tabs = {
    spells = function() tab = "spells" end,
    requested = function() tab = "requested" end,
    todo = function() tab = "todo" end,
}
local page = 1
local pages = {
    spells = 1,
    requested = 1,
    todo = 1,
}

local function getData()
    local f = fs.open(dataFile, "r")
    local toSave = f.readAll()
    local out = textutils.unserialiseJSON(toSave)
    f.close()
    return out
end

local function saveData(toSave)
    local f = fs.open(dataFile, "w")
    local out = textutils.serialiseJSON(toSave)
    f.write(out)
    f.close()
end



-- Variables init

data = getData()

-- Functions

local headerSize = 2
local footerSize = 2
local margins = headerSize + footerSize
local space = monH - margins
local function render()
    ui.canvas.clear()
    ui:addPager(page, pages[tab], function(n) page = n end)

    for i = 1, space, 1 do
        monitor.setCursorPos(1, i + headerSize)
        monitor.clearLine()
        local line = data.spells[space * (page - 1) + i]
        local toPrint = (line.name or "null") .. " - " .. (line.desc or "")
        if type(line.params) == "string" and string.len(line.params) ~= 0 then
            toPrint = string.gsub(toPrint, " - ", (" " .. line.params .. " "), 1)
        end
        monitor.write(toPrint)
    end
end




-- Threads

local function dataThread()
    while true do
        local buffer = getData()

        for tableType, spellTable in pairs(buffer) do
            for idx, spell in ipairs(spellTable) do
                if spell.params == "" then
                    buffer[tableType][idx].params = nil
                end
            end
        end
        -- handle events like clicks and such

        data = buffer
        saveData(buffer)
        ui.priority.high()
    end
end

local function uiThread()
    while true do
        render()
        ui.priority.low()
    end
end

parallel.waitForAny(uiThread, dataThread)
