-- Author: JustASnowflake

-- peripherals
local mon = peripheral.find("monitor")
if mon == nil then return else write("Found monitor\n") end

local ae2 = peripheral.find("ae2cc_adapter")
if ae2 == nil then
    return
else
    write("Connected to AE2 adapter\n")
    local cpus = ae2.getCraftingCPUs()
    write("- Found " .. #cpus .. " CPU's\n")
end

local itemIn = peripheral.wrap("hexical:pedestal_3")
local itemOut = peripheral.wrap("minecraft:barrel_17")

mon.setTextScale(0.5)
mon.clear()
local monWidth, monHeight = mon.getSize()
write("Changed monitor scale, new resolution: " .. monWidth .. "x" .. monHeight .. "\n")

local subWidth = math.floor(monWidth * 0.5)
local jobsWindowColor = colors.blue
local textColor = colors.black
local watchesWindowColor = colors.cyan

local jobsWindow = window.create(mon, 1, 1, subWidth, monHeight)
local watchesWindow = window.create(mon, subWidth + 1, 1, monWidth - subWidth, monHeight)
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

local path = fs.getDir(shell.getRunningProgram())
local watchesFile = path .. "/watchedIndexes.json"
local watchesFileModified = 0
local mode = {
    craftable = "Craftable",
    watched = "Watched",
}
local watchesMode = mode.watched

local data = {
    jobs = {},
    cpus = {},
    watches = {},
    crafting = {},
}
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
local function redraw()
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
            local isLacking = (v.item.amount or 0) + (v.item.inCrafting or 0) < v.item.buffer
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


    -- redrawing loop
    while runProgram do
        jobsWindow.setBackgroundColour(jobsWindowColor)
        jobsWindow.clear()
        jobsWindow.setCursorPos(1, 1)
        jobsWindow.write("CURRENT JOBS")
        watchesWindow.setBackgroundColour(watchesWindowColor)
        watchesWindow.clear()
        watchesWindow.setCursorPos(2, 1)
        watchesWindow.write("WATCHES - Amount/Buffer/BatchPerCraft/InCrafting")

        for k, job in pairs(data.jobs or {}) do printJob(job, k, 2) end
        printWatches(data.watches or {}, 2)
        sleep(priority.high)
    end
end

-- crafting


local function craftingManager()
    while true do
        for id, item in pairs(data.watches) do
            local amount, inCrafting = item.amount or 0, item.inCrafting or 0
            if (amount) + (inCrafting) < item.buffer then
                local missing = item.buffer - (amount + inCrafting)
                local remainder = item.batch - math.fmod(missing, item.batch)
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
local function eventHandler()
    local events = {
        ["ae2cc:crafting_cancelled"] = function(event, jobId, cancelReason)
            vPrint(event .. " " .. jobId .. " " .. cancelReason .. "\n")
        end,
        ["ae2cc:crafting_done"] = function(event, jobId)
            local craftingJob = data.crafting[jobId]
            data.crafting[jobId] = nil
            data.watches[craftingJob.id].amount = data.watches[craftingJob.id].amount + craftingJob.amount
            data.watches[craftingJob.id].inCrafting = data.watches[craftingJob.id].inCrafting - craftingJob.amount
            vPrint(event .. " " .. jobId .. " " .. craftingJob.id .. " " .. craftingJob.amount .. "\n")
        end,
        ["ae2cc:crafting_started"] = function(event, jobId)
            vPrint(event .. " " .. jobId .. "\n")
        end
    }

    while true do
        local eventData = { os.pullEvent() }
        local event, jobId, cancelReason = eventData[1], eventData[2], eventData[3]
        -- if string.find(event, "ae2") ~= nil then vPrint(textutils.serialise(eventData).."\n") end

        local eventFunc = events[event]
        if eventFunc ~= nil then eventFunc(event, jobId, cancelReason) end
        -- sleep(priority.high)
    end
end

local function scanJobs()
    while true do
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

        sleep(priority.high)
    end
end


local function scanItemsToWatch()
    while true do
        local f
        local exists = fs.exists(watchesFile)
        local itemInInput = itemIn.list()[1] ~= nil

        -- if file doesn't exist, create it
        if not exists then
            f = fs.open(watchesFile, "w")
            f.write("[\n]")
            f.close()
        end

        local fileModificationDate = fs.attributes(watchesFile)["modified"]
        local wasModified = fileModificationDate ~= watchesFileModified

        -- if file does exist check if modified, add to monitoredIndexes if yes
        if wasModified or itemInInput then
            vPrint("DB file modified, scanning...\n")
            watchesFileModified = fileModificationDate

            local f = fs.open(watchesFile, "r")
            local json = f.readAll()
            json = textutils.unserialiseJSON(json)
            f.close()
            data.watches = {}

            for _, v in ipairs(json) do
                data.watches[v["id"]] = {
                    displayName = v["displayName"],
                    type = v["type"],
                    buffer = v["buffer"],
                    batch = v["batch"],
                }
            end
            if itemInInput then
                -- get info and push item to ae2 system
                local itemToAdd = itemIn.getItemDetail(1)
                itemIn.pushItems(peripheral.getName(itemOut), 1)
                local idToAdd = itemToAdd["name"]
                itemToAdd = {
                    displayName = itemToAdd["displayName"],
                    type = itemToAdd["type"] or "item",
                    buffer = 0,
                    batch = 0,
                }
                -- add item to watches
                data.watches[idToAdd] = itemToAdd

                -- prepare watches to serialize and save them to json
                local toSerialise = {}
                for key, value in pairs(data.watches) do
                    table.insert(toSerialise, {
                        ["id"] = key,
                        ["displayName"] = value.displayName,
                        ["type"] = value.type or "item",
                        ["buffer"] = value.buffer,
                        ["batch"] = value.batch,
                    })
                end
                json = textutils.serialiseJSON(toSerialise)
                f = fs.open(watchesFile, "w+")
                f.write(json)
                f.close()

                -- update modification date to avoid scanning the same data again
                fileModificationDate = fs.attributes(watchesFile)["modified"]
                watchesFileModified = fileModificationDate
            end
            vPrint(textutils.serialise(data.watches) .. "\n")
        end

        sleep(priority.low)
    end
end

local function scanCraftingsAndItems()
    while true do
        local aeCraftings = ae2.getCraftableObjects()
        local aeItems = ae2.getAvailableObjects()
        -- aeCraftings = textutils.unserialiseJSON(aeCraftings)
        for _, v in pairs(aeCraftings) do
            local id = v["id"] or "#Error#"
            if data.watches[id] ~= nil then data.watches[id].craftable = true end
        end

        for _, v in pairs(aeItems) do
            local id = v["id"] or "#Error#"
            if data.watches[id] ~= nil then data.watches[id].amount = v["amount"] or 0 end
        end

        sleep(priority.periodical)
    end
end

-- input scanners

local function scanMonitorClicks()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        vPrint("# EVENT monitor_touch at (" .. x .. ", " .. y .. ")\n")
        sleep(0)
    end
end

local ctrlKey = 341
local function scanKeyPress()
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

parallel.waitForAny(redraw, eventHandler, scanKeyPress, scanJobs, scanMonitorClicks, scanItemsToWatch,
    scanCraftingsAndItems, craftingManager)
vPrint("Exiting...\n")
