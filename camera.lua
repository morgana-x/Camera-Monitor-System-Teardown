camera = nil
monitor = nil

screen = {}


cameraQuality = 0.2
cameraResolutionX, cameraResolutionY = 200, 100




pixelSprite = nil -- LoadSprite('pixel.png')


screenWidth, screenHeight = 100, 100


complexLighting = true



MAX_RAY_DEPTH = 0 

max_depth = 2
samples_per_pixel = 1
local screenDownScale = 100


 skyTintR, skyTintG, skyTintB = GetEnvironmentProperty("skyboxtint")
 skyBrightness = GetEnvironmentProperty("skyboxbrightness")

 skyAmbient = GetEnvironmentProperty("ambient")

 brightness = GetEnvironmentProperty("brightness")

 baseRed, baseBlue, baseGreen = GetEnvironmentProperty("constant")
cameraIsBody = false
monitorIsBody = false
function init()
    pixelSprite = LoadSprite("image/pixel.png")
    for x = 1, cameraResolutionX do
        screen[x] = {}
    
        for y = 1, cameraResolutionX do
            screen[x][y] = {}
        end
    end
    camera = FindShape('camera')
    monitor = FindShape('screen')

    if camera == 0 then
        camera = FindBody('camera')
    end
    if monitor == 0 then
        monitor = FindBody('monitor')
    end
 --   DebugPrint(camera)
--    DebugPrint(monitor)


end

local sunDirX, sunDirY, sunDirZ = GetEnvironmentProperty("sunDir")
local sunDir = VecNormalize(Vec(1, 1, 1))
local water = {0.2,0.3,0.5}

pixelSize =  0.05

focal_length = 1


function getInfo(startpos, shape, dir, dist)
    local hitPoint = VecAdd(startpos, VecScale(dir, dist))
    local mat, r,g,b = GetShapeMaterialAtPosition(shape,hitPoint)
    return hitPoint, mat, r, g,b
end

function castRay(startpos, dir, ignoreTransperant)
    local hit, dist, normal, shape = QueryRaycast( startpos , dir, 100,0, ignoreTransperant) 
    local hitPoint = VecAdd(startpos, VecScale(dir, dist))
    local mat, r,g,b = GetShapeMaterialAtPosition(shape,hitPoint)
    return hitPoint, dist, mat, r, g,b
end

local fov = math.rad(60) -- Set FOV to 60 degrees (adjust as needed)
local half_fov_tan = math.tan(fov / 2)
aspect_ratio = cameraResolutionX  / cameraResolutionY
function ray_color(startpos, transform, depth, x, y)
    if depth > max_depth then return 0,0,0,false end 
   local dir =  TransformToParentVec(transform,Vec(-0,0,-1))	
   local func = (cameraIsBody and QueryRejectBody(camera)) or  QueryRejectShape(camera)
   local hit, dist, normal, shape = QueryRaycast(startpos, dir, 500, 0, false) 

    local red, green, blue = 0,0,0   

    sky = false
    
    if not (hit and shape) then 
        --DebugLine(startpos,VecScale(startpos,dist),1,0,0,1)
        red, green, blue =          skyTintR * skyBrightness * 0.9 * samples_per_pixel,      skyTintG * skyBrightness * 0.9 * samples_per_pixel,      skyTintB * skyBrightness * 0.9 * samples_per_pixel
        sky = true
    else
        local hitPoint, mat, r,g,b = getInfo(startpos, shape, dir, dist)
        local shade = (normal[1] * -sunDir[1] + normal[2] * -sunDir[2] + normal[3] * -sunDir[3]) * -0.1 + 0.4
         shade = shade * skyBrightness 
        shade = shade * skyAmbient --* brightness

        red = r * shade   --/  (dist )
        green =  g * shade  -- / (dist )
        blue =  b  * shade --/ (dist )

        DebugLine(startpos, hitPoint)

        if IsPointInWater(hitPoint) then
            red = water[1]
            green = water[2]
            blue = water[3]
        end
--[[
        local target = VecAdd(hitPoint, normal)
        local rr, gg, bb, sky = ray_color( VecAdd(hitPoint, normal), VecSub(hitPoint, target), depth+1)



        red = red + (rr / depth) -- divide by needs fixing
        green = green + (gg  / depth)
        blue = blue + (bb /  depth)]]
    end




    return red, green, blue, sky
