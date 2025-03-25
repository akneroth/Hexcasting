local crafting = require "ae2crafting"
require "ae2base"

print(tostring(isEmpty("hello")))

-- crafting:start(function() return "hello", "there", {"general", "kenobi"} end)

local t = {
    a = "aaa",
    b = "bbb",
    c = "ccc",
    d = "ddd",
    item = "name of item"
}

print("find",
    tableFind(t,
        function(k, v)
            return (v == "aaa" or v == "ddd")
        end
    )
)

print("map",
    CCpretty.pretty_print(
        tableMap(t,
            function(k, v)
                return k, string.gsub(v, "%g", "X")
            end
        )
    )
)
