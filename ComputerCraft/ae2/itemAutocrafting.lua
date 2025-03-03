-- Author: JustASnowflake

-- peripherals
local mon = peripheral.find("monitor")
if mon == nil then return else write("Found monitor\n") end

local ae2 = peripheral.find("ae2cc_adapter")
if ae2 == nil then return else write("Connected to AE2 adapter\n") end

local itemIn = peripheral.wrap("hexical:pedestal_3")
local itemOut = peripheral.wrap("minecraft:barrel_17")

mon.setTextScale(0.5)
mon.clear()
local monWidth, monHeight = mon.getSize()
write("Changed monitor scale, new resolution: "..monWidth.."x"..monHeight.."\n")

local subWidth = math.floor(monWidth * 0.8)
local subHeight = math.floor(monHeight * 0.5)

local jobsWindow = window.create(mon, 1, 1, subWidth, subHeight)
local cpuWindow = window.create(mon, 1, subHeight + 1, subWidth, monHeight - subHeight)
local scheduledWindow = window.create(mon, subWidth + 1, 1, monWidth - subWidth, monHeight)
jobsWindow.setBackgroundColour(colors.blue)
cpuWindow.setBackgroundColour(colors.black)
scheduledWindow.setBackgroundColour(colors.cyan)
jobsWindow.clear()
cpuWindow.clear()
scheduledWindow.clear()

-- vaiables
local runProgram = true
local debug = true
local debugLog = "DEBUG\n"

local monitoredFile = "/ae2bridge/monitoredIndexes.txt"
local monitoredFileModified = 0
local monitoredIds = {}


local currentJobs = {} 



-- switches

local keybinds = {
    [keys.q] = function () runProgram = false end,
    [keys.d] = function () 
        local dfile = fs.open("/ae2bridge/debug.log", "w+")
        dfile.write(debugLog)
        dfile.close()
        runProgram = false 
    end,
}


-- functions

local function vPrint(str)
    if debug then
        debugLog = debugLog..str
    end
    write(str)
end


-- Given a string, returns a table of strings split by delim
local function split(str, delim)
    local valTable = {}
    local i = 1
    for k,_ in string.gmatch(str, "([^"..delim.."]+)") do
        valTable[i] = string.gsub(k, "%s", "")
        i = i + 1
    end
    return valTable
end



-- scanners
local function scanJobs()
    while true do
        -- local jobs = ae2.getIssuedCraftingJobs()
        -- for k, v in pairs(jobs) do
        --     jobsWindow.setCursorPos(1, k)
        --     jobsWindow.write("state: "..v["state"]..", jobID: "..v["jobID"])
        --     if v["systemID"]~=nil then jobsWindow.write(", systemID: "..v["systemID"]) end
        -- end

        local cpus = ae2.getCraftingCPUs()
        for k, v in pairs(cpus) do
            jobsWindow.setCursorPos(1, k)
            jobsWindow.clearLine()

            jobsWindow.write("CP: "..v["availableCoProcessors"]..", storage: "..v["availableStorage"]..", mode: "..v["selectionMode"])

            if v["jobStatus"] ~= nil then
                local status = v["jobStatus"]
                if status["output "]~= nil then jobsWindow.write(", item: "..status["output"]["displayName"]) end
                if status["totalObjects"] ~= nil then jobsWindow.write(", total: "..status["totalObjects"]) end
                if status["craftedObjects"] ~= nil then jobsWindow.write(", crafted: "..status["craftedObjects"]) end
                if status["elapsedNanos"] ~= nil then jobsWindow.write(", elapsed: "..(status["elapsedNanos"]/1000000).."s") end
            end
        end

        sleep(0.1)
    end
end

local function scanScheduled()
    while true do
        local jobs = ae2.getIssuedCraftingJobs()
        for k, v in pairs(jobs) do
            scheduledWindow.setCursorPos(1, k)
            scheduledWindow.write("state: "..v["state"]..", jobID: "..v["jobID"])
            if v["systemID"]~=nil then scheduledWindow.write(", systemID: "..v["systemID"]) end
        end

        sleep(0)
    end
end









local function scanMonitorClicks()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        mon.setCursorPos(1,1)
        mon.clearLine()
        mon.write("The monitor on side " .. side .. " was touched at (" .. x .. ", " .. y .. ")")
    end
end

local function scanItemsToMonitor()
    while true do
        local f
        local exists = fs.exists(monitoredFile)
        local fileModificationDate = fs.attributes(monitoredFile)["modified"]
        local wasModified = fileModificationDate ~= monitoredFileModified
        -- vPrint(tostring(exists).." "..tostring(fileModificationDate).." "..tostring(wasModified).."\n")
        
        if not exists then
            -- if file doesn't exist, create it
            f = fs.open(monitoredFile, "w")
            f.close()
        elseif wasModified then
            monitoredFileModified = fileModificationDate
            -- if file does exist check if modified, add to monitoredIndexes if yes
            monitoredIds = {}
            for line in io.lines(monitoredFile) do
                if line == nil then break end
                local parts = split(line,";")
                local id, buffer, batch = parts[1], parts[2], parts[3]
                if id == nil then break end
                monitoredIds[id] = {
                    ["buffer"] = buffer,
                    ["batch"] = batch,
                }
            end
            vPrint(textutils.serialise(monitoredIds).."\n")
        end
        if itemIn.list()[1] ~= nil then
            local idToAdd = itemIn.list()[1]["name"]
            itemIn.pushItems(peripheral.getName(itemOut), 1)
            if monitoredIds[idToAdd] == nil then
                vPrint("# Found new item: "..idToAdd.."\n")
                f = fs.open(monitoredFile, "a")
                f.writeLine(idToAdd..";0;0")
                f.close()
            end
        end
    end
end

local function scanKeyPress()
    while runProgram do
        local _, key = os.pullEvent("key")
        if key ~= nil and keybinds[key] ~= nil then keybinds[key]() end
    end
end

parallel.waitForAny(scanKeyPress, scanJobs, scanScheduled, scanItemsToMonitor)
vPrint("Exiting...\n")