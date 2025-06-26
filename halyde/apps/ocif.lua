local component = import("component")
local gpu = component.gpu
local fs = import("filesystem")
local ocif = import("ocif")

local args = {...}

if not args or not args[1] then
    return shell.run("help ocif")
end

local cmd = table.remove(args,1)

if cmd=="show" then
    if #args<1 then
        return shell.run("help ocif")
    end

    local bg = nil
    if table.find(args,"-b") then
        local idx = table.find(args,"-b")
        table.remove(args,idx)
        bg = tonumber(table.remove(args,idx),16)
    end
    local file = fs.concat(shell.workingDirectory, args[1])

    local success, result = ocif.load(file)
    assert(success,result)

    termlib.write(string.rep("\n",result.height))
    local x,y = termlib.cursorPosX,termlib.cursorPosY-result.height
    if bg~=nil then
        gpu.setBackground(bg)
        gpu.fill(x,y,result.width,result.height," ")
    end
    result:show(x,y)

elseif cmd=="to-ansi" then
    if #args<2 then
        return shell.run("help ocif")
    end
    local file = fs.concat(shell.workingDirectory, args[1])
    local outfile = fs.concat(shell.workingDirectory, args[2])

    local success, result = ocif.load(file)
    assert(success,result)

    local ansi = result:toansi()
    local out = fs.open(outfile,"w")
    out:write(ansi)
    out:close()
else
    print("Command \""..cmd.."\" does not exist.")
    return shell.run("help ocif")
end
