local name, version = "hextra", "v1.1.0"


local component,computer,event,fs=import("component"),import("computer"),import("event"),import("filesystem")
local gpu = component.gpu
local width,height = gpu.getResolution()

local yieldTime=computer.uptime()
local function yieldIfRequired()
    if computer.uptime()>yieldTime+4 then
        coroutine.yield()
    end
end

local content = {}
local chunkLength = 256

local bytesPerRow = 16
local rowIdxLength = 8
local bytePadding = 1
if width<115 then bytePadding=0 end
-- local rowLength = rowIdxLength+1+bytesPerRow*(2+bytePadding)-bytePadding+1+bytesPerRow
local rowLength = rowIdxLength+2+bytesPerRow*(3+bytePadding)-bytePadding
local rowByteLength = rowIdxLength+1+bytesPerRow*(2+bytePadding)-bytePadding

local cursor = 0
local scroll = 0


local cmdargs = {...}
local limit, newFile, fpath
if table.find(cmdargs,"-l") then
    local idx = table.find(cmdargs,"-l")
    table.remove(cmdargs,idx)
    limit = tonumber(table.remove(cmdargs,idx))
    if not limit then
        print("Argument -l must have a value.")
        return shell.run("help "..name)
    end
end
if table.find(cmdargs,"-n") then
    local idx = table.find(cmdargs,"-n")
    table.remove(cmdargs,idx)
    local nf = table.remove(cmdargs,idx)
    if not nf then
        print("Argument -n must have a value.")
        return shell.run("help "..name)
    end
    if string.find(nf,":") then
        local colon = string.find(nf,":")
        newFile = {tonumber(nf:sub(1,colon-1)),tonumber(nf:sub(colon+1),16)}
    else
        newFile = {tonumber(nf),0}
    end
else
    fpath = cmdargs[1]
    if not fpath then
        print("No file specified.")
        return shell.run("help "..name)
    end
end

