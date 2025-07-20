local filesystem = import("filesystem")
local component = import("component")
local unicode = import("unicode")
local gpu = component.gpu
local ctif = {}
local signature = "CTIF"

ctif.CCWide = true

local ccDefaultPalette = {
  0xF0F0F0, 0xF2B233, 0xE57FD8, 0x99B2F2,
  0xDEDE6C, 0x7FCC19, 0xF2B2CC, 0x4C4C4C,
  0x999999, 0x4C99B2, 0xB266E5, 0x3366CC,
  0x7F664C, 0x57A64E, 0xCC4C4C, 0x111111
}

local function getBraille(n)
  n=n-1
  local dat = (n & 0x01) << 7
  dat = dat | (n & 0x02) >> 1 << 6
  dat = dat | (n & 0x04) >> 2 << 5
  dat = dat | (n & 0x08) >> 3 << 2
  dat = dat | (n & 0x10) >> 4 << 4
  dat = dat | (n & 0x20) >> 5 << 1
  dat = dat | (n & 0x40) >> 6 << 3
  dat = dat | (n & 0x80) >> 7
  return unicode.char(0x2800 | dat)
end

local SEXTANTS = {
  ' ', '🬞', '🬏', '🬭', '🬇', '🬦', '🬖', '🬵', '🬃',
  '🬢', '🬓', '🬱', '🬋', '🬩', '🬚', '🬹', '🬁', '🬠',
  '🬑', '🬯', '🬉', '▐', '🬘', '🬷', '🬅', '🬤', '🬔',
  '🬳', '🬍', '🬫', '🬜', '🬻', '🬀', '🬟', '🬐', '🬮',
  '🬈', '🬧', '🬗', '🬶', '🬄', '🬣', '▌', '🬲', '🬌',
  '🬪', '🬛', '🬺', '🬂', '🬡', '🬒', '🬰', '🬊', '🬨',
  '🬙', '🬸', '🬆', '🬥', '🬕', '🬴', '🬎', '🬬', '🬝',
  '█' }

local function getSextant(n)
  return (SEXTANTS)[(n&0x3F)+1] or "?"
end

local function getChar(image,n)
  if image.ctif.charHeight==3 then
    n=n-1
    if ctif.CCWide then
      return getSextant((n&0xaa)|((n&0xaa)>>1))..getSextant((n&0x55)|((n&0x55)<<1))
    else
      return getSextant(n)
    end
  else
    return getBraille(n)
  end
end

local function getCharRaw(image,n)
  if image.ctif.charHeight==3 then
    return getSextant(n-1)
  else
    return getBraille(n)
  end
end

local function getPalette(image,i)
  if i<16 then
    local col = image.data.palette[i+1]
    if col~=nil then return col end
    if image.ctif.platformId==2 then
      return ccDefaultPalette[i+1]
    end
    return (i * 15) << 16 | (i * 15) << 8 | (i * 15)
  else
    local j = i - 16
    local b = math.floor((j % 5) * 255 / 4.0)
    local g = math.floor((math.floor(j / 5.0) % 8) * 255 / 7.0)
    local r = math.floor((math.floor(j / 40.0) % 6) * 255 / 5.0)
    return r << 16 | g << 8 | b
  end
end

local function getCharNum(chr)
  local point = unicode.codepoint(chr)

  if point>=0x2800 and point<=0x28FF then
    return point&0xFF
  end

  return table.find(SEXTANTS,chr)
end

local function colorDiff(c1,c2)
  return math.abs((c1>>16)-(c2>>16))
        +math.abs(((c1>>8)&255)-((c2>>8)&255))
        +math.abs((c1&255)-(c2&255))
end

local function fromPalette(image,color)
  local diff,idx = math.inf,nil
  for i=0,255 do
    local palc = getPalette(image,i)
    local ndif = colorDiff(color,palc)
    if ndif<diff then
      diff = ndir
      val = i
    end
  end
  return val
end

