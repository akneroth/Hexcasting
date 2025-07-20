local function writeLn(str) write(str .. "\n") end

local function getAeItems(ae2)
    local aeItems = {}
    for _, v in pairs(ae2.getAvailableObjects()) do
        aeItems[v.id] = {
            type = v.type,
            displayName = v.displayName,
            amount = v.amount,
        }
    end
    return aeItems
end

local function getAeCraftings(ae2)
    local aeCraftings = {}
    for _, v in pairs(ae2.getCraftableObjects()) do
        aeCraftings[v.id] = true
    end
    return aeCraftings
end

local function updateItemsMeta(data, aeItems, aeCraftings)
    for k, v in pairs(data.watches) do
        local aeDisplayName
        local aeType
        local aeAmount
        if (aeItems[k] ~= nil) then
            aeDisplayName = aeItems[k].displayName
            aeType = aeItems[k].type
            aeAmount = aeItems[k].amount
        else
            aeDisplayName = nil
            aeType = nil
            aeAmount = nil
        end
        local aeCraftable = aeCraftings[k] or false

        data.watches[k].displayName = v.displayName or aeDisplayName
        data.watches[k].type = aeType or v.type or "item"
        data.watches[k].buffer = v.buffer
        data.watches[k].batch = v.batch
        data.watches[k].amount = aeAmount or 0
        data.watches[k].inCrafting = v.inCrafting
        data.watches[k].craftable = aeCraftable
    end
    return data
end


-- Scans for items from all sources: dbFile, itemIn peripheral and ae2.
-- Takes the data object and returnes it updated
local function itemScanner(data)
    local itemIn = data.config.peripherals.itemIn
    local itemOut = data.config.peripherals.itemOut
    local ae2 = data.config.peripherals.ae2
    local f
    local exists = fs.exists(data.config.dbFile)
    local itemInInput = #itemIn.list() > 0
    local saveToDb = itemInInput

    -- get all items and available crafting recipies from AE2
    local aeItems = getAeItems(ae2)
    local aeCraftings = getAeCraftings(ae2)


    -- if file doesn't exist, create it with empty json array
    if not exists then
        f = fs.open(data.config.dbFile, "w")
        f.write("[\n]")
        f.close()
    end

    local lastModified = fs.attributes(data.config.dbFile)["modified"]
    local wasModified = lastModified ~= data.config.dbModified

    -- if file does exist check if modified, if it was, read everything from the file
    if wasModified or itemInInput then
        write("DB file modified, scanning... ")
        data.config.dbModified = lastModified

        f = fs.open(data.config.dbFile, "r")
        local readJson = f.readAll()
        f.close()
        readJson = textutils.unserialiseJSON(readJson)
        -- data.watches = {}

        local update = {}
        for _, v in ipairs(readJson) do
            update[v.id] = {
                displayName = v.displayName,
                type = v.type,
                buffer = v.buffer,
                batch = v.batch,
            }
        end

        -- if item is inserted into input, add it to update
        if itemInInput then
            for slot, item in pairs(itemIn.list()) do
                if item ~= nil then
                    item = itemIn.getItemDetail(slot)
                    itemIn.pushItems(peripheral.getName(itemOut), slot)
                    local itemToAdd = {
                        displayName = item.displayName,
                        type = nil,
                        buffer = item.maxCount,
                        batch = item.maxCount,
                    }
                    if update[item.name] == nil then
                        update[item.name] = itemToAdd
                    end
                end
            end
        end


        -- update runtime db with data from dbFile
        for k, v in pairs(update) do
            if data.watches[k] == nil then
                data.watches[k] = update[k]
            else
                data.watches[k].displayName = update[k].displayName
                data.watches[k].type = update[k].type
                data.watches[k].buffer = update[k].buffer
                data.watches[k].batch = update[k].batch
            end
        end
        -- remove from runtime db records that are no longer in dbFile
        for k, v in pairs(data.watches) do
            if update[k] == nil then
                data.watches[k] = nil
            end
        end
    end

    -- add additional meta to watches
    data = updateItemsMeta(data, aeItems, aeCraftings)

    if wasModified or itemInInput then
        if saveToDb then
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
            local writeJson = textutils.serialiseJSON(toSerialise)
            f = fs.open(data.config.dbFile, "w+")
            f.write(writeJson)
            f.close()

            -- update modification date to avoid scanning the same data again
            lastModified = fs.attributes(data.config.dbFile)["modified"]
            data.config.dbModified = lastModified
        end
        write("Done\n")
        -- writeLn(textutils.serialise(data.watches))
    end

    return data
end

local function handleCrafting(data)
    local events = {
        ["ae2cc:crafting_cancelled"] = function(event, jobId, cancelReason)
            writeLn("ae2cc:crafting_cancelled")
        end,
        ["ae2cc:crafting_done"] = function(event, jobId)
            writeLn("ae2cc:crafting_done")
            local itemId = data.crafting[jobId].id
            local craftedAmount = data.crafting[jobId].amount
            data.watches[itemId].amount = data.watches[itemId].amount + craftedAmount
            data.watches[itemId].inCrafting = data.watches[itemId].inCrafting - craftedAmount
        end,
        ["ae2cc:crafting_started"] = function(event, jobId)
            writeLn("ae2cc:crafting_started")
        end
    }

    for id, item in pairs(data.watches) do
        local amount, inCrafting, buffer, batch =
            item.amount or 0, item.inCrafting or 0, item.buffer or 0, item.batch or 0

        while #data.events.ae2 > 0 do
            local e = table.remove(data.events.ae2)
            if events[e.event] ~= nil then events[e.event](e.event, e.jobId) end
        end

        if amount + inCrafting < buffer then
            -- get amount of missing items (below buffer), add remainder to ceil multiplicative batch
            -- and scheduleCrafting
            local missing = buffer - (amount + inCrafting)
            local remainder = batch - math.fmod(missing, batch)
            data.watches[id].inCrafting = missing + remainder

            local craftJobId = data.config.peripherals.ae2.scheduleCrafting(item.type or "item", id, missing + remainder)
            data.crafting[craftJobId] = {
                id = id,
                amount = missing + remainder
            }
        end
    end
    return data
end


return {
    itemScanner = itemScanner,
    handleCrafting = handleCrafting
}
