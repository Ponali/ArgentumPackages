local fs = import("filesystem")
local ocif = import("ocif")

local args = {...}

if not args or not args[1] then
    shell.run("help ocifshow")
    return
end

local file = fs.concat(shell.workingDirectory, args[1])

local success, result = ocif.load(file)
assert(success,result)

termlib.write(string.rep("\n",result.height))
result:show(termlib.cursorPosX,termlib.cursorPosY-result.height)