local fileLength
if newFile==nil then
    if fpath:sub(1, 1) ~= "/" then
        fpath = fs.concat(shell.workingDirectory, fpath)
    end
    local file = fs.open(fpath,"rb")
    repeat
        local dlen = chunkLength
        if limit~=nil and #content>limit/chunkLength-1 then
            dlen = limit%chunkLength
        end
        local data = file:read(dlen)
        if data~=nil then table.insert(content,data) end
        yieldIfRequired()
    until data==nil or (limit~=nil and #content>=limit/chunkLength)
    file:close()
    fileLength = (#content-1)*chunkLength+string.len(content[#content])
else
    repeat
        local dlen = chunkLength
        if #content>newFile[1]/chunkLength-1 then
            dlen = newFile[1]%chunkLength
        end
        local data = string.rep(string.char(newFile[2]),dlen)
        table.insert(content,data)
        yieldIfRequired()
    until #content>=newFile[1]/chunkLength
    fileLength = newFile[1]
end

-- decoding table

local function bin(x)
    ret=""
    while x~=1 and x~=0 do
        ret=tostring(x%2)..ret
        x=math.modf(x/2)
    end
    ret=tostring(x)..ret
    return ret
end

local function bytesToInt(bytes)
    local res = 0
    for i=1,#bytes do
      res = (res<<8)&0xFFFFFFFF | bytes[i]
    end
    return res
end

local function readInt(readByte,n)
    n = n or 1
    if n==1 then return readByte(1) end
    -- local bytes, res = {string.byte(self:read(n),1,n)}, 0
    local bytes = {}
    for i=1,n do
        table.insert(bytes,readByte())
    end
    return bytesToInt(bytes)
end

local function largeNum(x)
    if math.abs(x)>9223372036854775807 then return string.format("%e",x) end -- 64bit integer limit. anything above have no integer representation
    if math.abs(x)>=1e+13 then return string.format("%d",x) end
    return string.format("%f",x)
end

local function readUniChar(readByte)
    local function inRange(min,max,...)
        for _,v in ipairs({...}) do
            if not (v and v>=min and v<max) then return false end
        end
        return true
    end
    local function readByte0() return readByte() or 0 end

    local byte = readByte()

    if byte < 0x80 then
        -- ASCII character (0xxxxxxx)
        return byte
    elseif byte < 0xC0 then
        -- Continuation byte (10xxxxxx), invalid at start position
        return nil
    elseif byte < 0xE0 then
        -- 2-byte sequence (110xxxxx 10xxxxxx)
        local byte2 = readByte0()
        if inRange(0x80,0xC0,byte2) then
            local code_point = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
            return code_point
        end
    elseif byte < 0xF0 then
        -- 3-byte sequence (1110xxxx 10xxxxxx 10xxxxxx)
        local byte2, byte3 = readByte0(), readByte0()
        if inRange(0x80,0xC0,byte2,byte3)then
            local code_point = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
            return code_point
        end
    elseif byte < 0xF8 then
        -- 4-byte sequence (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
        local byte2, byte3, byte4 = readByte0(), readByte0(), readByte0()
        if inRange(0x80,0xC0,byte2,byte3,byte4) then
            local code_point = ((byte & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
            return code_point
        end
    end

    -- Invalid UTF-8 byte sequence
    return nil
end

local decodingTable = {
    {
        ["title"]="Binary",
        ["shortTitle"]="bin",
        ["maxLength"]=8,
        ["bytes"]=1,
        ["decode"]=function(readByte)
            local out = bin(readByte())
            return string.rep("0",8-#out)..out
        end
    },
    {
        ["title"]="Octal",
        ["shortTitle"]="oct",
        ["maxLength"]=3,
        ["bytes"]=1,
        ["decode"]=function(readByte) return string.format("%o",readByte()) end
    },
    {
        ["title"]="Signed 8-bit",
        ["shortTitle"]="int8",
        ["maxLength"]=#("-128"),
        ["bytes"]=1,
        ["decode"]=function(readByte)
            local b = readInt(readByte,1)
            if b&0x80>0 then b=b-0x100 end
            return string.format("%d",b)
        end
    },
    {
        ["title"]="Unigned 8-bit",
        ["shortTitle"]="uint8",
        ["maxLength"]=#("255"),
        ["bytes"]=1,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,1)) end
    },
    {
        ["title"]="Signed 16-bit",
        ["shortTitle"]="int16",
        ["maxLength"]=#("-32768"),
        ["bytes"]=2,
        ["decode"]=function(readByte)
            local b = readInt(readByte,2)
            if b&0x8000>0 then b=b-0x10000 end
            return string.format("%d",b)
        end
    },
    {
        ["title"]="Unigned 16-bit",
        ["shortTitle"]="uint16",
        ["maxLength"]=#("65535"),
        ["bytes"]=2,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,2)) end
    },
    {
        ["title"]="Signed 32-bit",
        ["shortTitle"]="int32",
        ["maxLength"]=#("-2147483648"),
        ["bytes"]=4,
        ["decode"]=function(readByte)
            local b = readInt(readByte,4)
            if b&0x80000000>0 then b=b-0x100000000 end
            return string.format("%d",b)
        end
    },
    {
        ["title"]="Unigned 32-bit",
        ["shortTitle"]="uint32",
        ["maxLength"]=#("65535"),
        ["bytes"]=4,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,4)) end
    },
    {
        ["title"]="Float 32-bit",
        ["shortTitle"]="float",
        ["maxLength"]=#("-9223372036854775807"),
        ["bytes"]=4,
        ["decode"]=function(readByte)
            local bytes = {}
            for i=1,4 do table.insert(bytes,readByte()) end
            local exp = ((bytes[1]&0x7F)<<1)|bytes[2]>>7
            local mant = bytesToInt({bytes[2]&0x7F,bytes[3],bytes[4]})
            local absv = (1+mant/8388608)*math.pow(2,exp-127)
            local sign = 1
            if bytes[1]&0x80>0 then sign=-1 end
            return largeNum(sign*absv)
        end
    },
    {
        ["title"]="UTF-8 Character",
        ["shortTitle"]="UTF-8",
        ["maxLength"]=1,
        ["bytes"]=1,
        ["decode"]=function(readByte) return unicode.char(readUniChar(readByte)) end
    },
    {
        ["title"]="Unicode code point",
        ["shortTitle"]="Index",
        ["maxLength"]=#("U+10FFFF"),
        ["bytes"]=1,
        ["decode"]=function(readByte) return string.format("U+%04x",readUniChar(readByte)) end
    }
}

local noBytesText = "Not enough bytes"

if width<115 then
    for i=1,#decodingTable do
        decodingTable[i].title = decodingTable[i].shortTitle
    end
    -- the floating point and 32 bit numbers takes most time and screen space
    table.remove(decodingTable,9)
    noBytesText = "---"
