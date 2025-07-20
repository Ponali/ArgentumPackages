local ctif = import("ctif")

local component = import("component")
local unicode = import("unicode")
local event = import("event")
local fs = import("filesystem")
local gpu = component.gpu

local args = {...}

local viewY = 2
local fullscreen = false

local loremIpsumArgIdx = table.find(args,"-o") or table.find(args,"--oc-char-ratio")
if loremIpsumArgIdx then
  table.remove(args,loremIpsumArgIdx)
  ctif.CCWide = false
end

local fullscreenArgIdx = table.find(args,"-f") or table.find(args,"--fullscreen")
if fullscreenArgIdx then
  table.remove(args,fullscreenArgIdx)
  viewY = 1
  fullscreen = true
end

local file = args[1]
if not file then return shell.run("help ctif") end

if file:sub(1, 1) ~= "/" then
  file = fs.concat(shell.workingDirectory, file)
end
if not fs.exists(file) or fs.isDirectory(file) then
  print("\27[91mFile does not exist.")
end

local function truncate(txt,len)
  if unicode.wlen(txt)>len then
    return unicode.sub(txt,1,len-2).."…"
  end
  return txt
end


local screenWidth,screenHeight = gpu.getResolution()
local rbuf = gpu.allocateBuffer() or 0

gpu.setActiveBuffer(rbuf)


local img

local function renderInfo()
  gpu.setForeground(0)
  gpu.setBackground(0xFFFFFF)
  gpu.fill(1,1,screenWidth,1," ")
  local info = file.." - "
  info=info..(({"OC","CC"})[img.ctif.platformId] or "Unknown")
  info=info.." "..img.width.."x"..img.height
  if img.width~=img.renderWidth or img.height~=img.renderHeight then
    info=info.." (shown in "..img.renderWidth.."x"..img.renderHeight..")"
  end
  info=info.." "..img.bitDepth.."bpp"
  if #img.data.palette>0 then
    info=info.." Paletted ("..#img.data.palette.." colors)"
  end
  local controls = " ┃ [Q] Quit [←→↑↓] Move"
  gpu.set(1,1,truncate(info,screenWidth-unicode.len(controls)))
  gpu.setForeground(0x777777)
  gpu.set(screenWidth-unicode.len(controls),1,controls)
end

_, img = ctif.load(file)
local startX,startY = 1,1
if fullscreen then
  if rbuf~=0 then
    gpu.setActiveBuffer(0)
    gpu.setResolution(img.renderWidth,img.renderHeight)
    gpu.setActiveBuffer(rbuf)
  end
  gpu.setResolution(img.renderWidth,img.renderHeight)
else
  startX,startY = (screenWidth-img.renderWidth)//2,(screenHeight-img.renderHeight-1)//2+1
end
local x,y = startX,startY
if rbuf~=0 then
  gpu.setActiveBuffer(0)
  img:setPalette()
  gpu.setActiveBuffer(rbuf)
end
img:setPalette()
gpu.setBackground(0,false)
gpu.fill(1,1,screenWidth,screenHeight," ")
img:show(x,y,nil,nil,true)
if not fullscreen then renderInfo() end

gpu.bitblt()

local function updateScreen()
  if rbuf==0 then return end
  if fullscreen then
    gpu.bitblt()
  else
    gpu.bitblt(0,1,2,screenWidth,screenHeight-1,rbuf,1,2)
  end
end

local function moveHorizontal(diff)
  gpu.copy(1,viewY,screenWidth,screenHeight-viewY+1,diff,0)
  x=x-diff
  gpu.setBackground(0)
  local renderY = screenHeight-img.renderHeight-y
  if img.renderHeight>screenHeight then renderY=renderY+1 end -- why
  if diff>0 then
    gpu.fill(1,renderY,diff,img.renderHeight," ")
    local dx = x-startX*2+1
    img:show(0,renderY,diff+dx,img.renderHeight,true,dx)
  else
    gpu.fill(screenWidth+diff,renderY,1-diff,img.renderHeight," ")
    local dx = x+screenWidth+diff-startX*2+1
    img:show(screenWidth+diff,renderY,-diff+dx,img.renderHeight,true,dx)
  end
  updateScreen()
end

local function moveVertical(diff)
  if diff>0 then
    gpu.copy(1,viewY,screenWidth,screenHeight-(viewY-1)-diff,0,diff)
  else
    gpu.copy(1,viewY-diff,screenWidth,screenHeight-(viewY-1)+diff,0,diff)
  end
  y=y-diff
  gpu.setBackground(0)
  if diff>0 then
    gpu.fill(screenWidth-img.renderWidth-x,viewY,img.renderWidth,diff," ")
    local dy = y-startY*2+1+viewY
    img:show(screenWidth-img.renderWidth-x,viewY,img.renderWidth,diff+dy,true,nil,dy)
  else
    gpu.fill(screenWidth-img.renderWidth-x,screenHeight+diff,img.renderWidth,1-diff," ")
    local dy = y+screenHeight+diff-startY*2+1
    img:show(screenWidth-img.renderWidth-x,screenHeight+diff,img.renderWidth,-diff+dy,true,nil,dy)
  end
  updateScreen()
end

while true do
  local args = {event.pull("key_down",0.5)}
  local key = keyboard.keys[args[4]]
  if key=="left" then
    moveHorizontal(-8)
  elseif key=="right" then
    moveHorizontal(8)
  elseif key=="up" then
    moveVertical(-4)
  elseif key=="down" then
    moveVertical(4)
  elseif key=="q" then
    break
  elseif key=="enter" and fullscreen then
    break
  end
end

if rbuf~=0 then
  gpu.setActiveBuffer(0)
  gpu.freeBuffer(rbuf)
end
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0)
gpu.fill(1,1,screenWidth,screenHeight," ")
gpu.setDepth(1)
gpu.fill(1,1,screenWidth,screenHeight," ")
gpu.setDepth(gpu.maxDepth())
termlib.cursorPosX,termlib.cursorPosY=1,1

if fullscreen then
  gpu.setResolution(screenWidth,screenHeight)
end
