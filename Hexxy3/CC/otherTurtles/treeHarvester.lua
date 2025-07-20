local kinetic = peripheral.find("plethora:kinetic")
-- local colors = {"red", "orange", "yellow", "green", "lime", "cyan", "blue", "light_blue", "purple", "magenta", "pink", "brown", "white", "light_gray", "gray", "black"}

local data = {
    flags = {
        verbose = false,
        forceChop = false,
    },
    axeName = "botania:terra_axe",
    slots = {
        sapling = nil,
        axeSilk = nil,
        axeFortune = nil,
        axeFallback = nil,
    },
    tags = {
        axeAny = "minecraft:axes",
        enchantSilk = "minecraft:silk_touch",
        enchantFortune = "minecraft:fortune",
        logAny = "minecraft:logs",
        logNormal = "minecraft:overworld_natural_logs",
        logSpectrum = "spectrum:colored_logs",
        saplingAny = "minecraft:saplings",
        saplingSpectrum = "spectrum:colored_saplings",
    }
}

for index, value in ipairs(arg) do
    if value == "debug" then
        data.flags.verbose = true
    elseif value == "forceChop" then
        data.flags.forceChop = true
    end
end

local function vPrint(...)
    if data.flags.verbose then
        print(...)
    end
end

local function checkSlots()
    for key, value in pairs(data.slots) do
        data.slots[key] = nil
    end
    for i = 1, 16 do
        local item = turtle.getItemDetail(i, true)
        if item then
            if item.name == data.axeName and item.enchantments then
                for _, value in pairs(item.enchantments) do
                    if value.name == data.tags.enchantFortune then
                        data.slots.axeFortune = i
                    elseif value.name == data.tags.enchantSilk then
                        data.slots.axeSilk = i
                    end
                end
            elseif item.tags[data.tags.saplingAny] then
                data.slots.sapling = i
            end

            -- set fallback axe just in case some enchanted axe is not available
            if item.tags[data.tags.axeAny] and not data.slots.axeFallback then
                data.slots.axeFallback = i
            end
        end
    end
    vPrint("axeSilk:", data.slots.axeSilk)
    vPrint("axeFortune:", data.slots.axeFortune)
    vPrint("axeFallback:", data.slots.axeFallback)
end

local function checkBlock()
    local isBlock, block = turtle.inspect()
    return isBlock, isBlock and block.tags or nil, isBlock and block.name or nil
end

local function useAxe(axeSlot)
    local slot = axeSlot or data.slots.axeFallback
    if not slot then return false end
    turtle.select(slot)
    local item = turtle.getItemDetail() or {}
    if item.tags then
        if not item.tags[data.tags.axeAny] and data.flags.forceChop then
            turtle.select(data.slots.axeFallback)
        end
    end
    while checkBlock() do
        kinetic.swing()
        sleep(.05)
    end
end

checkSlots()
while true do
    local isBlock, tags, name = checkBlock()
    if not isBlock then
        checkSlots()
        if data.slots.sapling then
            turtle.select(data.slots.sapling)
            turtle.place()
        else
            turtle.suckDown(1)
        end
    elseif tags[data.tags.logSpectrum] then
        print("Chopping spectrum colored log", name)
        useAxe(data.slots.axeSilk)
    elseif tags[data.tags.logNormal] then
        print("Chopping natural overworld log", name)
        useAxe(data.slots.axeFortune)
    end
    sleep(.05)
end