end

local decodingTitleLength = 1
local decodingOutputLength = #noBytesText
for _,v in ipairs(decodingTable) do
    decodingTitleLength=math.max(decodingTitleLength,#v.title)
    decodingOutputLength=math.max(decodingOutputLength,v.maxLength)
end

local rbuf = assert(gpu.allocateBuffer(),"No render buffer available.")
gpu.setActiveBuffer(rbuf)
gpu.setBackground(0)
gpu.fill(1,1,160,50," ")

local function prompt(txt,default)
    gpu.setActiveBuffer(0)
    termlib.cursorPosX = 1
    termlib.cursorPosY = 1
    local out = read(nil,"\x1b[107m\x1b[30m"..txt,default)
    gpu.setActiveBuffer(rbuf)
    gpu.bitblt(0,1,1,width,1,rbuf,1,1)
    return out
end

local function getByte(idx)
    return content[math.floor(idx/chunkLength)+1]:byte(idx%chunkLength+1,idx%chunkLength+1)
end

local function setByte(idx,val)
    local chunk = math.floor(idx/chunkLength)+1
    local chunkidx = idx%chunkLength+1
    local str = content[chunk]
    content[chunk]=str:sub(1,chunkidx-1)..string.char(val)..str:sub(chunkidx+1)
end

local function save(saveAs)
    if saveAs or fpath==nil then
        local npath = prompt("Save location: ",fpath)
        if npath and npath~="" then fpath=npath end
    end
    if not fpath or fpath=="" then return end
    local file = fs.open(fpath,"wb")
    for i=1,#content do
        file:write(content[i])
    end
    file:close()
end

local hextype=""

local function renderByte(idx,cursorHighlight)
    local x = idx%bytesPerRow
    local screenX = 10+x*(2+bytePadding)
    local textX = 10+bytesPerRow*(2+bytePadding)-bytePadding+1
    local y = math.floor(idx/bytesPerRow)+1-scroll
    if idx>=fileLength then
        gpu.setForeground(0x707070)
        gpu.set(screenX,y,"--")
        gpu.setForeground(0xFFFFFF)
        return
    end
    local byte = getByte(idx)
    local specialByte = byte<32 or (byte>=0x7F and byte<=0x9F)
    local onCursor = idx==cursor and cursorHighlight

    if onCursor then
        gpu.setForeground(0)
        gpu.setBackground(0xFFFFFF)
    else
        if specialByte then gpu.setForeground(0x0080FF) end
    end

    local bhex = string.format("%02x",byte)
    if #hextype==0 then
        gpu.set(screenX,y,bhex)
    else
        if not onCursor then gpu.setForeground(0xFF8000) end
        gpu.set(screenX,y,hextype..bhex:sub(2))
        if not onCursor then gpu.setForeground(0xFFFFFF) end
    end

    if width>=80 then
        if specialByte then
            gpu.set(textX+x,y,".")
            if not onCursor then gpu.setForeground(0xFFFFFF) end
        else
            local ch
            if byte>127 then ch=string.char(0xC0|(byte>>6),0x80|(byte&0x3F)) else ch=string.char(byte) end
            gpu.set(textX+x,y,ch)
        end
    end
    if onCursor then
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0)
    end
end

local function renderRow(y)
    gpu.setForeground(0x999999)
    gpu.set(1,y,string.format("%0"..rowIdxLength.."x",(y-1+scroll)*bytesPerRow))
    gpu.setForeground(0xFFFFFF)
    for i=(y-1)*bytesPerRow,y*bytesPerRow-1 do renderByte(i+scroll*bytesPerRow,true) end
end

local function renderAllRows()
    for i=1,math.min(math.ceil(fileLength/bytesPerRow),height) do
        renderRow(i)
        yieldIfRequired()
    end
end

