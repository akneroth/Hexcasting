-- Variables
local CCpretty = require "cc.pretty"
local CCexpect = require "cc.expect"
local CCcompletion = require "cc.completion"

local data = {
    items = {},
    craftings = {},
    active = {},
    watched = {},
    watchedToEdit = {},
    itemTypes = {
        item = "item",
        block = "item",
        fluid = "fluid",
    },
    completion = {
        dict = {
            termModCompletion = {},
            termKeyNameCompletion = {},
        },
        termHistory = {},
    },
    errorMessages = {
        watchAddEditMessage = "\nUse: watch add|edit <key> <minAmount> [batchAmount]",
        watchRemoveMessage = "\nUse: watch remove <key>",
    },
    watchedLastModified = 0,
    systemName = "snowflake_ae2",
    protocols = {
        sendItems = "_items",
        sendActiveCrafting = "_activeCrafting",
        recieve = "_manager",
    },
    priority = {
        tick = function() sleep(0.05) end,
        high = function() sleep(.2) end,
        med = function() sleep(.5) end,
        low = function() sleep(1) end,
    },
    verbose = false,
    init = {
        data = false,
    },
}

local ae2 = peripheral.find("fulleng:crafting_terminal")
local modem = peripheral.find("modem")
local monitor = peripheral.find("monitor")
if monitor ~= nil then
    monitor.clear()
    monitor.setTextScale(0.5)
end
local lastLine = 1

local function print(...)
    local args = {}
    for _, value in ipairs(table.pack(...)) do
        table.insert(args, tostring(value))
    end

    if monitor == nil then
        _G.print(args)
    else
        local text = table.concat(args, " ")
        monitor.setCursorPos(1, lastLine)
        monitor.clearLine(text)
        monitor.write(text)
        local monW, monH = monitor.getSize()
        if lastLine == monH then
            monitor.scroll(1)
        else
            lastLine = lastLine + 1
        end
    end
end





local path = fs.getDir(shell.getRunningProgram())
local watchedItemsFile = path .. "/watchedItems.json"

local programName = fs.getName(shell.getRunningProgram())
if arg[1] == "help" then
    print("Usage: " .. programName .. " <systemName> [verbose]")
    return
else
    data.systemName = arg[1] or data.systemName
    for protocol, suffix in pairs(data.protocols) do
        data.protocols[protocol] = data.systemName .. suffix
    end
    data.verbose = arg[2] or false
end





-- INIT

rednet.open(peripheral.getName(modem))

if not rednet.isOpen() then
    print("Rednet connection is not open. Please check if wireless modem is attached to the computer")
    print("Terminating...")
    return
else
    print("Rednet connection is open")
end

if ae2 == nil then
    print("No AE2 connection attached. Please attach one of the blocks:")
    print("  AE2 1K Crafting Storage")
    print("  AE2 Energy Cell")
    print("  Fullblock Crafting Terminal")
    return
else
    print("AE2 connection established...")
end



-- Threads
-- Data

function data:getItemInfo(key)
    print(self.items[key], self.craftings[key])
    local a, b = CCpretty.pretty(self.items[key]), CCpretty.pretty(self.craftings[key])
    textutils.pagedPrint(a .. "\n\n\n" .. b)

    return true, "Info printed"
end

