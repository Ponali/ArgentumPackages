local component = import("component")
local computer = import("computer")
local json = import("json")
local fs = import("filesystem")
local event = import("event")

if not fs.exists("/halyde/config/utape.json") then
  fs.copy("/halyde/config/generate/utape.json", "/halyde/config/utape.json")
end
local handle, data, tmpdata = fs.open("/halyde/config/utape.json", "r"), "", nil
repeat
  tmpdata = handle:read(math.huge or math.maxinteger)
  data = data .. (tmpdata or "")
until not tmpdata
handle:close()
local function default(arr,idx,val)
    if arr[idx]==nil then arr[idx] = val end
end
local config = json.decode(data)
default(config,"disabled",false)
default(config,"sectorSize",512)
default(config,"readBuffer",true)
default(config,"writeBuffer",true)
default(config,"writeUpdate",2)
local drives = config.drives
local readBuffer = config.readBuffer
local writeBuffer = config.writeBuffer
local writeUpdate = config.writeUpdate
if writeBuffer then readBuffer=true end

local function containsDrive(id)
  if drives==nil or #drives==0 then return true end
  for _,v in ipairs(drives) do
    if #v>=3 and component.get(v)==id then return true end
  end
  return false
end

local driver = {}
driver.type = "drive"
driver.dependencies = {"tape_drive"}
driver.onStartup = function()
  local function handleProxy(tape)
    local cur = 1
    tape.seek(-math.huge)
    local sectorSize = config.sectorSize
    local function seek(pos)
      local dist = pos-cur
      if dist~=0 then tape.seek(dist) end
      cur=pos
    end
    local function read(n)
      local out = tape.read(n)
      cur=cur+(n or 1)
      return out
    end
    local function write(value)
      tape.write(value)
      if type(value)=="string" then
        cur=cur+#value
      else
        cur=cur+1
      end
    end
    local writeChanges, writeChangeTime = false, 0
    local bufferSect,bufferData
    -- bufferSect starts counting at 0, not 1
    local function updateBuffer(pos)
      local sect = math.floor((pos-1)/sectorSize)
      if bufferSect==nil or bufferSect~=sect then
        if writeBuffer and writeChanges then
          seek(bufferSect*sectorSize+1)
          write(bufferData)
          writeChanges = false
        end
        -- seek to new sector
        bufferSect=sect
        seek(sect*sectorSize+1)
        bufferData=read(sectorSize)
      end
    end
    return {
      ["getPlatterSize"]=function() return 1 end, -- why does this exist
      ["getSectorSize"]=function() return sectorSize end,
      ["getCapacity"]=function() return tape.getSize() end,
      ["getLabel"]=function() return tape.getLabel() end,
      ["setLabel"]=function(label) return tape.setLabel(label) end,
      ["readByte"]=function(pos)
        checkArg(1,pos,"number")
        if readBuffer==false then
          seek(pos)
          return read()
        else
          updateBuffer(pos)
          return bufferData:byte((pos-1)%sectorSize+1)
        end
      end,
      ["writeByte"]=function(pos,value)
        checkArg(1,pos,"number")
        checkArg(2,value,"number")
        if readBuffer then
          updateBuffer(pos)
          bufferData = bufferData:sub(1,(pos-1)%sectorSize)..string.char(value)..bufferData:sub(((pos-1)%sectorSize)+2)
        end
        if writeBuffer then
          if not writeChanges then
            writeChanges = true
            writeChangeTime = computer.uptime()
          end
        else
          seek(pos)
          write(value)
        end
      end,
      ["readSector"]=function(sector)
        checkArg(1,sector,"number")
        if readBuffer==false then
          seek((sector-1)*sectorSize+1)
          return read(sectorSize)
        else
          updateBuffer((sector-1)*sectorSize+1)
          return bufferData
        end
      end,
      ["writeSector"]=function(sector,value)
        checkArg(1,sector,"number")
        checkArg(2,value,"string")
        if readBuffer then
          bufferData = value..bufferData:sub(#value+1)
        end
        seek((sector-1)*sectorSize+1)
        write(value)
      end
    }, function()
      if writeBuffer and writeChanges then
        if computer.uptime()>writeChangeTime+writeUpdate then
          seek(bufferSect*sectorSize+1)
          write(bufferData)
          writeChanges = false
        end
      end
    end
  end
  local coroutines = {}
  local function handleComponent(id)
    if not containsDrive(id) then return end
    local tapeProxy = component.proxy(id)
    if not tapeProxy then return end
    local driveProxy, proxyCorFunc = handleProxy(tapeProxy)
    local readyBef = tapeProxy.isReady()
    if readyBef then component.virtual.add(id,"drive",driveProxy) end
    local cor = cormgr.addCoroutine(function()
      while true do
        local ready = nil
        local success, reason = pcall(function()
          ready = tapeProxy.isReady()
        end)
        if success then
          if readyBef~=ready then
            readyBef=ready
            if ready then
              component.virtual.add(id,"drive",driveProxy)
            else
              component.virtual.remove(id)
            end
          end
          proxyCorFunc()
        end
        coroutine.yield()
      end
    end,"utape-drive-"..id)
    coroutines[id]=cor
  end
  for id in pairs(component.list("tape_drive")) do
    handleComponent(id)
  end
  cormgr.addCoroutine(function()
    while true do
      local ev = {event.pull("component_added","component_removed")}
      if ev then
        if ev[1]=="component_added" and ev[3]=="tape_drive" then
          handleComponent(ev[2])
        end
        if ev[1]=="component_removed" and coroutines[ev[2]]~=nil then
          local id = ev[2]
          cormgr.removeCoroutine("utape-drive-"..id)
          if component.list("drive")[id]=="drive" then component.virtual.remove(id) end
        end
      end
      coroutine.yield()
    end
  end,"utape")
end
if config.disabled then
  driver.onStartup = function() end
end

return driver
