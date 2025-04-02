local basalt = require "basalt"
local CCpretty = require "cc.pretty"


local __path = fs.getDir(shell.getRunningProgram())
local __file = __path .. "/spells.json"
local data = {
    spells = {},
    mon = {},
    term = {},
}

local main = basalt.createFrame()
local monitor = peripheral.find("monitor")

if monitor then
    -- monitor.setTextScale(0.5)
    monitor.setTextScale(1)
    monitor.clear()
    local m, w, h = monitor, monitor.getSize()
    monitor = basalt.addMonitor():setSize(w, h)
    monitor:setMonitor(m)
else
    print("No monitor found. Exiting...")
    return
end

function data:getData()
    local f = fs.open(__file, "r")
    local json = f.readAll()
    f.close()
    local out = textutils.unserialiseJSON(json)
    self.spells = out.spells or {}
    return out
end

function data:saveData()
    local f = fs.open(__file, "w")
    local json = textutils.serialiseJSON(self.spells or {})
    f.write(json)
    f.close()
end

-- Variables init

data:getData()

--==================================================================================
--===============================         UI         ===============================
--==================================================================================


--==================================================================================
--===============================       MONITOR      ===============================
--==================================================================================

function data.setupMonitor()
    data.mon.spellListFrame = monitor:addFrame()
        :setPosition(1, 1)
        :setSize("parent.w * .3", "parent.h")

    data.mon.spellDescFrame = monitor:addFrame()
        :setPosition(data.mon.spellListFrame:getWidth() + 1, 1)
        :setSize(monitor:getWidth() - data.mon.spellListFrame:getWidth(), "parent.h")

    data.mon.spellNameLabel = data.mon.spellDescFrame:addLabel()
        :setPosition(2, 2)
        :setSize("parent.w - 2", 2)
        :setText("Selected spell name")
    data.mon.spellDescLabel = data.mon.spellDescFrame:addLabel()
        :setPosition(2, 4)
        :setSize("parent.w - 2", "parent.h - 4")
        :setText("Selected spell description")


    data.mon.spellList = data.mon.spellListFrame:addList()
        :setSize("parent.w - 1", "parent.h")
        :onSelect(
            function(self, event, item)
                basalt.debug(item.text)

                local spellName = string.match(item.text, "^(%g+)")
                local spell = data.spells[spellName] or { desc = "No spell" }
                data.mon.spellNameLabel:setText(item.text)
                data.mon.spellDescLabel:setText(spell.desc)
            end
        )
        :onResize(data.mon.checkScrollbar)

    local index = 1
    for name, info in pairs(data.spells) do
        local c = colors.black
        if math.fmod(index, 2) == 0 then c = colors.gray end
        index = index + 1
        if info.params then name = name .. " " .. info.params end
        data.mon.spellList:addItem(name, c, colors.white)
    end

    data.mon.spellListScrollbar = data.mon.spellListFrame:addScrollbar()
        :setPosition("parent.w", 1)
        :setSize(1, "parent.h")
        :onChange(
            function(self, _, value)
                basalt.debug(value)
                data.mon.spellList:setOffset(value - 1)
            end
        )

    function data.mon.checkScrollbar()
        local scrAmount = data.mon.spellList:getItemCount() - data.mon.spellList:getHeight()
        if scrAmount > 0 then
            data.mon.spellListScrollbar:show()
            data.mon.spellListScrollbar:setScrollAmount(scrAmount)
        else
            data.mon.spellListScrollbar:hide()
        end
    end

    data.mon:checkScrollbar()
end

function data.setupTerminal()
    data.term.listFrame = main:addFrame()
        :setPosition(1, 1)
        :setSize("parent.w", "parent.h")

    data.term.label = data.term.listFrame:addLabel()
        :setPosition(3, 3)
        :setSize("parent.w - 5", "parent.h - 5")
        :setText("This is WIP, don't touch it")
end

--==================================================================================
--===============================    BASALT START    ===============================
--==================================================================================

data.setupMonitor()
data.setupTerminal()

basalt.autoUpdate()
