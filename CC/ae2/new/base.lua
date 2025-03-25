--- true if empty
---@param any table|string
---@return boolean
function isEmpty(any)
    if type(any) == "table" then
        for _, _ in pairs(any) do return false end
    end
    if type(any) == "string" then
        if string.len(any) > 0 then return false end
    end
    return true
end

---true if any param isEmpty
---@param ... any
---@return boolean
function isAnyEmpty(...)
    for _, value in ipairs(table.pack(...)) do
        if isEmpty(value) then return true end
    end
    return false
end


function getKeys(table)
    local out = {}
    for key, _ in pairs(table) do
        table.insert(out, key)
    end
    return out
end

function tableFind(table, findFunction)
    for k, v in pairs(table) do
        if findFunction(k, v) then
            return v, k
        end
    end
end

--
function tableMap(table, mapFunction)
    local mapped = {}
    for key, value in pairs(table) do
        local k, v = mapFunction(key, value)
        mapped[k] = v
    end
    return mapped
end