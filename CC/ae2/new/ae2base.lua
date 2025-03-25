CCpretty = require "cc.pretty"
CCexpect = require "cc.expect"
CCcompletion = require "cc.completion"
require "base"

_path = fs.getDir(shell.getRunningProgram())
_programName = fs.getName(shell.getRunningProgram())
local _config = _path .. "/config.json"

base = {
    monitor = nil
}

base.monitor = peripheral.find("monitor")
base.monitor.clear()
base.monitor.setCursorPos(1, 1)

priority = {
    tick = function() sleep(0.05) end,
    high = function() sleep(0.2) end,
    med = function() sleep(0.5) end,
    low = function() sleep(0.1) end,
}

---Prints passed args as string on monitor if connected, else prints them in terminal
---@param ... any
function mprint(...)
    local args = {}
    for _, value in ipairs(table.pack(...)) do
        table.insert(args, tostring(value))
    end

    if base.monitor == nil then
        _G.print(args)
    else
        local text = table.concat(args, " ")
        local cX, cY = base.monitor.getCursorPos()
        local monW, monH = base.monitor.getSize()
        
        base.monitor.clearLine(text)
        base.monitor.write(text)

        if cY == monH then
            base.monitor.scroll(1)
            base.monitor.setCursorPos(1, cY)
        else
            base.monitor.setCursorPos(1, cY + 1)
        end
    end
end

function log(...)
    mprint(...)
end


---Opens rednet connection or terminates if requirements are not met.
function initRednet()
    local modem = peripheral.find("modem")
    rednet.open(peripheral.getName(modem))

    if modem == nil then
        mprint("No wireless modem attached to the computer. Please attach wireless or ender modem.")
        mprint("Terminating...")
        return
    end

    if not rednet.isOpen() then
        mprint("Rednet connection is not open. Please check if wireless modem is attached to the computer")
        mprint("Terminating...")
        return
    else
        mprint("Rednet connection is open")
    end
end

---Initialise ae2 connection via any correct block, returns table wit ae2 functions or nil if there is no ae2 block that can be used.
---@param verbose boolean
---@return table|nil
function initAE2(verbose)
    CCexpect.expect(1, verbose, "boolean")
    local allowed = {
        "fulleng:crafting_terminal",
        "ae2:energy_cell",
        "ae2:dense_energy_cell",
        "ae2:1k_crafting_storage",
        "ae2:4k_crafting_storage",
        "ae2:16k_crafting_storage",
        "ae2:64k_crafting_storage",
        "ae2:256k_crafting_storage",
    }
    local ae2 = nil
    for _, p in ipairs(allowed) do
        ae2 = peripheral.find(p)
        if ae2 ~= nil then break end
    end

    if verbose then
        if ae2 == nil then
            mprint("No AE2 connection attached. Please attach one of the blocks:")
            for _, value in ipairs(allowed) do
                mprint("  " .. value)
            end
        else
            mprint("AE2 connection established...")
        end
    end

    return ae2
end

---@alias side
---| "top"
---| "bottom"
---| "front"
---| "back"
---| "left"
---| "right"
---Resets ae2 connnection. Uses redstone to set of block breaking and replacing mechanism
---@param redstoneOutput side
---@return table|nil
function resetAE2(redstoneOutput)
    mprint("AE2 Item data empty!!! Reseting connection...")
    redstone.setOutput(redstoneOutput, true)
    sleep(5)
    redstone.setOutput(redstoneOutput, false)
    sleep(5)
    return initAE2(false)
end

--- returns parsed name, returns if was parsed from rawName as second argument
---@param rawName string
---@return string|nil
---@return boolean|nil
function toTechnicalName(rawName)
    local mod, name = string.match(rawName, "^%g+%.(%g+)%.(%g+)$")
    local fallbackMod, fallbackName = string.match(rawName, "^(%g+)%:(%g+)$")
    local n = {}
    if not isEmpty(name) then n = {mod, name} else n = {fallbackMod, fallbackName} end
    if isEmpty(n) then return end
    return table.concat(n, ":"), not isEmpty(name)
end

--- returns parsed name, returns if was parsed from technicalName as second argument
---@alias ae2type
---| "item"
---| "block"
---| "fluid"
---
---@param technicalName string
---@param type ae2type
---@return string|nil
---@return boolean|nil
function toRawName(technicalName, type)
    local mod, name = string.match(technicalName, "^(%g+)%:(%g+)$")
    local fallbackMod, fallbackName = string.match(technicalName, "^%g+%.(%g+)%.(%g+)$")
    local n = {}
    if not isEmpty(name) then n = {mod, name} else n = {fallbackMod, fallbackName} end
    if isEmpty(n) then return end
    table.insert(n, 1, type)
    return table.concat(n, "."), not isEmpty(name)
end

--- returns type from rawName
---@param rawName string
---@return string|nil
function rawNameType(rawName)
    local type = string.match(rawName, "^(%g+)%.%g+%.%g+$")
    if isEmpty(type) then return end
    return type
end

--- changes type to the one used in scheduleCrafting()
---@param type string
---@return string|nil
function toScheduleCraftingType(type)
    local types = {
        item = "item",
        block = "item",
        fluid = "fluid",
    }
    return types[type]
end