end
function tick()
    skyTintR, skyTintG, skyTintB = GetEnvironmentProperty("skyboxtint")
    skyBrightness = GetEnvironmentProperty("skyboxbrightness")
   
    skyAmbient = GetEnvironmentProperty("ambient")

    brightness = GetEnvironmentProperty("brightness")
    local transform = (cameraIsBody and GetBodyTransform(camera)) or  GetShapeWorldTransform(camera)

    --DebugPrint(transform.pos[3])
    DebugCross(transform.pos)

    local dir  =   TransformToParentVec(transform,Vec(-0,0,-1))	
   -- dir = Vec(-0,0,-1)
    local originPosition = transform.pos
    local func = (cameraIsBody and QueryRejectBody(camera)) or  QueryRejectShape(camera)
    local hit, dist, normal, shape = QueryRaycast( transform.pos ,dir , 300,0, false) 
    local hitPoint = VecAdd(transform.pos, VecScale(dir, dist))
    DebugCross(hitPoint, 1,0,0,1)
    DebugLine(transform.pos, hitPoint)
    originPosition[1] = originPosition[1] - ( ( (cameraResolutionX  / screenDownScale) / 2) )
    originPosition[2] = originPosition[2] - 0.1 -- originPosition[2]   - ( ( (cameraResolutionY / screenDownScale) / 2) )


        for x=1, cameraResolutionX * cameraQuality  do  -- - (cameraResolutionX/2)   do
            for y=1, cameraResolutionY * cameraQuality  do -- - (cameraResolutionY/2)  do 
                local startpos = VecAdd(originPosition, Vec( (x / screenDownScale) / cameraQuality,(y / screenDownScale) / cameraQuality))
                local red, green, blue = 0,0,0
                for i=1, samples_per_pixel do
                  --  local u = (x + math.random() ) / (cameraResolutionY*cameraQuality) / 10
                  --  local customdir = VecAdd(   dir,   VecScale(dir, u) )
                    local r,g,b,sky = ray_color(startpos, transform, i,x,y)
                    red = red + r 
                    green = green + g
                    blue = blue + b
                    if sky then break end
                end
                red = red / samples_per_pixel
                green = green / samples_per_pixel
                blue = blue / samples_per_pixel
              
                screen[x][y] = {red,green,blue}
               -- DebugCross(startpos, red, green, blue)
            end
        end
    local screenTransform = ( monitorIsBody and GetBodyTransform(monitor) ) or GetShapeWorldTransform(monitor)
    DebugCross(screenTransform.pos)

    -- use get right and get up etc

    local right = TransformToParentVec(screenTransform,Vec(1,0,0))
    local up = 	TransformToParentVec(screenTransform, Vec(0,1,0))
    local forward = TransformToParentVec(screenTransform, Vec(0,0,1))

  
    for x=1, (cameraResolutionX * cameraQuality)  do
        local width = (x / screenDownScale) / cameraQuality 
        local halfwidth = (cameraResolutionX / screenDownScale)  / 2 



        for y=1, cameraResolutionY  *cameraQuality  do
            local height = (y / screenDownScale) / cameraQuality
            local halfheight =  (cameraResolutionY / screenDownScale)  / 2 
    

            local rightOffset = VecScale( right , width - 0.05  )
            local upOffset = VecScale( up, height - 0.05 )

            local offset =  VecAdd(VecAdd(rightOffset, upOffset), VecScale(forward, -0.11))
            local pos = VecAdd( screenTransform.pos, offset)
            --screenTransform.Pos = pos
            local col = screen[x][y]

            --local pos2 = VecAdd(pos, Vec(1/screenDownScale,1 / screenDownScale,1 / screenDownScale))
          --    DebugCross(pos,col[1],col[2],col[3],1)
              --DrawLine(pos,pos,col[1],col[2],col[3],1)
              DrawSprite(pixelSprite,Transform(pos, screenTransform.rot),pixelSize ,pixelSize  ,col[1],col[2],col[3],1, true, false)
             -- break 
        
        end
    end
end