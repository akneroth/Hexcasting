local monitor = peripheral.find("monitor")
local monW, monH = monitor.getSize()
local modem = peripheral.find("modem")
local run = true
local protocol, mode, hostname
local page = 1
local pages = {}
local data = {}

monitor.setTextScale(0.5)
monitor.clear()

local programName = fs.getName(shell.getRunningProgram())
if #arg < 1 then
    print("Usage: " .. programName .. " <host> [<mode>] [<hostname>]")
    return
else
    mode = arg[2] or "items"
    protocol = arg[1].."_"..mode
    hostname = arg[3] or protocol.."_"..os.computerID()
end

local a = {
    header = "Mon",
    headerSize = 2,
    lines = {},
}
for i = 1, 200, 1 do
    table.insert(a.lines, "line " .. i)
end




-- INIT

rednet.open(peripheral.getName(modem))

if not rednet.isOpen() then
    print("Rednet connection is not open. Please check if wireless modem is attached to the computer")
    print("Terminating...")
    return
else
    print("Rednet connection is open")
    if hostname ~= nil then
        rednet.host(protocol, hostname)
    else
        rednet.host(protocol)
    end
    print("Rednet registered under")
    print("--hostname:" .. (hostname or "<no hostname>"))
    print("--protocol:" .. protocol)
end

if monitor == nil then
    print("No monitor attached. Please attach monitor, preferably equal or larger than 2x2")
    return
else
    print("Monitor attached...")
end


-- Components

local buttons = {}
for i = 1, monW, 1 do
    buttons[i] = {}
end
local function addButton(posX, posY, color, text, func, canvas)
    local prevColor = canvas.getBackgroundColor()
    canvas.setCursorPos(posX, posY)
    canvas.setBackgroundColor(color)
    canvas.write(text)
    canvas.setBackgroundColor(prevColor)

    -- register button
    for i = 0, string.len(text) - 1, 1 do
        buttons[posX + i][posY] = func
    end
end

local function addPager(page, maxPage, onChange, canvas)
    local canvW, canvH = canvas.getSize()
    local pagerText = page .. " of " .. maxPage
    local pagerStartPos = math.floor(canvW / 2 - string.len(pagerText) / 2 + 1)
    local pagerEndPos = pagerStartPos + string.len(pagerText)
    canvas.setCursorPos(pagerStartPos, canvH)
    canvas.write(pagerText)
    addButton(pagerStartPos - 6, canvH, colors.green, "<<", function() onChange(1) end, canvas)
    addButton(pagerStartPos - 3, canvH, colors.green, " <",
        function() if page - 1 < 1 then onChange(1) else onChange(page - 1) end end, canvas)
    addButton(pagerEndPos + 1, canvH, colors.green, "> ",
        function() if page + 1 > maxPage then onChange(maxPage) else onChange(page + 1) end end, canvas)
    addButton(pagerEndPos + 4, canvH, colors.green, ">>", function() onChange(maxPage) end, canvas)
end




-- Functions
local function color(canvas) return canvas.getBackgroundColor() end

local function printOnMonitor()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write(data.header)

    for line, value in pairs(pages[page]) do
        monitor.setCursorPos(1, data.headerSize + line)
        monitor.write(value or "")
    end

    addPager(page, #pages, function(i) page = i end, monitor)
end

local function pageify(lines, margins)
    local linesAvailable = monH - margins
    local out = {}
    for line, value in pairs(lines) do
        local toPage = math.floor(((line - 1) / linesAvailable)) + 1
        if out[toPage] == nil then out[toPage] = {} end
        table.insert(out[toPage], value)
    end
    return out
end






local events = {
    ["monitor_touch"] = function(event)
        local event, id, x, y = unpack(event)
        print(event, id, x, y)

        -- handle press
        local buttonFunc = buttons[x][y]
        if buttonFunc ~= nil then buttonFunc() end
    end
}

local function eventListener()
    while true do
        local event = { os.pullEvent() }
        local eventFunc = events[event[1]]
        if eventFunc ~= nil then eventFunc(event) end
    end
end

local function main()
    while run do
        local id, recieved = rednet.receive(protocol)
        data = textutils.unserialiseJSON(recieved)
        print("Recieved data from computer", id, "data:", data)
        pages = pageify(data.lines, data.headerSize + 1)

        printOnMonitor()
        sleep(0.05)
    end
end


parallel.waitForAny(main, eventListener)
