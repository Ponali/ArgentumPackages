local event = import("event")
local component = import("component")
local computer = import("computer")
local gpu = component.proxy(component.list("gpu")())
local screen_width,screen_height = gpu.getResolution()

local currentQuality = 1

gpu.fill(1,1,screen_width,screen_height-1," ")
gpu.setForeground(0x000000)
gpu.setBackground(0xFFFFFF)
gpu.fill(1,screen_height,screen_width,1," ")
gpu.set(1,screen_height,"Spinning donut demo")
gpu.setForeground(0x484848)
gpu.set(22,screen_height,"[Q] Quit | Mode: [T] Text [P] Pixels | Quality: [H] High [M] Medium [L] Low")
local qualities = {{"H",71},{"M",80},{"L",91}}

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
gpu.set(qualities[currentQuality][2],screen_height,"H")

local render_buffer = gpu.allocateBuffer()
gpu.setActiveBuffer(render_buffer)

function changeQuality(q)
  gpu.setActiveBuffer(0)
  gpu.fill(1,1,screen_width,screen_height-1," ")
  gpu.setForeground(0x484848)
  gpu.setBackground(0xFFFFFF)
  gpu.set(qualities[currentQuality][2],screen_height,qualities[currentQuality][1])
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  gpu.set(qualities[q][2],screen_height,qualities[q][1])
  gpu.setActiveBuffer(render_buffer)

  currentQuality=q
end

local R1 = 1
local R2 = 2
local K2 = 5
-- Calculate K1 based on screen size: the maximum x-distance occurs
-- roughly at the edge of the torus, which is at x=R1+R2, z=0.  we
-- want that to be displaced 3/8ths of the width of the screen, which
-- is 3/4th of the way from the center to the side of the screen.
-- screen_width*3/8 = K1*(R1+R2)/(K2+0)
-- screen_width*K2*3/(8*(R1+R2)) = K1
local K1 = screen_width*K2*3/(8*(R1+R2));

local mode = 0

local running=true

local eventTime = computer.uptime()

function listenForEvents()
  -- if computer.uptime()-eventTime<0.2 then return end
  eventTime=computer.uptime()
  coroutine.yield()
  local args = {event.pull("key_down",0.00001)}
  if args and args[1] then
    local chr = keyboard.keys[args[4]]
    -- print("CHR "..chr)
    if chr=="q" then running=false end
    if chr=="t" then mode=0 end
    if chr=="p" then mode=1 end
    if chr=="h" then changeQuality(1) end
    if chr=="m" then changeQuality(2) end
    if chr=="l" then changeQuality(3) end
  end
end

function set_pixel(x,y,lum)
  if mode==0 then
    local idx = math.ceil(lum*12)
    gpu.set(x,y,(".,-~:;=!*#$@"):sub(idx,idx))
  end
  if mode==1 then
    gpu.setBackground(math.min(math.max(math.floor(lum*255),0),255)*0x10101)
    gpu.set(x,y," ")
  end
  -- listenForEvents()
end

function render_frame(A,B)
  local size = ({0.7,0.55,0.4})[currentQuality]
  local donut_width,donut_height = math.floor(math.min(screen_width,screen_height*2)*size),math.floor(math.min(screen_width/2,screen_height)*size)-1

  local zoom = 1.6/size


  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  gpu.fill(1,1,donut_width,donut_height," ")

  -- precompute sines and cosines of A and B
  cosA = math.cos(A); sinA = math.sin(A);
  cosB = math.cos(B); sinB = math.sin(B);

  local theta_spacing = (0.10-(math.abs(cosA)^2)*0.03)*({1,1.75,2.5})[currentQuality] -- 0.07
  local phi_spacing   = (0.08-(math.abs(cosA)^2)*0.06)*({1,1.75,2.5})[currentQuality] -- 0.02

  -- output[0..screen_width, 0..screen_height] = ' ';
  -- zbuffer[0..screen_width, 0..screen_height] = 0;
  zbuffer={}
  for y=1,donut_height do
    table.insert(zbuffer,{})
    for x=1,donut_width do
      table.insert(zbuffer[y],0)
    end
  end

  -- theta goes around the cross-sectional circle of a torus
  for theta=0,2*math.pi,theta_spacing do
    -- precompute sines and cosines of theta
    costheta = math.cos(theta)
    sintheta = math.sin(theta)

    -- phi goes around the center of revolution of a torus
    for phi=0,2*math.pi,phi_spacing do
      -- precompute sines and cosines of phi
      cosphi = math.cos(phi)
      sinphi = math.sin(phi)

      -- the x,y coordinate of the circle, before revolving (factored
      -- out of the above equations)
      circlex = R2 + R1*costheta;
      circley = R1*sintheta;

      -- final 3D (x,y,z) coordinate after rotations, directly from
      -- our math above
      x = circlex*(cosB*cosphi + sinA*sinB*sinphi)
        - circley*cosA*sinB;
      y = circlex*(sinB*cosphi - sinA*cosB*sinphi)
        + circley*cosA*cosB;
      z = K2 + cosA*circlex*sinphi + circley*sinA
      ooz = 1/z;  -- "one over z"

      -- x and y projection.  note that y is negated here, because y
      -- goes up in 3D space but down on 2D displays.
      xp = math.floor(donut_width/2 + K1*ooz*x/zoom)
      yp = math.ceil(donut_height/2 - K1*ooz*y/2/zoom)

      -- calculate luminance.  ugly, but correct.
      L = cosphi*costheta*sinB - cosA*costheta*sinphi -
        sinA*sintheta + cosB*(cosA*sintheta - costheta*sinA*sinphi)
      -- L ranges from -sqrt(2) to +sqrt(2).  If it's < 0, the surface
      -- is pointing away from us, so we won't bother trying to plot it.
      if L>0 then
        -- test against the z-buffer.  larger 1/z means the pixel is
        -- closer to the viewer than what's already plotted.
        if zbuffer[yp] and zbuffer[yp][xp] and ooz > zbuffer[yp][xp] then
          zbuffer[yp][xp] = ooz
          -- luminance_index is now in the range 0..11 (8*sqrt(2) = 11.3)
          -- now we lookup the character corresponding to the
          -- luminance and plot it in our output:
          --output[xp, yp] = ".,-~:;=!*#$@"[luminance_index];
          set_pixel(xp,yp,L/1.5)
        end
      end
    end
  end

  local x,y,w,h,fx,fy = math.floor((screen_width-donut_width)/2)+1,math.floor((screen_height-donut_height)/2)+1,donut_width,donut_height,1,1
  gpu.bitblt(0,x,y,w,h,render_buffer,fx,fy)

end

while running do
  --render_frame(1+i*0.07*4,1+i*0.03*4)
  local time = computer.uptime()
  render_frame(1+time*1.4,1+time*0.6)
  listenForEvents()
end

gpu.setActiveBuffer(0)
gpu.freeAllBuffers()

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1,1,screen_width,screen_height," ")
termlib.cursorPosX=1
termlib.cursorPosY=1