local function exportImage(image)
  local content = ""
  local function write(str)
    content=content..str
  end
  local function writeNumber(num,n)
    for i=1,n or 1 do
      content=content..string.char(num&0xFF)
      num=num>>8
    end
  end

  write(signature)

  writeNumber(1)
  writeNumber(0)
  writeNumber(image.ctif.platformId,2)

  writeNumber(image.width,2)
  writeNumber(image.height,2)
  writeNumber(image.ctif.charWidth)
  writeNumber(image.ctif.charHeight)
  writeNumber(image.bitDepth)

  writeNumber(3)
  writeNumber(#image.data.palette,2)
  for i=1,#image.data.palette do
    writeNumber(image.data.palette[i],3)
  end

  for i=1,#image.data.chars do
    if image.bitDepth > 4 then
      writeNumber(image.data.chars[i][3])
      writeNumber(image.data.chars[i][2])
    else
      writeNumber((image.data.chars[i][3]<<4)|image.data.chars[i][2])
    end
    writeNumber(image.data.chars[i][1]-1)
  end

  return content
end

function ctif.new(width,height,bitDepth,charWidth,charHeight,platformId,palette)
  checkArg(1,width,"number")
  checkArg(2,height,"number")
  checkArg(3,bitDepth,"nil","number")
  checkArg(4,charWidth,"nil","number")
  checkArg(5,charHeight,"nil","number")
  checkArg(6,platformId,"nil","number")
  checkArg(7,palette,"nil","table")
  bitDepth = bitDepth or gpu.getDepth()
  charWidth = charWidth or 2
  charHeight = charHeight or 4
  platformId = platformId or 1
  palette = palette or {}

  local image = {
    ["width"]=width,
    ["height"]=height,
    ["bitDepth"]=bitDepth,
    ["ctif"]={
      ["platformId"]=platformId,
      ["charWidth"]=charWidth,
      ["charHeight"]=charHeight
    },
    ["data"]={
      ["palette"]=palette,
      ["chars"]={}
    },
    ["setPalette"]=function(self)
      checkArg(1,self,"table")
      for i,v in ipairs(self.data.palette) do
        gpu.setPaletteColor(i-1,v)
      end
    end,
    ["show"]=function(self,x,y,width,height,keepPalette,dx,dy)
      checkArg(1,self,"table")
      checkArg(2,x,"number","nil")
      checkArg(3,y,"number","nil")
      checkArg(4,width,"number","nil")
      checkArg(5,height,"number","nil")
      checkArg(6,keepPalette,"boolean","nil")
      checkArg(7,dx,"number","nil",nil)
      checkArg(8,dy,"number","nil",nil)
      x=math.floor(x or 1)
      y=math.floor(y or 1)
      dx=math.floor(dx or 1)
      dy=math.floor(dy or 1)
      local gpuWidth,gpuHeight = gpu.getResolution()
      width = width or self.renderWidth
      height = height or self.renderHeight

      width = math.floor(math.min(width,self.renderWidth))
      height = math.floor(math.min(height,self.renderHeight))

      if not keepPalette then
        self:setPalette()
      end

      for j=math.max(y,1),math.min(y-1+height-(dy-1),gpuHeight) do
        for i=math.max(x-(dx-1)%self.ctif.renderCharWidth,1),math.min(x-1+width-(dx-1),gpuWidth)+(self.ctif.renderCharWidth-1),self.ctif.renderCharWidth do
          local cx = (i-x+(dx-1))//self.ctif.renderCharWidth+1
          local cy = (j-y+(dy-1))//self.ctif.renderCharHeight+1
          local idx = cx+(cy-1)*self.width
          if cx>=1 and cy>=1 and cx<=self.width and cy<=self.height and self.data.chars[idx] then
            gpu.setForeground(getPalette(self,self.data.chars[idx][2]))
            gpu.setBackground(getPalette(self,self.data.chars[idx][3]))
            local char = getChar(self,self.data.chars[idx][1])
            if i<math.max(x,1) then
              gpu.set(i+(dx-1)%self.ctif.renderCharWidth,j,unicode.sub(char,(dx-1)%self.ctif.renderCharWidth+1))
            elseif i>=math.min(x-1+width-(dx-1),gpuWidth) then
              if i-x+dx<=self.renderWidth then
                gpu.set(i,j,unicode.sub(char,1,1+width%self.ctif.renderCharWidth))
              end
            else
              gpu.set(i,j,char)
            end
          end
        end
      end
    end,
    ["getChar"]=function(self,x,y)
      checkArg(1,self,"table")
      checkArg(2,width,"number")
      checkArg(3,height,"number")

      if x<1 or x>width or y<1 or y>height then return end

      local idx = x+(y-1)*self.width
      return getCharRaw(self,self.data.chars[idx][1]),
             getPalette(self,self.data.chars[idx][2]),
             getPalette(self,self.data.chars[idx][3])
    end,
    ["setChar"]=function(self,x,y,chr,fg,bg,isPaletteIndex)
      checkArg(1,self,"table")
      checkArg(2,width,"number")
      checkArg(3,height,"number")
      checkArg(4,chr,"string")
      checkArg(5,fg,"number")
      checkArg(6,bg,"number")

      if x<1 or x>width or y<1 or y>height then return false end

      local idx = x+(y-1)*self.width
      if self.data.chars[idx]==nil then return false end

      self.data.chars[idx][1] = getCharNum(chr)
      self.data.chars[idx][2] = isPaletteIndex and fg or fromPalette(image,fg)
      self.data.chars[idx][3] = isPaletteIndex and bg or fromPalette(image,bg)

      return true
    end,
    ["get"]=function(self,x,y)
      checkArg(1,self,"table")
      checkArg(2,width,"number")
      checkArg(3,height,"number")

      if x<1 or x>image.renderWidth or y<1 or y>image.renderHeight then return end

      local cx = (x-1)//image.ctif.renderCharWidth+1
      local cy = (y-1)//image.ctif.renderCharHeight+1
      local sx = (x-1)%image.ctif.renderCharWidth+1
      local sy = (y-1)%image.ctif.renderCharHeight+1

      local idx = cx+(cy-1)*self.width
      return unicode.sub(getChar(self,self.data.chars[idx][1]),sy,sy),
             getPalette(self,self.data.chars[idx][2]),
             getPalette(self,self.data.chars[idx][3])
    end,
    ["save"]=function(self,file)
      checkArg(1,self,"table")
      checkArg(2,file,"nil","string")
      local content = exportImage(self)
      if file then
        local handle = filesystem.open(file,"wb")
        handle:write(content)
        handle:close()
      end
      return content
    end
  }

  for i=1,width*height do
    table.insert(image.data.chars,{0,1,1})
  end

  image.ctif.renderCharWidth = 1
  image.ctif.renderCharHeight = 1
  if platformId==2 and ctif.CCWide then image.ctif.renderCharWidth=2 end

  image.renderWidth = width*image.ctif.renderCharWidth
  image.renderHeight = height*image.ctif.renderCharHeight

  return image
end

local function getMetadata(file)
  local fileSignature = file:read(#signature)
  if fileSignature ~= signature then
    error("invalid signature (expected \""..signature.."\", got \""..fileSignature.."\")")
  end

  local headerVersion = file:readBytes(1)
  if headerVersion > 1 then
    error("unknown header version (expected 1, got "..headerVersion..")")
  end

  local platformVariant = file:readBytes(1)
  local platformId = file:readBytes(2)
  if (platformId ~= 1 and platformId ~= 2) or platformVariant ~= 0 then
    error("unsupported platform ID: " .. platformId .. ":" .. platformVariant)
  end

  local width,height = file:readBytes(2),file:readBytes(2)
  local charWidth,charHeight = file:readBytes(1),file:readBytes(1)
  if charWidth~=2 or (charHeight~=3 and charHeight~=4) then
    error("image uses "..charWidth.."x"..charHeight.." resolution characters instead of 2x4 or 2x3")
  end

  local bitDepth = file:readBytes(1)

  return width,height,bitDepth,platformId,charWidth,charHeight
end

local function getData(file,width,height,bitDepth,platformId,charWidth,charHeight)
  local ccEntrySize = file:readBytes(1)
  local customColors = file:readBytes(2)
  if customColors > 0 and ccEntrySize ~= 3 then
    error("unsupported palette entry size: " .. ccEntrySize)
  end
  if customColors > 16 then
    error("unsupported palette entry amount: " .. customColors)
  end

  local palette = {}
  for p=1,customColors do
    palette[p] = file:readBytes(3)
  end

  local image = ctif.new(width,height,bitDepth,charWidth,charHeight,platformId,palette)

  for y=1,height do
    for x=1,width do
      local j = (y-1)*width+x
      local cw,fg,bg
      if bitDepth > 4 then
        bg = file:readBytes(1)
        fg = file:readBytes(1)
      else
        local color = file:readBytes(1)
        bg = (color >> 4) & 0x0F
        fg = color & 0x0F
      end
      cw = file:readBytes(1) + 1
      -- These colors are palette indexes, not actual colors
      image.data.chars[j] = {cw,fg,bg}
    end
  end
  return image
end

local function decodeImage(file)
  file.littleEndian = true
  local width,height,bitDepth,platformId,charWidth,charHeight = getMetadata(file)
  return getData(file,width,height,bitDepth,platformId,charWidth,charHeight)
end

function ctif.load(fpath)
  checkArg(1,fpath,"string")
  local file = filesystem.open(fpath,"rb")
  if not file then return false, "File "..fpath.." does not exist." end

  return xpcall(function()
    return decodeImage(file)
  end,function(...)
    file:close()
    return debug.traceback(...)
  end)
end

ctif.open = ctif.load

return ctif
