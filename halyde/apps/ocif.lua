local component = import("component")
local gpu = component.gpu
local fs = import("filesystem")
local ocif = import("ocif")
local event = import("event")

local args = {...}

if not args or not args[1] then
    return shell.run("help ocif")
end

local cmd = table.remove(args,1)

local bg = nil
local bgArgIdx = table.find(args,"-b") or table.find(args,"--background")
if bgArgIdx then
    table.remove(args,bgArgIdx)
    bg = tonumber(table.remove(args,bgArgIdx),16)
end

local fullscreen = false
local fsArgIdx = table.find(args,"-f") or table.find(args,"--fullscreen")
if fsArgIdx then
   table.remove(args,fsArgIdx)
   fullscreen = true
end

if cmd=="show" then
    if #args<1 then
        return shell.run("help ocif")
    end

    local file = fs.concat(shell.workingDirectory, args[1])

    local success, result = ocif.load(file)
    assert(success,result)

    if fullscreen then
        local width,height = gpu.getResolution()
        gpu.setResolution(result.width or width,result.height or height)
        result:show(1,1)
        local evargs
        while not evargs or evargs[4]~=keyboard.keys["enter"] do
            evargs = {event.pull("key_down")}
        end
        gpu.setResolution(width,height)
        clear()
    else
        termlib.write(string.rep("\n",result.height))
        local x,y = termlib.cursorPosX,termlib.cursorPosY-result.height
        if bg~=nil then
            gpu.setBackground(bg)
            gpu.fill(x,y,result.width,result.height," ")
        end
        result:show(x,y)
    end

elseif cmd=="to-ansi" then
    if #args<2 then
        return shell.run("help ocif")
    end
    local file = fs.concat(shell.workingDirectory, args[1])
    local outfile = fs.concat(shell.workingDirectory, args[2])

    local success, result = ocif.load(file)
    assert(success,result)

    local ansi = result:toansi(bg)
    local out = fs.open(outfile,"w")
    out:write(ansi)
    out:close()
else
    print("Command \""..cmd.."\" does not exist.")
    return shell.run("help ocif")
end
