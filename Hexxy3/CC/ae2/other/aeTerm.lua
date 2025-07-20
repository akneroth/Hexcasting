local monitor = peripheral.find("monitor")
local term = peripheral.find("fulleng:crafting_terminal")

local x, y = monitor.getSize()
monitor.clear()

-- local methods = textutils.serialise(peripheral.getMethods(peripheral.getName(term)))
-- local lines = require "cc.strings".wrap(methods, x)
-- local f = fs.open("home/commands.txt", "w")
-- f.write(methods)
-- f.close()

local function tabWrite(name, tab)
    local methods = textutils.serialise(tab)
    local lines = require "cc.strings".wrap(methods, x)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write(name)
    -- os.pullEvent("key")
    for i = 1, #lines do
        monitor.setCursorPos(1, i + 1)
        monitor.write(lines[i])
    end
end


local m = {
    {s = "items", m = function () return term.items() end},
    {s = "getPatternsFor", m = function () return term.getPatternsFor("item", "ae2:red_smart_cable") end},
    {s = "getActiveCraftings", m = function () return term.getActiveCraftings() end},
    {s = "getChannelEnergyDemand", m = function () return term.getChannelEnergyDemand() end},
    {s = "getAverageEnergyIncome", m = function () return term.getAverageEnergyIncome() end},
    -- {s = "pullItem", m = function () return term.pullItem() end},
    {s = "getCraftableFluids", m = function () return term.getCraftableFluids() end},
    {s = "getAverageEnergyDemand", m = function () return term.getAverageEnergyDemand() end},
    {s = "getCraftingCPUs", m = function () return term.getCraftingCPUs() end},
    {s = "getEnergy", m = function () return term.getEnergy() end},
    {s = "getEnergyUnit", m = function () return term.getEnergyUnit() end},
    {s = "getConfiguration", m = function () return term.getConfiguration() end},
    -- {s = "pullFluid", m = function () return term.pullFluid() end},
    {s = "tanks", m = function () return term.tanks() end},
    -- {s = "scheduleCrafting", m = function () return term.scheduleCrafting() end},
    {s = "getChannelInformation", m = function () return term.getChannelInformation() end},
    -- {s = "pushItem", m = function () return term.pushItem() end},
    -- {s = "pushFluid", m = function () return term.pushFluid() end},
    {s = "getCraftableItems", m = function () return term.getCraftableItems() end},
    {s = "getEnergyCapacity", m = function () return term.getEnergyCapacity() end},
}

local function all()
    for k, v in pairs(m) do
        local res = v.m() or "nil"
        tabWrite(v.s, res)
        os.pullEvent("key")
    end
end

local function listen()
    while true do
        local e = os.pullEvent()
        write("a\n")
        write(textutils.serialise(e).."\n")
        sleep(0)
    end
end

parallel.waitForAll(all, listen)









-- @vizoe half of my code for the buffering program i was writing can be thrown out
