-- UI "Framework" by JustASnowflake v0.0.1


-- Setup

local monitor = peripheral.find("monitor")
local ui = {
    monitor = monitor,
    canvas = monitor,
    priority = {
        tick = function () sleep(0.05) end,
        high = function () sleep(.2) end,
        med = function () sleep(.5) end,
        low = function () sleep(1) end,
    },
    buttons = {},
    monW = ({ monitor.getSize() })[1],
    monH = ({ monitor.getSize() })[2],
    canW = ({ monitor.getSize() })[1],
    canH = ({ monitor.getSize() })[2],
}

function ui:recalcBaseVars()
    self.monW, self.monH = self.monitor.getSize()
    self.canW, self.canH = self.canvas.getSize()
end

-- adds func as onClick for provided coordinates, returns if previous onClick was overwritten
function ui:addOnClick(x, y, func)
    if self.buttons[x] == nil then self.buttons[x] = {} end
    local prevFunc = self.buttons[x][y]
    self.buttons[x][y] = func
    if prevFunc == nil then return false else return true end
end

-- calls onClick for provided coordinates, returns if the function was called as first value and response if it was as second value
function ui:callOnClick(x, y)
    local col = self.buttons[x]
    if col == nil then return false end
    local func = col[y]
    if func == nil then return false end
    local response = func()
    return true, response
end

-- UI Components

function ui:addButton(posX, posY, color, text, func)
    local prevColor = self.canvas.getBackgroundColor()
    self.canvas.setCursorPos(posX, posY)
    self.canvas.setBackgroundColor(color)
    self.canvas.write(text)
    self.canvas.setBackgroundColor(prevColor)

    -- register button
    for i = 0, string.len(text) - 1, 1 do
        self:addOnClick(posX + i, posY, func)
    end
end

function ui:addPager(page, maxPage, onChange)
    local canvW, canvH = self.canW, self.canH
    local pagerText = page .. " of " .. maxPage
    local pagerStartPos = math.floor(canvW / 2 - string.len(pagerText) / 2 + 1)
    local pagerEndPos = pagerStartPos + string.len(pagerText)
    self.canvas.setCursorPos(pagerStartPos, canvH)
    self.canvas.write(pagerText)
    self:addButton(pagerStartPos - 6, canvH, colors.green, "<<", function() onChange(1) end)
    self:addButton(pagerStartPos - 3, canvH, colors.green, " <",
        function() if page - 1 < 1 then onChange(1) else onChange(page - 1) end end)
    self:addButton(pagerEndPos + 1, canvH, colors.green, "> ",
        function() if page + 1 > maxPage then onChange(maxPage) else onChange(page + 1) end end)
    self:addButton(pagerEndPos + 4, canvH, colors.green, ">>", function() onChange(maxPage) end)
end

-- Constructors

local function setMonitor(newMonitor)
    local out = ui
    out.monitor = newMonitor
    out.canvas = monitor
    out:recalcBaseVars()
    return out
end

-- local function setWindow(posX, posY, width, height)
--     window = newWindow
--     canvas = window
--     recalcBaseVars()
--     return returnConstr()
-- end



return {
    setMonitor = setMonitor,
    -- setWindow = setWindow,
}