local function renderDecodingBorder()
    if width<80 then return end
    local start = width-2-decodingOutputLength-decodingTitleLength
    local tableHeight = #decodingTable
    gpu.setForeground(0x80FF80)
    gpu.set(width,1,"┓")
    gpu.set(width-1-decodingOutputLength,1,"┯")
    gpu.set(start,1,"┏")
    gpu.fill(start+1,1,decodingTitleLength,1,"━")
    gpu.fill(width-decodingOutputLength,1,decodingOutputLength,1,"━")
    gpu.fill(start,2,1,tableHeight,"┃")
    gpu.fill(width-decodingOutputLength-1,2,1,tableHeight,"│")
    gpu.fill(width,2,1,tableHeight,"┃")
    gpu.set(start,tableHeight+2,"┗")
    gpu.set(width-1-decodingOutputLength,tableHeight+2,"┷")
    gpu.set(width,tableHeight+2,"┛")
    gpu.fill(start+1,tableHeight+2,decodingTitleLength,1,"━")
    gpu.fill(width-decodingOutputLength,tableHeight+2,decodingOutputLength,1,"━")

    gpu.set(width-#("Decoding table")-1,1,"Decoding table")

    gpu.setForeground(0xEEEEEE)
    for i,v in ipairs(decodingTable) do
        gpu.set(width-1-decodingOutputLength-#v.title,i+1,v.title)
    end

    gpu.setForeground(0xFFFFFF)
end

local function updateDecodingTable()
    if width<80 then return end
    local readcur
    local function readByte()
        local out = getByte(readcur)
        readcur=readcur+1
        return out
    end

    gpu.setBackground(0)
    local x = width-decodingOutputLength
    gpu.fill(x,2,decodingOutputLength,#decodingTable," ")

    for i=1,#decodingTable do
        if cursor+decodingTable[i].bytes>fileLength then
            gpu.setForeground(0x808080)
            gpu.set(x,i+1,noBytesText)
            goto continue
        end
        gpu.setForeground(0xFFFFFF)
        readcur=cursor
        local out
        local success = pcall(function()
            out = decodingTable[i].decode(readByte)
        end)
        if success then
            if out==nil then
                gpu.setForeground(0x808080)
                gpu.set(x,i+1,"nil")
            elseif out=="" then
                gpu.setForeground(0x808080)
                gpu.set(x,i+1,"Empty")
            else
                gpu.set(x,i+1,out)
            end
        else
            gpu.setForeground(0xFF8888)
            gpu.set(x,i+1,"Error")
        end
        ::continue::
    end
    gpu.setForeground(0xFFFFFF)
end

local inputModeX = 1
local inputModeY = #decodingTable+3
local inputMode = 0

local function initControlsText()
    if width<80 then
        inputModeX = rowByteLength+5
        inputModeY = height
        gpu.set(rowByteLength+5,inputModeY,"Bytes")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(rowByteLength+2,inputModeY,"^I")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)
    elseif width<115 then
        inputModeX = width-#("Bytes")
        gpu.set(width-#("nput mode: Bytes"),inputModeY,"nput mode:")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("^Input mode: Bytes"),inputModeY,"^I")
        gpu.setForeground(0x60FF60) gpu.setBackground(0)
        gpu.set(width-#("Bytes"),inputModeY,"Bytes")
        gpu.setForeground(0xFFFFFF)
    else
        inputModeX = width-#("Bytes)")
        gpu.set(width-#(" - Toggle input mode (Bytes)"),inputModeY," - Toggle input mode (Bytes)")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("^I - Toggle input mode (Bytes)"),inputModeY,"^I")
        gpu.setForeground(0x60FF60) gpu.setBackground(0)
        gpu.set(width-#("Bytes)"),inputModeY,"Bytes")
        gpu.setForeground(0xFFFFFF)
    end

    if width<80 then
        gpu.set(rowByteLength+5,height-1,"Save")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(rowByteLength+2,height-1,"^S")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)

        gpu.set(rowByteLength+5,height-2,"Exit")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(rowByteLength+2,height-2,"^X")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)

        gpu.set(rowByteLength+5,height-3,"Jump")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(rowByteLength+2,height-3,"^J")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)
    else
        gpu.set(width-#("Jump to address"),#decodingTable+4,"Jump to address")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("^J Jump to address"),#decodingTable+4,"^J")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)

        gpu.set(width-#("Save as"),#decodingTable+5,"Save as")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("Shift+^S Save as"),#decodingTable+5,"Shift+^S")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)

        gpu.set(width-#("Save"),#decodingTable+6,"Save")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("^S Save"),#decodingTable+6,"^S")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)

        gpu.set(width-#("Exit"),#decodingTable+7,"Exit")
        gpu.setForeground(0) gpu.setBackground(0xFFFFFF)
        gpu.set(width-#("^X Exit"),#decodingTable+7,"^X")
        gpu.setForeground(0xFFFFFF) gpu.setBackground(0)
    end
end

local function initSideContent()
    renderDecodingBorder()
    updateDecodingTable()

    initControlsText()

    gpu.setForeground(0x606060)
    local str = name.." "..version
    local y = height
    if width<80 then str=version y=1 end
    gpu.set(width-#str+1,y,str)
    gpu.setForeground(0xFFFFFF)
end

renderAllRows()
initSideContent()

local function applyScroll(dist)
    scroll=scroll+dist
    gpu.setBackground(0)
    if dist==1 then
        gpu.copy(1,2,rowLength,height-1,0,-1)
        gpu.fill(1,height,rowLength,1," ")
        renderRow(height)
    else
        gpu.copy(1,1,rowLength,height-1,0,1)
        gpu.fill(1,1,rowLength,1," ")
        renderRow(1)
    end
end

local cursorBlink = true
local function moveCur(dist)
    if #hextype>0 then hextype="" end
    cursorBlink=true
    local curnew = math.max(math.min(cursor+dist,fileLength-1),0)
    if cursor==curnew then
        return renderByte(cursor,true)
    end

    local y = math.floor(curnew/bytesPerRow)-scroll
    if y<0 then applyScroll(-1) end
    if y>=height then applyScroll(1) end
    renderByte(cursor,false)
    cursor=curnew
    renderByte(cursor,true)
    updateDecodingTable()
end

local function typeHex(key)
    cursorBlink=true
    hextype=hextype..key
    if #hextype==1 then
        renderByte(cursor,true)
    else
        setByte(cursor,tonumber(hextype,16))
        hextype=""
        moveCur(1)
    end
end

local function typeByte(byte)
    cursorBlink=true
    setByte(cursor,byte)
    moveCur(1)
end

local function jump()
    local curnew = tonumber(prompt("Jump to location: ",string.format("0x%08x",cursor)))
    if curnew==nil then return end
    curnew=math.max(math.min(curnew,fileLength-1),0)
    if curnew==cursor then return end
    scroll=math.max(math.min(math.floor(curnew/bytesPerRow),math.ceil(fileLength/bytesPerRow-height)),0)

    cursor=curnew
    gpu.setBackground(0)
    gpu.fill(1,1,rowLength,height," ")
    renderAllRows()
    gpu.bitblt()
end

local function toggleInputMode()
    inputMode=(inputMode+1)%2
    gpu.setForeground(0x60FF60)
    gpu.set(inputModeX,inputModeY,({"Bytes","Text "})[inputMode+1])
    gpu.setForeground(0xFFFFFF)
    gpu.bitblt()
end

while true do
    local args = {event.pull(0.5)}
    if args and args[1] then
        if args[1]=="key_down" then
            cursorBlink = true
            local key = keyboard.keys[args[4]]
            if key==nil then goto continue end
            local code = args[3]
            if code==13 then code=10 end
            if keyboard.ctrlDown then
                if key=="x" then break end
                if key=="s" then save(keyboard.shiftDown) end
                if key=="j" then jump() end
                if key=="i" then toggleInputMode() end
            else
                if key=="left" or code==8 then moveCur(-1)            gpu.bitblt() goto continue end
                if key=="right"           then moveCur( 1)            gpu.bitblt() goto continue end
                if key=="down"            then moveCur( bytesPerRow)  gpu.bitblt() goto continue end
                if key=="up"              then moveCur(-bytesPerRow)  gpu.bitblt() goto continue end
                if inputMode==0 then
                    if #key==1 and string.find("0123456789abcdef",key) then typeHex(key) gpu.bitblt() end
                    if #key==7 and key:sub(1,6)=="numpad" and string.find("0123456789",key:sub(7)) then typeHex(key:sub(7)) gpu.bitblt() end
                elseif inputMode==1 then
                    if code and code~=0 then typeByte(code) gpu.bitblt() end
                end
            end
        end
    else
        cursorBlink = not cursorBlink
        renderByte(cursor,cursorBlink)
        gpu.bitblt()
    end
    ::continue::
end

gpu.setActiveBuffer(0)
gpu.freeBuffer(rbuf)

gpu.setBackground(0)
gpu.fill(1,1,160,50," ")
termlib.cursorPosX=1
termlib.cursorPosY=1