function data:getData()
    local itemsRaw = ae2.items()
    while #itemsRaw == 0 do
        print("AE2 Item data empty!!! Reseting connection...")
        redstone.setOutput("bottom", true)
        sleep(15)
        redstone.setOutput("bottom", false)
        sleep(10)
        print("Connection reset, requesting item data...")
        itemsRaw = ae2.items()
        if #itemsRaw > 0 then
            print("AE2 Item data correct, proceeding.")
        end
    end

    local craftingsRaw = ae2.getCraftableItems()
    local activeCraftingRaw = ae2.getActiveCraftings()

    if not self.init.data then
        print("Loaded", #itemsRaw, "items")
        print("Loaded", #craftingsRaw, "craftings")
        print("Loaded", #activeCraftingRaw, "active craftings")
        self.init.data = true
    end

    local craftingsBufferRaw = {}
    local craftingsBuffer = {}
    for i, value in ipairs(craftingsRaw) do
        local key = table.concat(table.pack(string.match(value.name, "^%g+%.(%g+)%.(%g+)$")), ":") -- item.mod.fullname -> mod:fullname
        if key ~= nil then
            craftingsBuffer[key] = {
                rawName = value.name,
                displayName = value.displayName,
            }
        end
    end

    local itemsBuffer = {}
    for i, value in ipairs(itemsRaw) do
        local key = value.name or nil -- mod:fullname
        if key ~= nil then
            local item = {
                amount = value.count,
                displayName = value.displayName,
                rawName = value.rawName -- item.mod.fullname
            }
            itemsBuffer[key] = item
        end
    end

    local activeCraftingBuffer = {}
    for i, value in ipairs(activeCraftingRaw) do
        local targetInfo = value.target
        if targetInfo ~= nil then
            local key = targetInfo.name
            activeCraftingBuffer[key] = {
                rawName = targetInfo.rawName,
                displayName = targetInfo.displayName,
                amount = targetInfo.count,
                type = targetInfo.type,
                progress = value.progress,
                progressMax = value.amount,
            }
        end
    end

    local completionsRaw = {}
    local completionsModRaw = {}
    local completionsModBuffer = {}
    local completionsKeyNameBuffer = {}

    for key, _ in pairs(craftingsBuffer) do table.insert(completionsRaw, key) end
    local rawStr = table.concat(completionsRaw, " ")
    for m, n in string.gmatch(rawStr, "(%g+):(%g+)") do
        if completionsModRaw[m .. ":"] == nil then completionsModRaw[m .. ":"] = {} end
        completionsModRaw[m .. ":"][n] = true
    end

    for key, value in pairs(completionsModRaw) do
        table.insert(completionsModBuffer, key)
        if completionsKeyNameBuffer[key] == nil then completionsKeyNameBuffer[key] = {} end
        for subKey, _ in pairs(value) do
            table.insert(completionsKeyNameBuffer[key], key .. subKey)
        end
    end

    self.items = itemsBuffer
    self.craftings = craftingsBuffer
    self.active = activeCraftingBuffer
    self.completion.dict.termModCompletion = completionsModBuffer
    self.completion.dict.termKeyNameCompletion = completionsKeyNameBuffer
end

function data:updateWatches()
    local exists = fs.exists(watchedItemsFile)
    if exists then
        local modified = fs.attributes(watchedItemsFile).modified
        if modified > self.watchedLastModified then
            self.watchedLastModified = modified
            print("Watched items file modified, updating...")
            local f = fs.open(watchedItemsFile, "r")
            local watchesRaw = {}
            if f ~= nil then watchesRaw = textutils.unserialiseJSON(f.readAll()) end
            f.close()
            self.watched = watchesRaw
            print("Watches updated.")
        end
    end
end

function data:editWatch(...)
    local operations = {
        add = "add",
        edit = "edit",
        remove = "remove",
    }
    local args = { ... }
    local operation = args[1]
    local key = args[2]
    local minAmount = tonumber(args[3] or "0")
    local batchAmount = tonumber(args[4] or "0")

    if batchAmount == 0 and minAmount ~= 0 then batchAmount = math.floor(minAmount / 4) end

    local addEditMessage = self.errorMessages.watchAddEditMessage
    local removeMessage = self.errorMessages.watchRemoveMessage
    local usageMessage = addEditMessage .. removeMessage

    if type(key) ~= "string" then
        return false, "Key must be a string" .. usageMessage
    end

    if operation == operations.add or operation == operations.edit then
        if self.watched[key] ~= nil and operation == operations.add then
            return false, "Watch under that name already exists" .. addEditMessage
        end
        if minAmount == 0 then
            return false, "minAmount must be a number" .. addEditMessage
        end
    end
    if operation == operations.remove then
        if self.watched[key] == nil then
            return false, "Watch under that key doesn't exist" .. removeMessage
        end
    end

    local watch = {
        key = key,
        minAmount = minAmount,
        batchAmount = batchAmount,
        operation = operation
    }
    table.insert(self.watchedToEdit, watch)
    return true, "Watch edited"
end

function data:saveWatches()
    local exists = fs.exists(watchedItemsFile)
    local amountToEdit = #data.watchedToEdit
    if exists and amountToEdit > 0 then
        print("Editing watches...")
        local watchesRaw = self.watched
        while #self.watchedToEdit > 0 do
            local value = table.remove(self.watchedToEdit, 1)
            if value.operation == "remove" then
                watchesRaw[value.key] = nil
            else
                watchesRaw[value.key] = {
                    minAmount = value.minAmount,
                    batchAmount = value.batchAmount,
                }
            end
        end

        local f = fs.open(watchedItemsFile, "w")
        if f ~= nil then f.write(textutils.serialiseJSON(watchesRaw)) end
        f.close()
        print("Watches edited.")
    end
end

local function dataThread()
    while true do
        data:getData()
        data:saveWatches()
        data:updateWatches()
        data.priority.high()
    end
end

-- Crafting

function data:handleCraftings()
    for key, craftConfig in pairs(self.watched) do
        local hasCrafting = self.craftings[key] ~= nil
        local isCrafting = self.active[key] ~= nil
        if hasCrafting and not isCrafting then
            local currentAmount = (self.items[key] or { amount = 0 }).amount
            local minAmount = craftConfig.minAmount
            local rawName = self.craftings[key].rawName
            local type = self.itemTypes[string.match(rawName, "(%w+)%.")]
            -- print(CCpretty.pretty(craftConfig), currentAmount, minAmount, rawName, type)
            if currentAmount < minAmount and type ~= "none" then
                ae2.scheduleCrafting(type, key, craftConfig.batchAmount)
                self.active[key] = "Scheduled"
                print("Scheduled", craftConfig.batchAmount, self.craftings[key].displayName)
            end
        end
    end
end

local function craftingThread()
    while true do
        data:handleCraftings()
        data.priority.med()
    end
end

-- Sender

function data:sendActiveCraftings()

end

local function senderThread()
    print("-- Sending to protocol:" .. data.protocols.sendItems)
    print("-- Sending to protocol:" .. data.protocols.sendActiveCrafting)
    while true do
        data.priority.low()
    end
end


-- Reciever

-- returns: boolean, string, [table]
local commands = {
    watch = function(...)
        local subCommands = {
            add = function(...) return data:editWatch(...) end,
            edit = function(...) return data:editWatch(...) end,
            remove = function(...) return data:editWatch(...) end,
            list = function(...) return true, data.watched end
        }
        if ... == nil then return true, "Available commands", subCommands end
        local f = subCommands[...]
        if f ~= nil then return f(...) end
        if f == nil and ... ~= nil then
            return false,
                "No such sub command" .. data.errorMessages.watchAddEditMessage .. data.errorMessages.watchRemoveMessage
        end
        return true,
            "Watches management" .. data.errorMessages.watchAddEditMessage .. data.errorMessages.watchRemoveMessage
    end,
    items = function(...)
        local subCommands = {
            info = function(...) return data:getItemInfo(table.unpack({ table.unpack(..., 2, #... - 1) })) end
        }
        if ... == nil then return true, "Available commands", subCommands end
        local f = subCommands[...]
        if f ~= nil then return f(...) end
        if f == nil and ... ~= nil then
            return false,
                "No such sub command"
        end
        return true,
            "Items management"
    end,
    default = function(...)
        if ... == nil then return nil end
        print(...)
        return true, table.concat(table.pack(...), " ")
    end
}

function completion()
    local mainCommand = {}
    local subCommands = {}
    for key, value in pairs(commands) do
        table.insert(mainCommand, key)
        local done, mess, tab = value()
        if type(tab) == "table" then
            for subKey, _ in pairs(tab) do
                table.insert(subCommands, subKey)
            end
        end
    end
    return table.pack(mainCommand, subCommands)
end

function data:recieveCommands()
    local id, str = rednet.receive(self.protocols.recieve)
    local parts = {}
    for v in string.gmatch(str, "%g+") do
        table.insert(parts, v)
    end
    local command = table.remove(parts, 1)
    local params = parts
    print("Recieved command:", command, "| params:", table.concat(params, " "))

    local func = commands.default
    if commands[command] ~= nil then func = commands[command] end
    local response = { func(table.unpack(params)) }

    rednet.send(id, textutils.serialiseJSON(response), self.protocols.recieve)
end

local function recieverThread()
    rednet.host(data.protocols.recieve, data.systemName)
    print("-- Receiving from protocol:" .. data.protocols.recieve)
    while true do
        -- data:recieveCommands()
        data.priority.tick()
    end
end

-- Terminal
-- autocomplete item key names (minecraft:dirt)
function data.completion:keyNameCompletionMatcher(stringParts, step)
    CCexpect.expect(1, stringParts, "table")
    CCexpect.expect(2, step, "number")

    local s = stringParts
    local modName = string.match(s[step], "^%w+%:")
    local itemName = string.match(s[step], "%:(%w+)%s?$")
    if data.verbose then
        print('"' .. tostring(modName) .. '"', '"' .. tostring(itemName) .. '"')
    end

    if modName ~= nil then
        local t = {}
        for _, value in pairs(self.dict.termKeyNameCompletion[modName]) do
            local a = string.match(value, "^" .. modName .. (itemName or ""))
            if a ~= nil then table.insert(t, value) end
        end
        return true, t
    else
        return false, self.dict.termModCompletion
    end
end

function data:recieveFromTerminal()
    local str = read(nil, self.termHistory,
        function(text)
            local s = {}
            local completions = {
                [1] = function() return true, completion()[1] end,
                [2] = function() return true, completion()[2] end,
                [3] = function()
                    local a = string.gsub(s[2], " ", "")
                    if a == "add" or a == "edit" or a == "remove" then
                        return data.completion:keyNameCompletionMatcher(s, 3)
                    end
                    return false, {}
                end,
            }
            for v in string.gmatch(text, "%g+%s?") do
                table.insert(s, v)
            end
            if #s == 0 or #s > 3 then return CCcompletion.choice(text, {}) end
            if data.verbose then
                print(" ")
                print(#s, textutils.serialise(s))
                print(s[#s], textutils.serialise(({ completions[#s]() })[2]))
            end
            local addSpace, list = completions[#s]()
            return CCcompletion.choice(s[#s], list, addSpace)
        end
    )
    table.insert(self.completion.termHistory, str)
    if str == nil then return end
    local parts = {}
    for v in string.gmatch(str, "%g+") do
        table.insert(parts, v)
    end
    local command = table.remove(parts, 1)
    local params = parts

    local func = commands.default
    if commands[command] ~= nil then func = commands[command] end
    local response = { func(table.unpack(params)) }
    local isError = response[1] == false
    local function p(...) if isError then _G.printError(...) else _G.print(...) end end
    for i, v in ipairs(response) do
        if type(v) == "table" then CCpretty.pretty_print(v) end
        if type(v) == "string" then p(v) end
        if type(v) == "boolean" and self.verbose then p(v) end
        if type(v) == "number" then p(v) end
    end
end

local function terminalThread()
    while true do
        data:recieveFromTerminal()
        data.priority.tick()
    end
end


parallel.waitForAny(craftingThread, senderThread, dataThread, recieverThread, terminalThread)
