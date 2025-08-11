local name, version = "hextra", "v1.7.2"


local component,computer,event,fs,json,unicode=import("component"),import("computer"),import("event"),import("filesystem"),import("json"),import("unicode")
local gpu = component.gpu
local width,height = gpu.getResolution()

local yieldTime=computer.uptime()
local function yieldIfRequired()
    if computer.uptime()>yieldTime+4 then
        coroutine.yield()
    end
end

local function default(arr,idx,val)
    if arr[idx]==nil then arr[idx] = val end
end

-- config
if not fs.exists("/halyde/config/hextra.json") then
  fs.copy("/halyde/config/generate/hextra.json", "/halyde/config/hextra.json")
end
local handle, data, tmpdata = fs.open("/halyde/config/hextra.json", "r"), "", nil
repeat
  tmpdata = handle:read(math.huge or math.maxinteger)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()
local config = json.decode(data)
default(config,"memory",{})
default(config,"design",{})
default(config,"colors",{})
default(config,"defaultCommand",{})
for i,v in pairs(config.colors) do
    config.colors[i] = tonumber(config.colors[i])
end

default(config.design,"bytesUppercase",    false)
default(config.design,"codePointUppercase",true)
default(config.design,"rowIndexUppercase", false)

default(config.colors,"mainBackground"          ,0x000000)
default(config.colors,"mainForeground"          ,0xFFFFFF)
default(config.colors,"keyBackground"           ,0xFFFFFF)
default(config.colors,"keyForeground"           ,0x000000)
default(config.colors,"cursorBackground"        ,0xFFFFFF)
default(config.colors,"cursorForeground"        ,0x000000)
default(config.colors,"rowIndex"                ,0x999999)
default(config.colors,"emptyByte"               ,0x707070)
default(config.colors,"nonPrintableByte"        ,0x0080FF)
default(config.colors,"typingByte"              ,0xFF8000)
default(config.colors,"decodingTableBorder"     ,0x80FF80)
default(config.colors,"decodingTableEntryTitle" ,0xEEEEEE)
default(config.colors,"decodingTableOutput"     ,0xFFFFFF)
default(config.colors,"decodingTableEmptyOutput",0x808080)
default(config.colors,"decodingTableError"      ,0xFF8888)
default(config.colors,"toggleableEntry"         ,0x60FF60)
default(config.colors,"fileDescription"         ,0x808080)
default(config.colors,"version"                 ,0x606060)


local content = {}
local chunkLength = config.chunkLength or 256

local bytesPerRow = config.design.bytesPerRow or 16
local rowIdxLength = config.design.rowIdxLength or 8
local bytePadding = config.design.bytePadding or 1
if width<115 then bytePadding=0 end
-- local rowLength = rowIdxLength+1+bytesPerRow*(2+bytePadding)-bytePadding+1+bytesPerRow
local rowLength = rowIdxLength+2+bytesPerRow*(3+bytePadding)-bytePadding
local rowByteLength = rowIdxLength+1+bytesPerRow*(2+bytePadding)-bytePadding
if width<80 then rowLength = rowByteLength end

local cursor = 0
local scroll = 0


local function invalidArgSyntax(err)
    print(err)
    return shell.run("help "..name)
end

local cmdargs = {...}
if #cmdargs==0 then
    cmdargs = config.defaultCommand
end
local limit, newFile, fpath
local bufferFile = true
if table.find(cmdargs,"-l") then
    local idx = table.find(cmdargs,"-l")
    table.remove(cmdargs,idx)
    local arg = table.remove(cmdargs,idx)
    if not arg then return invalidArgSyntax("Argument -l must have a value.") end
    limit = tonumber(arg)
    if not limit then return invalidArgSyntax("Cannot convert value of argument -l to number") end
end
if table.find(cmdargs,"-d") then
    table.remove(cmdargs,table.find(cmdargs,"-d"))
    bufferFile=false
