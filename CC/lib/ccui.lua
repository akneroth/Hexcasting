-- UI "Framework" by JustASnowflake v0.0.1


-- Setup

local priority = {
    tick = sleep(0.05),
    high = sleep(.2),
    med = sleep(.5),
    low = sleep(1),
}

local monitor = peripheral.find("monitor")
-- local window = monitor
local canvas = monitor
local monW, monH = monitor.getSize()
local canW, canH = canvas.getSize()


local function recalcBaseVars()
    monW, monH = monitor.getSize()
    canW, canH = canvas.getSize()
end


-- local function newWindow(posX, posY, width, height)
--     write(text)
--     scroll(y)
--     getCursorPos()
--     setCursorPos(x, y)
--     getSize()
--     clear()
--     clearLine()
--     getTextColour()
--     getTextColor()
--     setTextColour(colour)
--     setTextColor(colour)
--     getBackgroundColour()
--     getBackgroundColor()
--     setBackgroundColour(colour)
--     setBackgroundColor(colour)
--     isColour()
--     isColor()
--     blit(text, textColour, backgroundColour)
--     setPaletteColour(...)
--     setPaletteColor(...)
--     getPaletteColour(colour)
--     getPaletteColor(colour)



--     return {
--         setTextScale = monitor.setTextScale,
--         getTextScale = monitor.getTextScale,
--         write = monitor.write,
--         scroll = monitor.scroll,
--         getCursorPos = monitor.getCursorPos,
--         setCursorPos = monitor.setCursorPos,
--         getCursorBlink = monitor.getCursorBlink,
--         setCursorBlink = monitor.setCursorBlink,
--         getSize = monitor.getSize,
--         clear = monitor.clear,
--         clearLine = monitor.clearLine,
--         getTextColour = monitor.getTextColour,
--         getTextColor = monitor.getTextColor,
--         setTextColour = monitor.setTextColour,
--         setTextColor = monitor.setTextColor,
--         getBackgroundColour = monitor.getBackgroundColour,
--         getBackgroundColor = monitor.getBackgroundColor,
--         setBackgroundColour = monitor.setBackgroundColour,
--         setBackgroundColor = monitor.setBackgroundColor,
--         isColour = monitor.isColour,
--         isColor = monitor.isColor,
--         blit = monitor.blit,
--         setPaletteColour = monitor.setPaletteColour,
--         setPaletteColor = monitor.setPaletteColor,
--         getPaletteColour = monitor.getPaletteColour,
--         getPaletteColor = monitor.getPaletteColor,
--     }
-- end




-- UI Components

local buttons = {}
for i = 1, canW, 1 do
    buttons[i] = {}
end
local function addButton(posX, posY, color, text, func)
    local prevColor = canvas.getBackgroundColor()
    canvas.setCursorPos(posX, posY)
    canvas.setBackgroundColor(color)
    canvas.write(text)
    canvas.setBackgroundColor(prevColor)

    -- register button
    for i = 0, string.len(text) - 1, 1 do
        buttons[posX + i][posY] = func
    end
end

local function addPager(page, maxPage, onChange)
    local canvW, canvH = canvas.getSize()
    local pagerText = page .. " of " .. maxPage
    local pagerStartPos = math.floor(canvW / 2 - string.len(pagerText) / 2 + 1)
    local pagerEndPos = pagerStartPos + string.len(pagerText)
    canvas.setCursorPos(pagerStartPos, canvH)
    canvas.write(pagerText)
    addButton(pagerStartPos - 6, canvH, colors.green, "<<", function() onChange(1) end)
    addButton(pagerStartPos - 3, canvH, colors.green, " <",
        function() if page - 1 < 1 then onChange(1) else onChange(page - 1) end end)
    addButton(pagerEndPos + 1, canvH, colors.green, "> ",
        function() if page + 1 > maxPage then onChange(maxPage) else onChange(page + 1) end end)
    addButton(pagerEndPos + 4, canvH, colors.green, ">>", function() onChange(maxPage) end)
end






-- Constructors

local function returnConstr()
    return {
        clear = canvas.clear,
        addButton = addButton,
        addPager = addPager
    }
end

local function setMonitor(newMonitor)
    monitor = newMonitor
    canvas = monitor
    recalcBaseVars()
    return returnConstr()
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
