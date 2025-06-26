local filesystem = import("filesystem")
local component = import("component")
local gpu = component.gpu
local ocelot = component.proxy(component.list("ocelot")())
local ocif = {}
local signature = "OCIF"

local palette = {0x000000, 0x000040, 0x000080, 0x0000BF, 0x0000FF, 0x002400, 0x002440, 0x002480, 0x0024BF, 0x0024FF, 0x004900, 0x004940, 0x004980, 0x0049BF, 0x0049FF, 0x006D00, 0x006D40, 0x006D80, 0x006DBF, 0x006DFF, 0x009200, 0x009240, 0x009280, 0x0092BF, 0x0092FF, 0x00B600, 0x00B640, 0x00B680, 0x00B6BF, 0x00B6FF, 0x00DB00, 0x00DB40, 0x00DB80, 0x00DBBF, 0x00DBFF, 0x00FF00, 0x00FF40, 0x00FF80, 0x00FFBF, 0x00FFFF, 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x330000, 0x330040, 0x330080, 0x3300BF, 0x3300FF, 0x332400, 0x332440, 0x332480, 0x3324BF, 0x3324FF, 0x334900, 0x334940, 0x334980, 0x3349BF, 0x3349FF, 0x336D00, 0x336D40, 0x336D80, 0x336DBF, 0x336DFF, 0x339200, 0x339240, 0x339280, 0x3392BF, 0x3392FF, 0x33B600, 0x33B640, 0x33B680, 0x33B6BF, 0x33B6FF, 0x33DB00, 0x33DB40, 0x33DB80, 0x33DBBF, 0x33DBFF, 0x33FF00, 0x33FF40, 0x33FF80, 0x33FFBF, 0x33FFFF, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x660000, 0x660040, 0x660080, 0x6600BF, 0x6600FF, 0x662400, 0x662440, 0x662480, 0x6624BF, 0x6624FF, 0x664900, 0x664940, 0x664980, 0x6649BF, 0x6649FF, 0x666D00, 0x666D40, 0x666D80, 0x666DBF, 0x666DFF, 0x669200, 0x669240, 0x669280, 0x6692BF, 0x6692FF, 0x66B600, 0x66B640, 0x66B680, 0x66B6BF, 0x66B6FF, 0x66DB00, 0x66DB40, 0x66DB80, 0x66DBBF, 0x66DBFF, 0x66FF00, 0x66FF40, 0x66FF80, 0x66FFBF, 0x66FFFF, 0x696969, 0x787878, 0x878787, 0x969696, 0x990000, 0x990040, 0x990080, 0x9900BF, 0x9900FF, 0x992400, 0x992440, 0x992480, 0x9924BF, 0x9924FF, 0x994900, 0x994940, 0x994980, 0x9949BF, 0x9949FF, 0x996D00, 0x996D40, 0x996D80, 0x996DBF, 0x996DFF, 0x999200, 0x999240, 0x999280, 0x9992BF, 0x9992FF, 0x99B600, 0x99B640, 0x99B680, 0x99B6BF, 0x99B6FF, 0x99DB00, 0x99DB40, 0x99DB80, 0x99DBBF, 0x99DBFF, 0x99FF00, 0x99FF40, 0x99FF80, 0x99FFBF, 0x99FFFF, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xCC0000, 0xCC0040, 0xCC0080, 0xCC00BF, 0xCC00FF, 0xCC2400, 0xCC2440, 0xCC2480, 0xCC24BF, 0xCC24FF, 0xCC4900, 0xCC4940, 0xCC4980, 0xCC49BF, 0xCC49FF, 0xCC6D00, 0xCC6D40, 0xCC6D80, 0xCC6DBF, 0xCC6DFF, 0xCC9200, 0xCC9240, 0xCC9280, 0xCC92BF, 0xCC92FF, 0xCCB600, 0xCCB640, 0xCCB680, 0xCCB6BF, 0xCCB6FF, 0xCCDB00, 0xCCDB40, 0xCCDB80, 0xCCDBBF, 0xCCDBFF, 0xCCFF00, 0xCCFF40, 0xCCFF80, 0xCCFFBF, 0xCCFFFF, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0, 0xFF0000, 0xFF0040, 0xFF0080, 0xFF00BF, 0xFF00FF, 0xFF2400, 0xFF2440, 0xFF2480, 0xFF24BF, 0xFF24FF, 0xFF4900, 0xFF4940, 0xFF4980, 0xFF49BF, 0xFF49FF, 0xFF6D00, 0xFF6D40, 0xFF6D80, 0xFF6DBF, 0xFF6DFF, 0xFF9200, 0xFF9240, 0xFF9280, 0xFF92BF, 0xFF92FF, 0xFFB600, 0xFFB640, 0xFFB680, 0xFFB6BF, 0xFFB6FF, 0xFFDB00, 0xFFDB40, 0xFFDB80, 0xFFDBBF, 0xFFDBFF, 0xFFFF00, 0xFFFF40, 0xFFFF80, 0xFFFFBF, 0xFFFFFF}

