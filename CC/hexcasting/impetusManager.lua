local CCpretty = require "cc.pretty"

local __path = fs.getDir(shell.getRunningProgram())

local manager = {
    maxBufferedMedia = (tonumber(arg[1]) or 5000),
    circles = {},
    dataFile = __path .. "/circles.json",

    monitor = nil,
}

local function isImpetus(name)
    if type(name) ~= "string" then return false end
    if string.find(name, "impetus", nil, true) ~= nil then return true end
    return false
end

local function isRelay(name)
    if type(name) ~= "string" then return false end
    if string.find(name, "redstone_relay", nil, true) ~= nil then return true end
    return false
end


function manager:mwrite(x, y, clear, ...)
    self.monitor.setCursorPos(x, y)
    if clear then self.monitor.clearLine() end
    local parts = {}
    for _, v in ipairs(table.pack(...)) do table.insert(parts, tostring(v)) end
    self.monitor.write(table.concat(parts, " "))
end

function manager:readFile()
    if not fs.exists(self.dataFile) then return end
    local f = fs.open(self.dataFile, "r")
    local fromJson = textutils.unserialiseJSON(f.readAll())
    if fromJson == nil then return end
    for index, value in ipairs(fromJson) do
        local impetus = peripheral.wrap(value.impetusName)
        local relay = peripheral.wrap(value.relayName)
        local circle = {
            impetusName = value.impetusName,
            relayName = value.relayName,
            impetus = impetus,
            relay = relay,
            receivingMedia = false,
        }
        if impetus ~= nil and relay ~= nil then
            table.insert(self.circles, circle)
        end
    end
    f.close()
end

function manager:updateFile()
    local f = fs.open(self.dataFile, "w")
    local toJson = {}
    for key, value in pairs(self.circles) do
        local circle = {
            impetusName = value.impetusName,
            relayName = value.relayName,
        }
        table.insert(toJson, circle)
    end
    f.write(textutils.serialiseJSON(toJson))
    f.close()
end

function manager:addCircle(impetusName, relayName)
    local circle = {
        impetusName = impetusName,
        relayName = relayName,
        impetus = peripheral.wrap(impetusName),
        relay = peripheral.wrap(relayName),
        receivingMedia = false,
        media = 0,
    }

    self.circles[impetusName] = circle
    self:mwrite(1, 1, true, "Added circle", impetusName, "+", relayName)
    self:updateFile()
end

function manager:removeCircle(peripheralName)
    for key, value in pairs(self.circles) do
        if value.impetusName == peripheralName or value.relayName == peripheralName then
            self:mwrite(1, 1, true, "Removed circle", value.impetusName, "+", value.relayName)
            self.circles[key] = nil
        end
    end
    self:updateFile()
end

function manager.listenAttach()
    local attached = {}
    while true do
        local _, p = os.pullEvent("peripheral")
        print(_, p)
        table.insert(attached, p)

        local e1peek, e2peek = attached[1], attached[2]
        local impetus, relay
        if isImpetus(e1peek) and isRelay(e2peek) then
            impetus = table.remove(attached, 1)
            relay = table.remove(attached, 1)
            manager:addCircle(impetus, relay)
        end
        if isImpetus(e2peek) and isRelay(e1peek) then
            impetus = table.remove(attached, 1)
            relay = table.remove(attached, 1)
            manager:addCircle(impetus, relay)
        end
        if not isImpetus(e1peek) and not isRelay(e1peek) then
            table.remove(attached, 1)
        end
    end
end

function manager.listenDetach()
    while true do
        local _, p = os.pullEvent("peripheral_detach")
        print(_, p)
        if isImpetus(p) or isRelay(p) then
            manager:removeCircle(p)
        end
    end
end

function manager.manageCasting()
    while true do
        for key, circle in pairs(manager.circles) do
            if circle.impetus ~= nil and circle.relay ~= nil then
                if not circle.impetus.isCasting() then
                    circle.impetus.activateCircle()
                end
            end
        end
        sleep(0.05)
    end
end

function manager.manageMedia()
    while true do
        for key, circle in pairs(manager.circles) do
            if circle.impetus ~= nil and circle.relay ~= nil then
                circle.media = (circle.impetus.getMedia() or 0) / 10000

                if circle.media < manager.maxBufferedMedia then
                    circle.relay.setOutput("top", true)
                    manager.circles[key].receivingMedia = true
                else
                    circle.relay.setOutput("top", false)
                    manager.circles[key].receivingMedia = false
                end

            end
        end
        sleep(0.5)
    end
end


function manager.showInfo()
    local mon = manager.monitor
    while true do
        if mon then
            local mW, mH = mon.getSize()
            for i = 3, mH, 1 do
                mon.setCursorPos(1, i)
                mon.clearLine()
                mon.setCursorPos(1, 2)
                mon.write("==================================== TEMPORARY DASHBOARD ====================================")
            end
            local circles = {}
            for key, value in pairs(manager.circles) do
                table.insert(circles, value)
            end

            for index, value in ipairs(circles) do
                mon.setCursorPos(1, index + 2)
                mon.clearLine()
                local str = {
                    [1] = "Impetus " .. string.match(value.impetusName, "%_(%w+)$"),
                    [14] = "Relay " .. string.match(value.relayName, "%_(%w+)$"),
                    [28] = "Media: " .. ((value.impetus.getMedia() or 0) / 10000),
                    [42] = "Recharging: "..tostring(value.receivingMedia),
                }
                for key, strPart in pairs(str) do
                    mon.setCursorPos(key, index + 2)
                    mon.write(strPart)
                end
            end
        end

        sleep(0.5)
    end
end

function manager:start()
    self:readFile()
    self.monitor = peripheral.find("monitor")
    if self.monitor then
        self.monitor.setTextScale(0.5)
        self.monitor.clear()
        self.monitor.setCursorPos(1, 1)
    end
    parallel.waitForAny(self.listenAttach, self.listenDetach, self.showInfo, self.manageCasting, self.manageMedia)
end

manager:start()
