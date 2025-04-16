local core = peripheral.wrap("left")
local ae2 = peripheral.wrap("back")
local has_block , block = turtle.inspect()
local colors = {"red", "orange", "yellow", "green", "lime", "cyan", "blue", "light_blue", "purple", "magenta", "pink", "brown", "white", "light_gray", "gray", "black"}
local box = peripheral.wrap("bottom")

function resetConn()
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(2)
    core.swing()
    core.swing()
    turtle.suck()
    turtle.select(3)
    turtle.place()
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(1)
end

function conn()
    ae2.items(false)
end

while true do 

    if pcall(conn) then
        print("yipppee moving on")
        blockPrev = textutils.serialize(block.name)
        print(blockPrev)
        if string.sub(blockPrev, -4, -2) == "log" then
            print("holy fuck a log")
            turtle.select(1)
            core.swing()
            has_block, block = turtle.inspect()
            blockPrev = textutils.serialize(block.name)
        elseif blockPrev == "nil" then
            local i = math.random(1, 16) 
            print(colors[i])
            local item = "spectrum:"..colors[i].."_sapling"
            ae2.pushItem("bottom",item, 1)
            turtle.suckDown()
            turtle.select(3)
            turtle.place()
            has_block, block = turtle.inspect()
            blockPrev = textutils.serialise(block.name)
        else
            has_block, block = turtle.inspect()
            blockPrev = textutils.serialise(block.name)
         end
    else
        print("no AE2?? no maidens???")
        resetConn()
        os.sleep(1)
    end
end
        