function ocif.new(width,height)
    chr={}
    fgc={}
    bgc={}
    alp={}
    for i=1,width*height do
        table.insert(chr," ")
        table.insert(fgc,0xFFFFFF)
        table.insert(bgc,0x000000)
        table.insert(alp,0)
    end
    return {
        ["ocif"]={},
        ["width"]=width,
        ["height"]=height,
        ["data"]={chr,fgc,bgc,alp},
        ["set"]=function(self,x,y,chr,fg,bg,al)
            checkArg(1,self,"table")
            checkArg(2,x,"number")
            checkArg(3,y,"number")
            checkArg(4,chr,"string")
            checkArg(5,fg,"number","nil")
            checkArg(6,bg,"number","nil")
            checkArg(7,al,"number","nil")
            fg = fg or 0xFFFFFF
            bg = bg or 0
            al = al or 1

            if x<1 or x>self.width or y<1 or y>self.height then return end

            local idx = x+(y-1)*self.width

            self.data[1][idx]=chr
            self.data[2][idx]=fg
            self.data[3][idx]=bg
            self.data[4][idx]=al
        end,
        ["show"]=function(self,x,y)
            checkArg(1,self,"table")
            checkArg(2,x,"number","nil")
            checkArg(3,y,"number","nil")
            x=x or 1
            y=y or 1
            for j=1,self.height do
                for i=1,self.width do
                    local idx = i+(j-1)*self.width
                    if self.data[4][idx]==1 and self.data[1][idx]==" " then goto continue end
                    gpu.setForeground(self.data[2][idx])
                    if self.data[4][idx]==1 then
                        gpu.setBackground(({gpu.get(i+x-1,j+y-1)})[3])
                    else
                        gpu.setBackground(self.data[3][idx])
                    end
                    gpu.set(i+x-1,j+y-1,self.data[1][idx])
                    ::continue::
                end
            end
        end,
        ["toansi"]=function(self)
            local function encodeColor(id,c)
                local out = "\x1b["..id..";2;"..((c>>16)&255)..";"..((c>>8)&255)..";"..(c&255).."m"
                ocelot.log(c.." -> "..out)
                return out
            end
            out=""
            for j=1,self.height do
                local fg = nil
                local bg = nil
                for i=1,self.width do
                    local idx = i+(j-1)*self.width
                    ocelot.log(table.concat({
                        self.data[1][idx],
                        self.data[2][idx],
                        self.data[3][idx],
                        self.data[4][idx]
                    }," "))
                    if self.data[2][idx]~=fg then
                        fg=self.data[2][idx]
                        out=out..encodeColor(38,fg)
                    end
                    if self.data[4][idx]==1 then
                        if bg~=nil then
                            bg=nil
                            out=out.."\x1b[49m"
                        end
                    else
                        if self.data[3][idx]~=bg then
                            bg=self.data[3][idx]
                            out=out..encodeColor(48,bg)
                        end
                    end
                    out=out..self.data[1][idx]
                end
                out=out.."\x1b[0m\n"
            end
            return out
        end
    }
end

local function to24Bit(x)
    return palette[x+1]
end

local codecs = {
    [6]={
        ["meta"]=function(file)
            return file:readBytes(), file:readBytes()
        end,
        ["pixel"]=function(file,width,height)
            local img = ocif.new(width,height)
            for alpha = 1, file:readBytes(1) do
                local currentAlpha = file:readBytes(1) / 255

                for symbol = 1, file:readBytes(2) do
                    local currentSymbol = file:readUnicodeChar()

                    for background = 1, file:readBytes(1) do
                        local currentBackground = to24Bit(file:readBytes(1))

                        for foreground = 1, file:readBytes(1) do
                            local currentForeground = to24Bit(file:readBytes(1))

                            for y = 1, file:readBytes(1) do
                                local currentY = file:readBytes(1)

                                for x = 1, file:readBytes(1) do
                                    img:set(
                                        file:readBytes(1),
                                        currentY,
                                        currentSymbol,
                                        currentForeground,
                                        currentBackground,
                                        currentAlpha
                                    )
                                end
                            end
                        end
                    end
                end
            end
            return img
        end
    }
}

local function getMetadata(file)
    fileSignature = file:read(#signature)
    if fileSignature ~= signature then
        error("invalid signature (expected \""..signature.."\", got \""..fileSignature.."\")")
    end

    local method = string.byte(file:read(1))
    assert(codecs[method], "codec #"..method.." is not supported.")

    local width, height = codecs[method].meta(file)

    return method, width, height
end

local function getPixelData(file,method,width,height)
    return codecs[method].pixel(file,width,height)
end

function ocif.load(fpath)
    checkArg(1,fpath,"string")
    local file = filesystem.open(fpath,"r")
    if not file then return false, "File "..fpath.." does not exist." end

    return xpcall(function()
        local method, width, height = getMetadata(file)
        local img = getPixelData(file,method,width,height)
        img.ocif.codec=method
        return img
    end,function(...)
        file:close()
        return debug.traceback(...)
    end)
end

ocif.open = ocif.load

return ocif
