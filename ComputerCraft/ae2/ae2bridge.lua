-- Author: JustASnowflake

local utils = require("ae2bridgeUtil")

-- peripherals
local monitor = peripheral.find("monitor")
if monitor == nil then return else write("Found monitor\n") end

local ae2 = peripheral.find("ae2cc_adapter")
if ae2 == nil then
    return
else
    write("Connected to AE2 adapter\n")
    local cpus = ae2.getCraftingCPUs()
    write("- Found " .. #cpus .. " CPU's\n")
end

local itemIn = peripheral.find("hexical:pedestal")
local itemOut = peripheral.find("minecraft:barrel")

monitor.setTextScale(0.5)
monitor.clear()
local monWidth, monHeight = monitor.getSize()
write("Changed monitor scale, new resolution: " .. monWidth .. "x" .. monHeight .. "\n")

local subWidth = math.floor(monWidth * 0.5)
local jobsWindowColor = colors.blue
local textColor = colors.black
local watchesWindowColor = colors.cyan

local jobsWindow = window.create(monitor, 1, 1, subWidth, monHeight)
local watchesWindow = window.create(monitor, subWidth + 1, 1, monWidth - subWidth, monHeight)
jobsWindow.setTextColour(textColor)
jobsWindow.setBackgroundColour(jobsWindowColor)
watchesWindow.setTextColour(textColor)
watchesWindow.setBackgroundColour(watchesWindowColor)
jobsWindow.clear()
watchesWindow.clear()
local jobsWindowWidth, jobsWindowHeight = jobsWindow.getSize()
local watchesWindowWidth, watchesWindowHeight = watchesWindow.getSize()
write("Created jobsWindow, resolution: " .. jobsWindowWidth .. "x" .. jobsWindowHeight .. "\n")
write("Created watchesWindow, resolution: " .. watchesWindowWidth .. "x" .. watchesWindowHeight .. "\n")


-- vaiables
local runProgram = true
local debug = true
local debugLog = "DEBUG\n"

local ctrlKey = 341

local path = fs.getDir(shell.getRunningProgram())
local dbFile = path .. "/watchedIndexes.json"

local data = {
    config = {
        path = path,
        dbFile = dbFile,
        dbModified = 0,
        peripherals = {
            itemIn = itemIn,
            itemOut = itemOut,
            ae2 = ae2
        }
    },
    cpus = {},
    jobs = {},
    watches = {},
    crafting = {},
    events = {
        ae2 = {}
    }
}

-- write(textutils.serialise(data))

local priority = {
    high = 0,
    med = 0.2,
    low = 0.5,
    ultralow = 1,
    periodical = 5
}


-- switches

local keybinds = {
    ctrl_q = function() runProgram = false end,
    [keys.d] = function()
        local dfile = fs.open("/ae2bridge/debug.log", "w+")
        dfile.write(debugLog)
        dfile.close()
        runProgram = false
    end,
}


-- functions

local function vPrint(str)
    if debug then
        debugLog = debugLog .. str
    end
    write(str)
end


-- Given a string, returns a table of strings split by delim
local function split(str, delim)
    local valTable = {}
    local i = 1
    for k, _ in string.gmatch(str, "([^" .. delim .. "]+)") do
        valTable[i] = string.gsub(k, "%s", "")
        i = i + 1
    end
    return valTable
end


-- GUI
local function printJob(job, cpuIdx, headerOffset)
    local jobInfo
    local cpuInfo = data.cpus[cpuIdx]
    local headerLine, infoLine = (2 * cpuIdx) - 1 + headerOffset, 2 * cpuIdx + headerOffset
    if job == false then
        jobInfo = ""
    else
        if type(job) == "table" then
            local rawSec = math.floor(job.elapsedNanos / 1000000000)
            local min, sec = math.floor(rawSec / 60), math.fmod(rawSec, 60)
            jobInfo =
                (job.amount or "#Error#") .. "x " ..
                (job.displayName or "#Error#") .. " " ..
                (job.crafted or "#Error#") .. "/" ..
                (job.total or "#Error#") .. " " ..
                (min or "#Error#") .. "m " ..
                (sec or "#Error#") .. "s "
        end
    end
    jobsWindow.setCursorPos(1, headerLine)
    jobsWindow.clearLine()
    jobsWindow.write(
        "CPU#" .. cpuIdx ..
        " Co-Processors:" .. cpuInfo.availableCoProcessors ..
        " Memory:" .. (cpuInfo.availableStorage / 1024) .. "K " ..
        cpuInfo.state)
    jobsWindow.setCursorPos(1, infoLine)
    jobsWindow.clearLine()
    jobsWindow.write(jobInfo)
end

local function printWatches(watches, headerOffset)
    local list = {}
    for k, v in pairs(watches) do
        table.insert(list, {
            id = k,
            item = v
        })
    end
    for k, v in pairs(list) do
        local craftable
        local isLacking = (v.item.amount or 0) + (v.item.inCrafting or 0) < (v.item.buffer or 0)
        local backgroundColour = colors.green
        if isLacking and (v.item.inCrafting or 0) > 0 then
            backgroundColour = colors.orange
        else
            if isLacking then backgroundColour = colors.red end
        end
        if v.craftable then craftable = "[C]" else craftable = "" end
        local text =
            "" .. (v.item.displayName or "#Error#") ..
            " " .. craftable ..
            " - " .. (v.item.amount or 0) ..
            "/" .. (v.item.buffer or 0) ..
            "/" .. (v.item.batch or 0) ..
            "/" .. (v.item.inCrafting or 0)
        watchesWindow.setCursorPos(2, k + headerOffset)
        watchesWindow.setBackgroundColour(backgroundColour)
        watchesWindow.write(text)
    end
end

local function redraw()
    while true do
        -- redrawing loop
        jobsWindow.setBackgroundColour(jobsWindowColor)
        jobsWindow.clear()
        jobsWindow.setCursorPos(1, 1)
        jobsWindow.write("CURRENT JOBS")
        watchesWindow.setBackgroundColour(watchesWindowColor)
        watchesWindow.clear()
        watchesWindow.setCursorPos(2, 1)
        watchesWindow.write("WATCHES - Amount/Buffer/BatchPerCraft/InCrafting")

        for k, job in pairs(data.jobs or {}) do
            printJob(job, k, 2)
        end
        printWatches(data.watches or {}, 2)
        sleep(priority.high)
    end
end

-- crafting


local function craftingManager()
    while true do
        for id, item in pairs(data.watches) do
            local amount, inCrafting, buffer, batch = item.amount or 0, item.inCrafting or 0, item.buffer or 0,
                item.batch or 0
            if amount + inCrafting < buffer then
                local missing = buffer - (amount + inCrafting)
                local remainder = batch - math.fmod(missing, batch)
                data.watches[id].inCrafting = missing + remainder
                local craftJobId = ae2.scheduleCrafting(item.type or "item", id, missing + remainder)
                data.crafting[craftJobId] = {
                    id = id,
                    amount = missing + remainder
                }
            end
        end


        sleep(priority.low)
    end
end


-- scanners
local function eventScanner()
    local events = {
        ["ae2cc:crafting_cancelled"] = function(event, jobId, cancelReason)
            table.insert(data.events.ae2, 1, { event = event, jobId = jobId, cancelReason = cancelReason })
        end,
        ["ae2cc:crafting_done"] = function(event, jobId)
            table.insert(data.events.ae2, 1, { event = event, jobId = jobId, })
        end,
        ["ae2cc:crafting_started"] = function(event, jobId)
            table.insert(data.events.ae2, 1, { event = event, jobId = jobId, })
        end
    }

    while true do
        local eventData = { os.pullEvent() }

        local eventFunc = events[eventData[1]]
        if eventFunc ~= nil then
            eventFunc(eventData[1], eventData[2], eventData[3], eventData[4], eventData[5],
                eventData[6])
        end
        -- sleep(priority.high)
    end
end

local function jobScanner()
    local cpus = ae2.getCraftingCPUs()
    for k, v in pairs(cpus) do
        local jobInfo
        if type(v["jobStatus"]) == "table" and type(v["jobStatus"]["output"]) == "table" then
            jobInfo = {
                all = v,
                cpu = k,
                amount = v["jobStatus"]["output"]["amount"],
                displayName = v["jobStatus"]["output"]["displayName"],
                crafted = v["jobStatus"]["craftedObjects"],
                total = v["jobStatus"]["totalObjects"],
                elapsedNanos = v["jobStatus"]["elapsedNanos"],
            }
        end
        data.jobs[k] = jobInfo or false

        local cpuState
        if v["jobStatus"] ~= nil then cpuState = "Busy" else cpuState = "Idle" end
        local cpuInfo = {
            availableCoProcessors = v["availableCoProcessors"],
            availableStorage = v["availableStorage"],
            selectionMode = v["selectionMode"],
            state = cpuState,
        }
        data.cpus[k] = cpuInfo
    end
end

local function main()
    while true do
        data = utils.itemScanner(data) or data
        data = utils.handleCrafting(data) or data
        jobScanner()
        sleep(priority.high)
    end
end

-- input scanners



local function keyScanner()
    local function run(a) if type(a) == "function" then a() end end
    local pressed = {}
    while runProgram do
        local event, key = os.pullEvent()
        if event == "key" then
            pressed[key] = true
        elseif event == "key_up" then
            pressed[key] = nil
        end
        if pressed[ctrlKey] and pressed[keys.q] then run(keybinds.ctrl_q) end
    end
end

parallel.waitForAny(redraw, eventScanner, main, keyScanner, craftingManager)
vPrint("Exiting...\n")
