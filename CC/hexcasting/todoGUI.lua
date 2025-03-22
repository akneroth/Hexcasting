local ui = require("ccui")

local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
monitor.clear()
local monW, monH = monitor.getSize()
ui.setMonitor(monitor)

-- Variables

local path = fs.getDir(shell.getRunningProgram())
local dataFile = path .. "/todoData.json"
local data = {}
local tab = "spells"
local tabs = {
    spells = function () tab = "spells" end,
    requested = function () tab = "requested" end,
    todo = function () tab = "todo" end,
}
local page = 1
local pages = {
    spells = 1,
    requested = 1,
    todo = 1,
}

local function getData()
    local f = fs.open(dataFile, "r")
    local out = textutils.unserialiseJSON(f.readAll())
    f.close()
    return out
end

local function saveData(data)
    local f = fs.open(dataFile, "w")
    local out = textutils.serialiseJSON(data)
    f.write(out)
end



-- Variables init

data = getData()

-- Functions


local headerSize = 2
local footerSize = 2
local margins = headerSize + footerSize
local function render()
    ui.clear()
    ui.addPager(page, pages[tab], function (n) page = n end)

    for i = 1, (monH - margins), 1 do
        monitor.setCursorPos()
        monitor.clearLine()
        monitor.write()
    end


end




-- Threads

local function dataThread()
    while true do
        data = getData()

        -- handle events like clicks and such

        saveData(data)
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
