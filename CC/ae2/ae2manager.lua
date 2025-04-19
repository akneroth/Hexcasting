-- Variables
CCpretty = require "cc.pretty"
CCexpect = require "cc.expect"
CCcompletion = require "cc.completion"

local configPath = "/.config/ae2.json"
local config = ""
print("Looking for config", configPath)
if fs.exists(configPath) then
    for line in io.lines(configPath) do config = config .. " " .. line end
    config = textutils.unserialiseJSON(config)
    if type(config) ~= "table" then
        printError("Can't read " .. configPath)
    else
        print("Config", configPath, "read properly.")
    end
else
    printError("No config file found: " .. configPath)
end

base = require(config.lib_path .. "base")
ae2base = require(config.lib_path .. "ae2base")
craftingModule = require(config.lib_path .. "ae2crafting")
-- itemsModule = require (config.lib_path.."ae2items")


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
local monitor = peripheral.find("monitor")
if monitor ~= nil then
    monitor.clear()
    monitor.setTextScale(0.5)
end




local watchedItemsFile = __path .. "/watchedItems.json"

if arg[1] == "help" then
    mprint("Usage: " .. __programName .. " <systemName> [verbose]")
    return
else
    data.systemName = arg[1] or data.systemName
    for protocol, suffix in pairs(data.protocols) do
        data.protocols[protocol] = data.systemName .. suffix
    end
    data.verbose = arg[2] or false
end

-- ============================================================================
-- ============================         INIT         ==========================
-- ============================================================================

initRednet()
ae2 = initAE2(true)
if ae2 == nil then return end



-- ============================================================================
-- ============================================================================
-- ============================       THREADS        ==========================
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- ============================         DATA         ==========================
-- ============================================================================

function data:getItemInfo(key)
    mprint(self.items[key], self.craftings[key])
    local a, b = CCpretty.pretty(self.items[key]), CCpretty.pretty(self.craftings[key])
    textutils.pagedPrint(a .. "\n\n\n" .. b)

    return true, "Info printed"
end

function data:getData()
    local function checkAE2() ae2.items(false) end
    local ae2isFine = pcall(checkAE2)

    if not ae2isFine then ae2 = resetAE2("bottom") end

    local itemsRaw = ae2.items() or {}
    local craftingsRaw = ae2.getCraftableItems() or {}
    local activeCraftingRaw = ae2.getActiveCraftings() or {}
    
    while #itemsRaw == 0 do
        ae2 = resetAE2("bottom")
        if ae2 ~= nil then
            itemsRaw = ae2.items() or {}
            craftingsRaw = ae2.getCraftableItems() or {}
            activeCraftingRaw = ae2.getActiveCraftings() or {}
        end
        if #itemsRaw > 0 then mprint("AE2 data correct, proceeding.") end
    end

    if not self.init.data then
        mprint("Loaded", #itemsRaw, "items")
        mprint("Loaded", #craftingsRaw, "craftings")
        mprint("Loaded", #activeCraftingRaw, "active craftings")
        self.init.data = true
    end

    local craftingsBuffer = {}
    for i, value in ipairs(craftingsRaw) do
        local key = toTechnicalName(value.name)
        if key ~= nil then
            craftingsBuffer[key] = {
                rawName = value.name,
                type = rawNameType(value.name),
                displayName = value.displayName,
            }
        end
    end

    local itemsBuffer = {}
    for i, value in ipairs(itemsRaw) do
        local key = value.name -- mod:fullname
        if key ~= nil then
            local item = {
                amount = value.count,
                displayName = value.displayName,
                type = rawNameType(value.rawName),
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


    -- TODO cleanup?, it works for now
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
            mprint("Watched items file modified, updating...")
            local f = fs.open(watchedItemsFile, "r")
            local watchesRaw = {}
            if f ~= nil then
                watchesRaw = textutils.unserialiseJSON(f.readAll())
                f.close()
            end
            self.watched = watchesRaw
            mprint("Watches updated.")
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
        mprint("Editing watches...")
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
        if f ~= nil then
            f.write(textutils.serialiseJSON(watchesRaw))
            f.close()
        end
        mprint("Watches edited.")
    end
end

local function dataThread()
    while true do
        data:getData()
        data:saveWatches()
        data:updateWatches()
        priority.high()
    end
end


-- ============================================================================
-- ============================       CRAFTING       ==========================
-- ============================================================================
local function craftingThread()
    if craftingModule == nil then
        mprint("Can't initialise crafting module")
        return
    end

    local function getDataForCraftingModule() return ae2, data.items, data.watched, data.craftings, data.active end
    while true do
        craftingModule:iteration(getDataForCraftingModule)
        priority.low()
    end
end

-- ============================================================================
-- ============================        SENDER        ==========================
-- ============================================================================

function data:sendActiveCraftings()

end

local function senderThread()
    mprint("-- Sending to protocol:" .. data.protocols.sendItems)
    mprint("-- Sending to protocol:" .. data.protocols.sendActiveCrafting)
    while true do
        priority.low()
    end
end


-- ============================================================================
-- ============================       RECEIVER       ==========================
-- ============================================================================

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
        mprint(...)
        return true, table.concat(table.pack(...), " ")
    end
}

---@++
local commands_v2 = {
    watch = {
        add = function(...) return data:editWatch(...) end,
        edit = function(...) return data:editWatch(...) end,
        remove = function(...) return data:editWatch(...) end,
        list = function(...) return true, data.watched end,
        __default = {}
    },
    items = {
        info = function(...) return data:getItemInfo(table.unpack({ table.unpack(..., 2, #... - 1) })) end
    },
    __default = function(...)
        if ... == nil then return false, "no passed args", {} end
        mprint(...)
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
    mprint("Recieved command:", command, "| params:", table.concat(params, " "))

    local func = commands.default
    if commands[command] ~= nil then func = commands[command] end
    local response = { func(table.unpack(params)) }

    rednet.send(id, textutils.serialiseJSON(response), self.protocols.recieve)
end

local function recieverThread()
    rednet.host(data.protocols.recieve, data.systemName)
    mprint("-- Receiving from protocol:" .. data.protocols.recieve)
    while true do
        -- data:recieveCommands()
        priority.tick()
    end
end

-- ============================================================================
-- ============================       TERMINAL       ==========================
-- ============================================================================

-- autocomplete item key names (minecraft:dirt)
function data.completion:keyNameCompletionMatcher(stringParts, step)
    CCexpect.expect(1, stringParts, "table")
    CCexpect.expect(2, step, "number")

    local s = stringParts
    local modName = string.match(s[step], "^%w+%:")
    local itemName = string.match(s[step], "%:(%w+)%s?$")
    if data.verbose then
        mprint('"' .. tostring(modName) .. '"', '"' .. tostring(itemName) .. '"')
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
    local str = read(nil, self.completion.termHistory,
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
                mprint(" ")
                mprint(#s, textutils.serialise(s))
                mprint(s[#s], textutils.serialise(({ completions[#s]() })[2]))
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
        priority.tick()
    end
end

print("Started!")
parallel.waitForAny(craftingThread, senderThread, dataThread, recieverThread, terminalThread)
print("Finished!")
