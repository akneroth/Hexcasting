require "ae2base"

local ae2crafting = {
    ae2 = {},
    items = {},
    watches = {},
    craftings = {},
    failedCraftings = {},
}

-- getPatternsFor
-- [
--  {
--      "inputs": [
--          {
--              "count": 1,
--              "maxStackCount": 64,
--              "name": "Oak logs",
--              "tags": {},
--              "techicalName": "minecraft:oak_log",
--              "type": "item"
--          }
--      ],
--      "outputs": [
--           {
--              "count": 4,
--              "maxStackCount": 64,
--              "name": "Oak Planks",
--              "tags": {},
--              "techicalName": "minecraft:oak_planks",
--              "type": "item"
--          }
--      ]
--  }
-- ]

---Check if provided key and amount meet prequisites for crafting
---@param key string
---@param amount number
---@return boolean
---@return table|nil
local function checkPrequisites(key, amount)
    local item = ae2crafting.items[key]
    local patterns = ae2crafting.ae2.getPatternsFor(toScheduleCraftingType(item.type), key)
    local neededForPattern = {}
    for _, pattern in ipairs(patterns) do
        local outputAmount = tableFind(pattern.outputs,
            function(z)
                return z.techicalName == key
            end
        ).count
        local craftingTimesNeeded = math.ceil(amount / outputAmount)
        local inputNeeded = tableMap(pattern.inputs,
            function(k, v)
                local tname = v.technicalName
                local tamount = v.count * craftingTimesNeeded
                if tname ~= nil and tamount ~= nil then
                    k = tname
                    v = tamount
                else
                    v = nil
                end
                return k, v
            end
        )
        local missing = {}
        for k, v in pairs(inputNeeded) do
            local neededItem = ae2crafting.items[k] or { displayName = "Error",amount = 0 }
            if neededItem.amount < v then
                table.insert(missing, neededItem.displayName.." "..neededItem.amount.."/"..v)
                break
            end
        end
        table.insert(neededForPattern, missing)
        if #missing == 0 then return true end
    end

    return false, neededForPattern
end

---try to schedule crafting
---@param key any
function ae2crafting:scheduleCrafting(key)
    local config = self.watches[key]
    local hasCrafting = self.craftings[key] ~= nil
    local isCrafting = self.active[key] ~= nil
    if hasCrafting and not isCrafting then
        local currentAmount = (self.items[key] or { amount = 0 }).amount
        local minAmount = config.minAmount
        local rawName = self.craftings[key].rawName
        local type = toScheduleCraftingType(rawNameType(rawName) or "item")
        
        -- print(CCpretty.pretty(craftConfig), currentAmount, minAmount, rawName, type)
        if currentAmount < minAmount and type ~= "none" then
            local prequisitesMet, missing = checkPrequisites(key, config.batchAmount)
            local success, response = false, "Prequisites not met\n  "..table.concat(missing or {}, "\n  ")
            if prequisitesMet then
                success = self.ae2.scheduleCrafting(type, key, config.batchAmount)
            end
            if success then
                self.failedCraftings[key] = nil
                self.active[key] = "Scheduled"
                mprint("Scheduled", config.batchAmount, self.craftings[key].displayName)
            end
            if not success and not self.failedCraftings[key] then
                self.failedCraftings[key] = true
                mprint(response)
            end
        end
    end
end

function ae2crafting:start(getDataFunction)
    ae2crafting.updateData = getDataFunction
    while true do
        self.ae2, self.items, self.watches, self.craftings = self.updateData()
        if isAnyEmpty(self.ae2, self.items, self.watches, self.craftings) then return end
        for key, _ in pairs(self.watches) do
            self:scheduleCrafting(key)
        end
        priority.low()
    end
end

return ae2crafting
