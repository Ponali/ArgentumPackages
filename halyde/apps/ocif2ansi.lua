local fs = import("filesystem")
local ocif = import("ocif")

local args = {...}

if not args or not args[1] or not args[2] then
    shell.run("help ocif2ansi")
    return
end

local file = fs.concat(shell.workingDirectory, args[1])
local outfile = fs.concat(shell.workingDirectory, args[2])

local success, result = ocif.load(file)

if success then
    local ansi = result:toansi()
    local out = fs.open(outfile,"w")
    out:write(ansi)
    out:close()
else
    print("Error: "..result)
end