end
if table.find(cmdargs,"-n") then
    local idx = table.find(cmdargs,"-n")
    table.remove(cmdargs,idx)
    local nf = table.remove(cmdargs,idx)
    if not nf then return invalidArgSyntax("Argument -n must have a value.") end
    if string.find(nf,":") then
        local colon = string.find(nf,":")
        local flen,fill=tonumber(nf:sub(1,colon-1)),tonumber(nf:sub(colon+1),16)
        if flen==nil then return invalidArgSyntax("Argument -n: Cannot convert file length to number") end
        if fill==nil then return invalidArgSyntax("Argument -n: Cannot convert fill byte to number") end
        newFile = {flen,fill}
    else
        local flen = tonumber(nf)
        if flen==nil then return invalidArgSyntax("Argument -n: Cannot convert value to number") end
        newFile = {flen,0}
    end
    if limit~=nil then
        newFile[1] = math.min(newFile[1],limit)
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
    if not fs.exists(fpath) then return print("File doesn't exist ("..fpath..")") end
    if fs.isDirectory(fpath) then return print("Cannot open directory ("..fpath..")") end
    local file = fs.open(fpath,"rb",bufferFile)
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

local function toHex(num,uppercase,pad)
    local cmd = "%"
    if pad~=nil then cmd=cmd.."0"..tostring(pad) end
    if uppercase then cmd=cmd.."X" else cmd=cmd.."x" end
    return string.format(cmd,num)
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

local littleEndian = false
local function bytesToInt(bytes,le)
    if le==nil then le=littleEndian end
    local res = 0

    if le then
        for i=#bytes,1,-1 do
            res = (res<<8)&0xFFFFFFFF | bytes[i]
        end
    else
        for i=1,#bytes do
        res = (res<<8)&0xFFFFFFFF | bytes[i]
        end
    end

    return res
end

local function readInt(readByte,n,le)
    n = n or 1
    if n==1 then return readByte(1) end
    -- local bytes, res = {string.byte(self:read(n),1,n)}, 0
    local bytes = {}
    for i=1,n do
        table.insert(bytes,readByte())
    end
    return bytesToInt(bytes,le)
end

local function writeInt(num,bytes)
    if bytes==1 then return {num&255} end
    local out = {}
    if littleEndian then
        for i=1,bytes do out[i]=(num>>((i-1)*8))&255 end
    else
        for i=1,bytes do out[i]=(num>>((bytes-i)*8))&255 end
    end
    return out
end

