-- Author: JustASnowflake


local mon = peripheral.find("monitor")
if mon == nil then return end
write("Found monitor\n")
mon.setTextScale(0.8)
mon.clear()
local monWidth, monHeight = mon.getSize()
write("Changed monitor scale, new resolution: "..monWidth.."x"..monHeight.."\n")

local ae2 = peripheral.find("ae2cc_adapter")
if ae2 == nil then return end
write("Connected to AE2 adapter\n")

local db = ae2.getAvailableObjects()
local columns = 2

-- items {k: name, v: {index, amount, display name}}
local items = {}
local lookupList = {"minecraft:redstone", "minecraft:diamond"}
for i, v in ipairs(lookupList) do
    write("-- Adding "..v.." to monitored items\n")
    items[v] = {
        ["index"] = i,
        ["amount"] = 0,
    }
end

for _, item in ipairs(db) do
    local id = item["id"]
    if items[id] ~= nil and items["displayName"] == nil then
        write("--- Setting "..id.." name to "..item["displayName"].."\n")
        items[id]["displayName"] = item["displayName"]
    end
end

local function updateDashboard(id)
    -- <name> <spacer> <amount> <col spacer> <name> <spacer> <amount>
    local maxColWidth = math.floor(monWidth/columns)
    local amountWidth = 5
    local spacer = 2
    local nameLen = math.floor(maxColWidth - spacer - amountWidth)
    local index = items[id]["index"]
    local row = math.floor(index/(columns+1))+1
    local col = math.fmod(index, columns)
    local colOffset = (nameLen + spacer + amountWidth + spacer) * col
    if colOffset == 0 then colOffset = 1 end

    local name = string.sub(items[id]["displayName"], 1, nameLen)
    local amount = items[id]["amount"]
    local displayAmount

    write("Updating "..name..", pos: "..row.." "..col.." to "..amount.."\n")

    if amount < 10000 then displayAmount = tostring(amount)
    elseif amount < 1000000 then displayAmount = tostring(math.floor(amount/1000)).."K"
    elseif amount < 1000000000 then displayAmount = tostring(math.floor(amount/1000000)).."M"
    else displayAmount = tostring(math.floor(amount/1000000000)).."B"
    end

    mon.setCursorPos(colOffset, row)
    mon.write(string.rep(" ", colOffset))
    mon.setCursorPos(colOffset, row)
    mon.write(name)
    mon.setCursorPos(colOffset + nameLen + spacer, row)
    mon.write(displayAmount)
end

local function checkItems()
    db = ae2.getAvailableObjects()
    for _, item in ipairs(db) do
        local id = item["id"]

        if items[id] ~= nil and items[id]["amount"] ~= item["amount"] then
            write("$ "..id.." amount "..items[id]["amount"].."->"..item["amount"].."\n")
            items[id]["amount"] = item["amount"]
            updateDashboard(id)
        end
    end
end


while true do
    checkItems()
    sleep(5)
end