local function largeNum(x)
    if math.abs(x)>math.maxinteger then return string.format("%e",x) end
    if math.abs(x)>=1e+12 then return string.format("%d",x) end
    return string.format("%f",x)
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
        end,
        ["write"]=function(input) return {math.max(math.min(tonumber(input,2),255),0)} end
    },
    {
        ["title"]="Octal",
        ["shortTitle"]="oct",
        ["maxLength"]=3,
        ["bytes"]=1,
        ["decode"]=function(readByte) return string.format("%o",readByte()) end,
        ["write"]=function(input) return {math.max(math.min(tonumber(input,8),255),0)} end
    },
    {
        ["title"]="Signed 8-bit",
        ["shortTitle"]="int8",
        ["maxLength"]=#("-128"),
        ["maxInputLength"]=#("-0x80"),
        ["bytes"]=1,
        ["decode"]=function(readByte)
            local b = readInt(readByte,1)
            if b&0x80>0 then b=b-0x100 end
            return string.format("%d",b)
        end,
        ["write"]=function(input)
            local n = math.min(math.max(tonumber(input),-0x80),0x7F)
            if n<0 then n=n+0x100 end
            return writeInt(n,1)
        end
    },
    {
        ["title"]="Unigned 8-bit",
        ["shortTitle"]="uint8",
        ["maxLength"]=#("255"),
        ["maxInputLength"]=#("0xFF"),
        ["bytes"]=1,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,1)) end,
        ["write"]=function(input) return writeInt(math.max(math.min(tonumber(input),0xFF),0),1) end
    },
    {
        ["title"]="Signed 16-bit",
        ["shortTitle"]="int16",
        ["maxLength"]=#("-32768"),
        ["maxInputLength"]=#("-0x8000"),
        ["bytes"]=2,
        ["decode"]=function(readByte)
            local b = readInt(readByte,2)
            if b&0x8000>0 then b=b-0x10000 end
            return string.format("%d",b)
        end,
        ["write"]=function(input)
            local n = math.min(math.max(tonumber(input),-0x8000),0x7FFF)
            if n<0 then n=n+0x10000 end
            return writeInt(n,2)
        end
    },
    {
        ["title"]="Unigned 16-bit",
        ["shortTitle"]="uint16",
        ["maxLength"]=#("65535"),
        ["maxInputLength"]=#("0xFFFF"),
        ["bytes"]=2,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,2)) end,
        ["write"]=function(input) return writeInt(math.max(math.min(tonumber(input),0xFFFF),0),2) end
    },
    {
        ["title"]="Signed 32-bit",
        ["shortTitle"]="int32",
        ["maxLength"]=#("-2147483648"),
        ["maxInputLength"]=#("-0x80000000"),
        ["bytes"]=4,
        ["decode"]=function(readByte)
            local b = readInt(readByte,4)
            if b&0x80000000>0 then b=b-0x100000000 end
            return string.format("%d",b)
        end,
        ["write"]=function(input)
            local n = math.min(math.max(tonumber(input),-0x80000000),0x7FFFFFFF)
            if n<0 then n=n+0x100000000 end
            return writeInt(n,4)
        end
    },
    {
        ["title"]="Unigned 32-bit",
        ["shortTitle"]="uint32",
        ["maxLength"]=#("4294967295"),
        ["maxInputLength"]=#("0xFFFFFFFF"),
        ["bytes"]=4,
        ["decode"]=function(readByte) return string.format("%d",readInt(readByte,4)) end,
        ["write"]=function(input) return writeInt(math.max(math.min(tonumber(input),0xFFFFFFFF),0),4) end
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
            local mant = bytesToInt({bytes[2]&0x7F,bytes[3],bytes[4]},false)
            local absv = (1+mant/8388608)*math.pow(2,exp-127)
            local sign = 1
            if bytes[1]&0x80>0 then sign=-1 end
            return largeNum(sign*absv)
        end,
        ["write"]=function(input)
            local num = tonumber(input)
            if num==0 then return {0,0,0,0} end
            if num~=num then return {127,255,255,255} end
            if num==math.huge then return {127,128,0,0} end
            if num==-math.huge then return {255,128,0,0} end

            local sign = 0
            if num<0 then sign=1 end
            num=math.abs(num)

            local exp = 0
            if num>=1 then
                while num>=2 do
                    num = num / 2
                    exp = exp + 1
                end
            else
                while num < 1 do
                    num = num * 2
                    exp = exp - 1
                end
            end
            exp=exp+127
            -- Handle denormalized numbers (exponent would be < 0)
            if exp <= 0 then
                -- Denormalized number
                num = num * math.pow(2, exp - 1)
                exp = 0
            else
                -- Remove implicit leading 1
                num = num - 1
            end

            local mantissa = math.floor(num * 8388608 + 0.5)
            exp=math.max(0,math.min(255,exp))
            mantissa=math.max(0,math.min(8388607,mantissa))

            return {
                (sign<<7)|(exp>>1),
                ((exp&1)<<7)|(mantissa>>16),
                (mantissa>>8)&255,
                mantissa&255
            }
        end
    },
    {
        ["title"]="UTF-8 Character",
        ["shortTitle"]="UTF-8",
        ["maxLength"]=1,
        ["bytes"]=1,
        ["decode"]=function(readByte) return unicode.readChar(readByte) end,
        ["write"]=function(input) return {string.byte(unicode.sub(input,1,1),1,4)} end
    },
    {
        ["title"]="Unicode code point",
        ["shortTitle"]="Index",
        ["maxLength"]=#("U+10FFFF"),
        ["bytes"]=1,
        ["decode"]=function(readByte) return "U+"..toHex(unicode.readCodePoint(readByte),config.design.codePointUppercase,4) end,
        ["write"]=function(input)
            if input:sub(1,2)=="U+" then input=input:sub(3) end
            return {string.byte(unicode.char(tonumber(input,16)),1,4)}
        end
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

for _,v in ipairs(decodingTable) do
    if v.maxInputLength==nil then
        v.maxInputLength=v.maxLength
    end
end

local rbuf = assert(gpu.allocateBuffer(),"No render buffer available.")
gpu.setActiveBuffer(rbuf)
gpu.setBackground(config.colors.mainBackground)
gpu.setForeground(config.colors.mainForeground)
gpu.fill(1,1,160,50," ")

local function prompt(txt,default)
    local bg = gpu.getBackground()
    gpu.setActiveBuffer(0)
    gpu.setBackground(0xFFFFFF)
    termlib.cursorPosX = 1
    termlib.cursorPosY = 1
    local out = read(nil,"\x1b[107m\x1b[30m"..txt,default)
    gpu.setBackground(bg)
    gpu.setActiveBuffer(rbuf)
    gpu.bitblt(0,1,1,width,1,rbuf,1,1)
    return out
end

local function getByte(idx)
    return content[math.floor(idx/chunkLength)+1]:byte(idx%chunkLength+1,idx%chunkLength+1)
end

local changedBytes = 0
local changedBytesY = height-3
if width<115 then
    changedBytesY = height-1
else
    gpu.setForeground(config.colors.fileDescription)
    local txt = (fpath or "New file").." ("..fileLength.." bytes)"
    gpu.set(width-unicode.wlen(txt)+1,height-2,txt)
    gpu.setForeground(config.colors.mainForeground)
end

local function setByte(idx,val)
    val = val or 0 -- in case some shit happened
    local chunk = math.floor(idx/chunkLength)+1
    local chunkidx = idx%chunkLength+1
    local str = content[chunk]
    content[chunk]=str:sub(1,chunkidx-1)..string.char(val&255)..str:sub(chunkidx+1)
    changedBytes=changedBytes+1

    if width<80 then return end

    local txt = changedBytes.." bytes changed"
    if changedBytes==1 then txt="1 byte changed" end
    gpu.setForeground(config.colors.fileDescription)
    gpu.set(width-unicode.wlen(txt)+1,changedBytesY,txt)
    gpu.setForeground(config.colors.mainForeground)
end

local function isReadOnly(fpath)
    local address = fs.absolutePath(fpath)
    return component.invoke(address,"isReadOnly")
end

local function save(saveAs)
    if saveAs or fpath==nil or isReadOnly(fpath) then
        local npath = nil
        while npath==nil or isReadOnly(npath) do
            npath = prompt("Save location: ",fpath)
            if npath and npath~="" then fpath=npath end
            if npath==" " then return end
        end
    end
    if not fpath or fpath=="" then return end
    local file = fs.open(fpath,"wb")
    for i=1,#content do
        file:write(content[i])
    end
    file:close()

    gpu.setBackground(config.colors.mainBackground)
    gpu.fill(rowLength+1,changedBytesY,width,1," ")
    gpu.bitblt()

    changedBytes = 0
end

local hextype=""

local function renderByte(idx,cursorHighlight)
    local x = idx%bytesPerRow
    local screenX = 10+x*(2+bytePadding)
    local textX = 10+bytesPerRow*(2+bytePadding)-bytePadding+1
    local y = math.floor(idx/bytesPerRow)+1-scroll
    if idx>=fileLength then
        gpu.setForeground(config.colors.emptyByte)
        gpu.set(screenX,y,"--")
        gpu.setForeground(config.colors.mainForeground)
        return
    end
    local byte = getByte(idx)
    local specialByte = byte<32 or (byte>=0x7F and byte<=0x9F)
    local onCursor = idx==cursor and cursorHighlight

    if onCursor then
        gpu.setForeground(config.colors.cursorForeground)
        gpu.setBackground(config.colors.cursorBackground)
    else
        if specialByte then gpu.setForeground(config.colors.nonPrintableByte) end
    end

    local bhex = toHex(byte,config.design.bytesUppercase,2)
    if #hextype==0 then
        gpu.set(screenX,y,bhex)
    else
        if not onCursor then gpu.setForeground(config.colors.typingByte) end
        gpu.set(screenX,y,hextype..bhex:sub(2))
        if not onCursor then gpu.setForeground(config.colors.mainForeground) end
    end

    if width>=80 then
        if specialByte then
            gpu.set(textX+x,y,".")
            if not onCursor then gpu.setForeground(config.colors.mainForeground) end
        else
            local ch
            if byte>127 then ch=string.char(0xC0|(byte>>6),0x80|(byte&0x3F)) else ch=string.char(byte) end
            gpu.set(textX+x,y,ch)
        end
    end
    if onCursor then
        gpu.setForeground(config.colors.mainForeground)
        gpu.setBackground(config.colors.mainBackground)
    end
end

local function renderRow(y)
    gpu.setForeground(config.colors.rowIndex)
    gpu.set(1,y,toHex((y-1+scroll)*bytesPerRow,config.design.rowIndexUppercase,rowIdxLength):sub(-rowIdxLength))
    gpu.setForeground(config.colors.mainForeground)
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
    gpu.setForeground(config.colors.decodingTableBorder)
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

    gpu.setForeground(config.colors.decodingTableEntryTitle)
    for i,v in ipairs(decodingTable) do
        gpu.set(width-1-decodingOutputLength-#v.title,i+1,v.title)
    end

    gpu.setForeground(config.colors.mainForeground)
end

local function getDecodingValue(idx,default)
    if cursor+decodingTable[idx].bytes>fileLength then return default end
    local readcur=cursor
    local function readByte()
        local out = getByte(readcur)
        readcur=readcur+1
        return out
    end
    local out
    local success = pcall(function()
        out = decodingTable[idx].decode(readByte)
    end)
    if not success then return default end
    if out==nil then return default end
    return out
end

local function updateDecodingTable()
    if width<80 then return end
    local readcur
    local function readByte()
        local out = getByte(readcur)
        readcur=readcur+1
        return out
    end

    gpu.setBackground(config.colors.mainBackground)
    local x = width-decodingOutputLength
    gpu.fill(x,2,decodingOutputLength,#decodingTable," ")

    for i=1,#decodingTable do
        if cursor+decodingTable[i].bytes>fileLength then
            gpu.setForeground(config.colors.decodingTableEmptyOutput)
            gpu.set(x,i+1,noBytesText)
            goto continue
        end
        gpu.setForeground(config.colors.decodingTableOutput)
        readcur=cursor
        local out
        local success = pcall(function()
            out = decodingTable[i].decode(readByte)
        end)
        if success then
            if out==nil then
                gpu.setForeground(config.colors.decodingTableEmptyOutput)
                gpu.set(x,i+1,"nil")
            elseif out=="" then
                gpu.setForeground(config.colors.decodingTableEmptyOutput)
                gpu.set(x,i+1,"Empty")
            else
                gpu.set(x,i+1,out)
            end
        else
            gpu.setForeground(config.colors.decodingTableError)
            gpu.set(x,i+1,"Error")
        end
        ::continue::
    end
    gpu.setForeground(config.colors.mainForeground)
end

local endiannessX = 1
local endiannessY = #decodingTable+3

local inputModeX = 1
local inputModeY = #decodingTable+6
local inputMode = 0

local function initControlsText()
    -- input mode
    if width<80 then
        inputModeX = rowByteLength+5
        inputModeY = height
        gpu.set(rowByteLength+5,inputModeY,"Bytes")
        gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
        gpu.set(rowByteLength+2,inputModeY,"^I")
        gpu.setForeground(config.colors.mainForeground) gpu.setBackground(config.colors.mainBackground)
    elseif width<115 then
        inputModeX = width-#("Bytes")
        gpu.set(width-#("nput mode: Bytes"),inputModeY,"nput mode:")
        gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
        gpu.set(width-#("^Input mode: Bytes"),inputModeY,"^I")
        gpu.setForeground(config.colors.toggleableEntry) gpu.setBackground(config.colors.mainBackground)
        gpu.set(width-#("Bytes"),inputModeY,"Bytes")
        gpu.setForeground(config.colors.mainForeground)
    else
        inputModeX = width-#("Bytes)")
        gpu.set(width-#(" - Toggle input mode (Bytes)"),inputModeY," - Toggle input mode (Bytes)")
        gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
        gpu.set(width-#("^I - Toggle input mode (Bytes)"),inputModeY,"^I")
        gpu.setForeground(config.colors.toggleableEntry) gpu.setBackground(config.colors.mainBackground)
        gpu.set(width-#("Bytes)"),inputModeY,"Bytes")
        gpu.setForeground(config.colors.mainForeground)
    end

    -- endianness
    if width>=80 then
        if width<115 then
            endiannessX = width-#("Big")
            gpu.set(width-#("ndianness: Big"),endiannessY,"ndianness: Big")
            gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
            gpu.set(width-#("^Endianness: Big"),endiannessY,"^E")
            gpu.setForeground(config.colors.toggleableEntry) gpu.setBackground(config.colors.mainBackground)
            gpu.set(width-#("Big"),endiannessY,"Big")
            gpu.setForeground(config.colors.mainForeground)
        else
            endiannessX = width-#("Big)")
            gpu.set(width-#(" - Toggle endianness (Big)"),endiannessY," - Toggle endianness (Big)")
            gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
            gpu.set(width-#("^E - Toggle endianness (Big)"),endiannessY,"^E")
            gpu.setForeground(config.colors.toggleableEntry) gpu.setBackground(config.colors.mainBackground)
            gpu.set(width-#("Big)"),endiannessY,"Big")
            gpu.setForeground(config.colors.mainForeground)
        end
    end

    -- other
    if width<80 then
        gpu.set(rowByteLength+5,height-1,"Save")
        gpu.set(rowByteLength+5,height-2,"Exit")
        gpu.set(rowByteLength+5,height-3,"Jump")
        gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
        gpu.set(rowByteLength+2,height-1,"^S")
        gpu.set(rowByteLength+2,height-2,"^X")
        gpu.set(rowByteLength+2,height-3,"^J")
        gpu.setForeground(config.colors.mainForeground) gpu.setBackground(config.colors.mainBackground)
    else
        gpu.set(width-#("Write value")       ,#decodingTable+4 ,"Write value")
        gpu.set(width-#("Jump to address")   ,#decodingTable+7 ,"Jump to address")
        gpu.set(width-#("Save as")           ,#decodingTable+9 ,"Save as")
        gpu.set(width-#("Save")              ,#decodingTable+10,"Save")
        gpu.set(width-#("Exit")              ,#decodingTable+11,"Exit")
        gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
        gpu.set(width-#("^W Write value")    ,#decodingTable+4 ,"^W")
        gpu.set(width-#("^J Jump to address"),#decodingTable+7 ,"^J")
        gpu.set(width-#("Shift+^S Save as")  ,#decodingTable+9 ,"Shift+^S")
        gpu.set(width-#("^S Save")           ,#decodingTable+10,"^S")
        gpu.set(width-#("^X Exit")           ,#decodingTable+11,"^X")
        gpu.setForeground(config.colors.mainForeground) gpu.setBackground(config.colors.mainBackground)
    end
end

local function initSideContent()
    renderDecodingBorder()
    updateDecodingTable()

    initControlsText()

    gpu.setForeground(config.colors.version)
    local str = name.." "..version
    local y = height
    if width<80 then str=version y=1 end
    gpu.set(width-#str+1,y,str)
    gpu.setForeground(config.colors.mainForeground)
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
local function moveTo(to)
    if #hextype>0 then hextype="" end
    cursorBlink=true
    local curnew = math.max(math.min(to,fileLength-1),0)
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

local function moveCur(dist)
    moveTo(cursor+dist)
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
    if not byte or byte==0 or byte~=byte&255 then return end
    cursorBlink=true
    setByte(cursor,byte)
    moveCur(1)
    gpu.bitblt()
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
    gpu.setForeground(config.colors.toggleableEntry)
    gpu.set(inputModeX,inputModeY,({"Bytes","Text "})[inputMode+1])
    gpu.setForeground(config.colors.mainForeground)
    gpu.bitblt()
end

local function toggleEndianness()
    if width<80 then return end

    littleEndian=not littleEndian
    gpu.setForeground(config.colors.toggleableEntry)
    if littleEndian then
        gpu.set(endiannessX,endiannessY,"Low")
    else
        gpu.set(endiannessX,endiannessY,"Big")
    end
    gpu.setForeground(config.colors.mainForeground)
    updateDecodingTable()
    gpu.bitblt()
end

local dcur = 1

local function renderDecodingItem(idx,cur)
    if cur then
        gpu.setForeground(config.colors.cursorForeground)
        gpu.setBackground(config.colors.cursorBackground)
    else
        gpu.setForeground(config.colors.decodingTableEntryTitle)
        gpu.setBackground(config.colors.mainBackground)
    end
    local v = decodingTable[idx]
    gpu.set(width-1-decodingOutputLength-decodingTitleLength,idx+1,string.rep(" ",decodingTitleLength-#v.title)..v.title)
end

local function writePrompt()
    gpu.bitblt()
    gpu.setActiveBuffer(0)

    termlib.cursorPosX = width-decodingOutputLength
    termlib.cursorPosY = 1+dcur
    local ogv = getDecodingValue(dcur,"")
    gpu.setForeground(config.colors.cursorForeground)
    gpu.setBackground(config.colors.cursorBackground)
    gpu.set(width-decodingOutputLength,1+dcur,ogv..string.rep(" ",decodingOutputLength-unicode.len(ogv)))
    local input = read(nil,nil,ogv,decodingTable[dcur].maxInputLength)
    gpu.setActiveBuffer(rbuf)
    renderDecodingItem(dcur,false)

    if input==ogv then return gpu.bitblt() end

    local out
    local success = pcall(function()
        out = decodingTable[dcur].write(input)
    end)
    if out==nil then return gpu.bitblt() end
    if type(out)~="table" then return gpu.bitblt() end
    if not success then return gpu.bitblt() end

    for i=1,#out do
        local byteIdx = cursor+i-1
        setByte(byteIdx,(out[i] or 0)&255)
        renderByte(byteIdx,true)
    end

    updateDecodingTable()
    gpu.bitblt()
end

local function writeDecodingFormat()
    if width<80 then return end

    gpu.setActiveBuffer(0)
    gpu.setForeground(config.colors.mainForeground) gpu.setBackground(config.colors.mainBackground)
    gpu.fill(width-2-decodingOutputLength-decodingTitleLength,#decodingTable+2,2+decodingOutputLength+decodingTitleLength,10," ")
    gpu.setForeground(config.colors.keyForeground) gpu.setBackground(config.colors.keyBackground)
    gpu.set(width-10,#decodingTable+3,"←/⌫")
    gpu.set(width-10,#decodingTable+4,"↑/↓")
    gpu.set(width-10,#decodingTable+5,"→/⏎")
    gpu.setForeground(config.colors.mainForeground) gpu.setBackground(config.colors.mainBackground)
    gpu.set(width-6,#decodingTable+3,"Cancel")
    gpu.set(width-6,#decodingTable+4,"Choose")
    gpu.set(width-5,#decodingTable+5,"Enter")
    gpu.setActiveBuffer(rbuf)

    renderDecodingItem(dcur,true)
    local function bitblt()
        local x = width-2-decodingOutputLength-decodingTitleLength
        gpu.bitblt(0,x,1,2+decodingOutputLength+decodingTitleLength,#decodingTable+2,rbuf,x,1)
    end
    bitblt()

    while true do
        local args = {event.pull("key_down",0.5)}
        if args and args[1] then
            local key = keyboard.keys[args[4]]
            if key=="up" then
                renderDecodingItem(dcur,false)
                dcur=math.max(dcur-1,1)
                renderDecodingItem(dcur,true)
                bitblt()
            end
            if key=="down" then
                renderDecodingItem(dcur,false)
                dcur=math.min(dcur+1,#decodingTable)
                renderDecodingItem(dcur,true)
                bitblt()
            end
            if key=="left" or key=="back" then
                renderDecodingItem(dcur,false)
                return gpu.bitblt()
            end
            if key=="right" or key=="enter" then break end
        end
    end
    writePrompt()
end

local function cursorTouch(x,y)
    if x>rowIdxLength+1 and x<=rowLength then
        local curX
        if x<=rowByteLength then
            curX = (x-rowIdxLength-2)//(2+bytePadding)
        elseif x>rowByteLength+1 and width>=80 then
            curX = x-rowByteLength-2
        else
            return
        end
        local curByte = curX+(y-1+scroll)*bytesPerRow
        moveTo(curByte)
        gpu.bitblt()
    end
    if width>=80 and x>width-2-decodingOutputLength-decodingTitleLength and x<width and y>1 and y<=#decodingTable+1 then
        dcur = y-1
        renderDecodingItem(dcur,true)
        writePrompt()
    end
end

local function scrollEvent(x,y,dir)
    dir=-dir
    if scroll+dir<0 or scroll+dir>=fileLength//bytesPerRow-height+1 then return end
    applyScroll(dir)
    if cursor+(dir-scroll)*bytesPerRow<bytesPerRow then moveCur(bytesPerRow) end
    if cursor+(dir-scroll)*bytesPerRow>=(height-1)*bytesPerRow then moveCur(-bytesPerRow) end
    gpu.bitblt()
end

while true do
    local args = {event.pull(0.5)}
    if args and args[1] then
        if args[1]=="key_down" then
            cursorBlink = true
            local key = keyboard.keys[args[4]]
            local code = args[3]
            if key==nil then
                if code and code~=0 then typeByte(code) end
                goto continue
            end
            if code==13 then code=10 end
            if keyboard.ctrlDown then
                if key=="x" then
                    local input = unicode.lower(prompt("Would you like to save changes? [Y/n] "))
                    if changedBytes>0 and input~="n" and input~="н" then
                        save(false)
                    end
                    break
                end
                if key=="s" then save(keyboard.shiftDown) end
                if key=="j" then jump() end
                if key=="i" then toggleInputMode() end
                if key=="e" then toggleEndianness() end
                if key=="w" then writeDecodingFormat() end
            else
                if key=="left" or code==8 then moveCur(-1)            gpu.bitblt() goto continue end
                if key=="right"           then moveCur( 1)            gpu.bitblt() goto continue end
                if key=="down"            then moveCur( bytesPerRow)  gpu.bitblt() goto continue end
                if key=="up"              then moveCur(-bytesPerRow)  gpu.bitblt() goto continue end
                if inputMode==0 then
                    if #key==1 and string.find("0123456789abcdef",key) then typeHex(key) gpu.bitblt() end
                    if #key==7 and key:sub(1,6)=="numpad" and string.find("0123456789",key:sub(7)) then typeHex(key:sub(7)) gpu.bitblt() end
                elseif inputMode==1 then
                    if code and code~=0 then typeByte(code) end
                end
            end
        end
        if args[1]=="touch" or args[1]=="drag" then cursorTouch(args[3],args[4]) end
        if args[1]=="scroll" then scrollEvent(args[3],args[4],args[5]) end
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
gpu.fill(1,1,width,height," ")
termlib.cursorPosX=1
termlib.cursorPosY=1
