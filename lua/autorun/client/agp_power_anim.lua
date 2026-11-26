-- PowerGrid: Grid Power parts come alive - moving parts (bones of the models), glowing that follows the part,
-- visible water / air and machine sounds. Called from agp_power_base's Draw.
--   solar panel   turns to the sun (motor sound while it moves)
--   pump (valve)  the wheel turns on open / close, liquid flows through the sight glass while open
--   water pump    rotor spins, water rises in the sight glass, water pours from the outlet, bubbles at the intake
--   compressor    fans spin, air swirls in the sight glass, air is drawn into the intakes
--   dispenser     the refill arm swings out on E
--   cache         the rings spin around the black hole
--   heater        the heating bars glow, low electric hum while it heats
--   cooler        the fan spins while it cools, low machine hum
--   splitter      bubbles rise in both gas columns, the electrodes crackle, bubbling hum
--   ram scoop     the collector ring turns (faster with speed), glowing motes are drawn into the mouth
--   fusion        the three plasma rings turn against each other inside the glass band, faster while it makes energy
--   hydro         the water wheel turns (fast while the generator is in water), splashes at its lower edge
--   steam turbine the rotor behind the glass window runs up and slows down
--   env probe     the sensor head turns slowly all the time
--   terraformer   the halo ring turns round the spire while it works, glowing motes rise from the emitter
--   hydroponics   the misting arm sweeps over the plants while they grow
--   gravity       the two rings turn against each other (faster at a stronger setting)
--   heavy water the centrifuge drum spins up while it extracts and runs down when it stops fuel cell soft
--   electric hum and trickling water while it works glow cores, tanks and rings
--   glow brighter the fuller / busier the part is (material proxy AGPGlow)
AGP = AGP or {}

local cvSound = CreateClientConVar("agp_power_sounds", "1", true, false, "Ascension Gates: machine sounds of PowerGrid parts", 0, 1)

local SOUNDS = {
    waterpump = { { "ambient/machines/city_ventpump_loop1.wav", 0.35, 105 }, { "ambient/water/water_flow_loop1.wav", 0.3, 100 } },
    compressor = { { "ambient/machines/courtyard_mach_loop.wav", 0.3, 115 } },
    pump = { { "ambient/water/water_flow_loop1.wav", 0.22, 120 } },
    cache = { { "ambient/levels/citadel/field_loop1.wav", 0.12, 70 } },
    heater = { { "ambient/energy/electric_loop.wav", 0.1, 70 } },
    cooler = { { "ambient/machines/courtyard_mach_loop.wav", 0.22, 90 } },
    splitter = { { "ambient/energy/electric_loop.wav", 0.08, 90 }, { "ambient/water/water_flow_loop1.wav", 0.18, 140 } },
    ramscoop = { { "ambient/levels/citadel/field_loop1.wav", 0.14, 90 } },
    fusion = { { "ambient/levels/citadel/field_loop1.wav", 0.2, 60 }, { "ambient/energy/electric_loop.wav", 0.08, 60 } },
    hydro = { { "ambient/water/water_flow_loop1.wav", 0.25, 100 } },
    turbine = { { "ambient/machines/courtyard_mach_loop.wav", 0.25, 105 } },
    terraformer = { { "ambient/levels/citadel/field_loop1.wav", 0.16, 50 } },
    plant = { { "ambient/water/water_flow_loop1.wav", 0.07, 165 } },
    gravity = { { "ambient/levels/citadel/field_loop1.wav", 0.12, 125 } },
    fuelcell = { { "ambient/energy/electric_loop.wav", 0.06, 110 }, { "ambient/water/water_flow_loop1.wav", 0.08, 160 } },
    heavywater = { { "ambient/machines/courtyard_mach_loop.wav", 0.2, 150 }, { "ambient/water/water_flow_loop1.wav", 0.1, 120 } },
}
local MOTOR = "ambient/levels/labs/machine_moving_loop3.wav"

local function bone(ent, name)
    ent.AGPBones = ent.AGPBones or {}
    local b = ent.AGPBones[name]
    if b == nil then
        b = ent:LookupBone(name) or false
        ent.AGPBones[name] = b
    end
    return b or nil
end

local function setAng(ent, name, ang)
    local b = bone(ent, name)
    if b then ent:ManipulateBoneAngles(b, ang, false) end
end

local function setPos(ent, name, pos)
    local b = bone(ent, name)
    if b then ent:ManipulateBonePosition(b, pos, false) end
end

local function show(ent, name, visible)
    local b = bone(ent, name)
    if b then ent:ManipulateBoneScale(b, visible and Vector(1, 1, 1) or Vector(0, 0, 0)) end
end

-- looping sounds: fade in while the part runs, out when it stops. (bug hunt): they were only started and stopped
-- while the part was drawn - a machine switched off behind the player's back hummed on, one switched on there was
-- silent, "Machine sounds" off did nothing until the part was looked at. Now a timer keeps them for every part.
local looping, motors = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function loops(ent)
    looping[ent] = true
end

local function keepLoops(ent, list)
    ent.AGPSnd = ent.AGPSnd or {}
    local on = (ent.AGPKind == "cache" or ent:GetOn()) and not ent:IsDormant() and cvSound:GetBool()
        and LocalPlayer():GetPos():DistToSqr(ent:GetPos()) < 1200 * 1200
    for i, d in ipairs(list) do
        local s = ent.AGPSnd[i]
        if on then
            if not s then
                s = CreateSound(ent, d[1])
                s:SetSoundLevel(62)
                ent.AGPSnd[i] = s
            end
            local fresh = not s:IsPlaying()
            if fresh then s:PlayEx(0, d[3]) end
            if fresh or not ent.AGPSndOn then s:ChangeVolume(d[2], 0.6) end
        elseif s and ent.AGPSndOn then
            s:FadeOut(0.6)
        end
    end
    ent.AGPSndOn = on
end

timer.Create("AGP.Power.Sounds", 0.2, 0, function()
    if not IsValid(LocalPlayer()) then return end
    for ent in pairs(looping) do
        if not IsValid(ent) then looping[ent] = nil
        elseif SOUNDS[ent.AGPKind] then keepLoops(ent, SOUNDS[ent.AGPKind]) end
    end
    for ent in pairs(motors) do
        local m = IsValid(ent) and ent.AGPMotor
        if not m then motors[ent] = nil
        elseif CurTime() - (ent.AGPMotorT or 0) > 0.3 then
            if m:IsPlaying() then m:FadeOut(0.3) end
            motors[ent] = nil
        end
    end
end)
hook.Add("OnEntityCreated", "AGP.Power.Sounds", function(ent)
    timer.Simple(0, function() if IsValid(ent) and ent.IsAGPPower and SOUNDS[ent.AGPKind] then looping[ent] = true end end)
end)

local function motor(ent, moving)
    if moving and cvSound:GetBool() and LocalPlayer():GetPos():DistToSqr(ent:GetPos()) < 900 * 900 then
        if not ent.AGPMotor then ent.AGPMotor = CreateSound(ent, MOTOR); ent.AGPMotor:SetSoundLevel(58) end
        if not ent.AGPMotor:IsPlaying() then ent.AGPMotor:PlayEx(0.25, 130) end
        ent.AGPMotorT = CurTime()
        motors[ent] = true
    end
end

-- particles -----------------------------------------------------------------------------------------------------
local emitter
local function emit(pos, mat)
    if not emitter or not emitter:IsValid() then emitter = ParticleEmitter(pos) end
    emitter:SetPos(pos)
    return emitter:Add(mat, pos)
end

local function waterParticles(ent)
    if (ent.AGPNextFx or 0) > CurTime() then return end
    ent.AGPNextFx = CurTime() + 0.05
    -- water pouring from the outlet pipe on the side
    local out = ent:LocalToWorld(Vector(0, 16, 14))
    local p = emit(out, "effects/splash2")
    if p then
        p:SetVelocity(ent:GetRight() * -math.Rand(40, 70) + VectorRand() * 6)
        p:SetGravity(Vector(0, 0, -400))
        p:SetDieTime(0.8); p:SetStartAlpha(200); p:SetEndAlpha(0)
        p:SetStartSize(math.Rand(1.5, 3)); p:SetEndSize(5)
        p:SetColor(150, 200, 255); p:SetCollide(true); p:SetBounce(0.1)
    end
    -- bubbles drawn in at the intake below
    if math.random() < 0.4 then
        local inl = ent:LocalToWorld(Vector(0, -12, -24))
        local b = emit(inl + VectorRand() * 10, "effects/bubble")
        if b then
            b:SetVelocity((inl - b:GetPos()):GetNormalized() * 30 + Vector(0, 0, 10))
            b:SetDieTime(0.6); b:SetStartAlpha(220); b:SetEndAlpha(0)
            b:SetStartSize(1); b:SetEndSize(0.4)
        end
    end
end

local function airParticles(ent)
    if (ent.AGPNextFx or 0) > CurTime() then return end
    ent.AGPNextFx = CurTime() + 0.08
    for _, y in ipairs({ -7.5, 7.5 }) do
        local intake = ent:LocalToWorld(Vector(0, y, 24))
        local from = intake + VectorRand() * 18 + ent:GetUp() * 14
        local p = emit(from, "particle/particle_smokegrenade")
        if p then
            p:SetVelocity((intake - from) * 1.6)
            p:SetDieTime(0.6); p:SetStartAlpha(0); p:SetEndAlpha(60)
            p:SetStartSize(3); p:SetEndSize(0.5)
            p:SetColor(220, 240, 255)
        end
    end
end

local function scoopParticles(ent, speed)
    if (ent.AGPNextFx or 0) > CurTime() then return end
    ent.AGPNextFx = CurTime() + 0.06
    local mx = ent:OBBMaxs()
    local mouth = ent:LocalToWorld(Vector(mx.x - 1, 0, mx.z - 11.4))
    for _ = 1, 1 + math.floor(speed / 1000) do
        local from = mouth + ent:GetForward() * math.Rand(30, 60) + VectorRand() * 14
        local p = emit(from, "sprites/light_glow02_add")
        if p then
            p:SetVelocity((mouth - from) * 2.2)
            p:SetDieTime(0.45); p:SetStartAlpha(0); p:SetEndAlpha(200)
            p:SetStartSize(2.5); p:SetEndSize(0.5)
            p:SetColor(120, 200, 255)
        end
    end
end

local function riseParticles(ent, pos, col)
    if (ent.AGPNextFx or 0) > CurTime() then return end
    ent.AGPNextFx = CurTime() + 0.12
    local p = emit(pos + VectorRand() * 3, "sprites/light_glow02_add")
    if p then
        p:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(25, 45)))
        p:SetDieTime(1.2); p:SetStartAlpha(220); p:SetEndAlpha(0)
        p:SetStartSize(2.5); p:SetEndSize(0.4)
        p:SetColor(col[1], col[2], col[3])
    end
end

local function splashParticles(ent)
    if (ent.AGPNextFx or 0) > CurTime() then return end
    ent.AGPNextFx = CurTime() + 0.06
    local p = emit(ent:LocalToWorld(Vector(0, 0, 3)) + VectorRand() * Vector(10, 10, 0), "effects/splash2")
    if p then
        p:SetVelocity(Vector(math.Rand(-25, 25), math.Rand(-25, 25), math.Rand(30, 60)))
        p:SetGravity(Vector(0, 0, -300))
        p:SetDieTime(0.7); p:SetStartAlpha(190); p:SetEndAlpha(0)
        p:SetStartSize(1.5); p:SetEndSize(4)
        p:SetColor(160, 210, 255)
    end
end

-- a spinning bone: the speed runs up and slows down (field AGP<name>), returns the angle
local function spin(ent, field, dt, target)
    ent[field .. "S"] = Lerp(math.min(1, dt * 1.5), ent[field .. "S"] or 0, target)
    ent[field] = ((ent[field] or 0) + dt * ent[field .. "S"]) % 360
    return ent[field]
end

-- the animation of one part (every frame it is drawn) ------------------------------------------------------------
function AGP.PowerAnim(ent)
    local k = ent.AGPKind
    local on = ent.GetOn and ent:GetOn()
    local dt = FrameTime()
    local near = LocalPlayer():GetPos():DistToSqr(ent:GetPos()) < 2500 * 2500
    -- glow level for the material proxy: how full (storage) or how busy (machines)
    local fill = 0
    if ent.ParseSummary then
        local _, list = ent.ParseSummary(ent:GetSummary())
        if list[1] and list[1].max > 0 then fill = math.Clamp(list[1].amount / list[1].max, 0, 1) end
    end
    local busy = on and (k ~= "storage" and k ~= "tank" and k ~= "node" and k ~= "display")
    local target = busy and (1.15 + 0.3 * math.sin(CurTime() * 4)) or (0.35 + 0.9 * fill)
    if k == "cache" then target = 1.1 + 0.35 * math.sin(CurTime() * 2.2) end
    ent.AGPGlow = Lerp(math.min(1, dt * 4), ent.AGPGlow or target, target)
    if not near then
        if ent.AGPSnd or ent.AGPMotor then AGP.PowerAnimStop(ent); ent.AGPSnd, ent.AGPMotor = nil, nil end
        return
    end

    if k == "solar" then
        -- aim the panel at the sun (or a fixed tilt where the map has none)
        local sun = util.GetSunInfo and util.GetSunInfo()
        local yaw, pitch = 0, 28
        if sun and sun.direction and sun.direction.z > 0.05 then
            local d = ent:WorldToLocal(ent:GetPos() + sun.direction)
            yaw = math.deg(math.atan2(d.y, d.x))
            pitch = 90 - math.deg(math.asin(math.Clamp(d.z, -1, 1)))
        end
        ent.AGPYaw = ent.AGPYaw or 0
        ent.AGPPitch = ent.AGPPitch or 0
        local dy = math.AngleDifference(yaw, ent.AGPYaw)
        local dp = pitch - ent.AGPPitch
        local step = 20 * dt
        ent.AGPYaw = ent.AGPYaw + math.Clamp(dy, -step, step)
        ent.AGPPitch = ent.AGPPitch + math.Clamp(dp, -step, step)
        motor(ent, math.abs(dy) > 0.5 or math.abs(dp) > 0.5)
        setAng(ent, "panel", Angle(ent.AGPPitch, ent.AGPYaw - 90, 0))   -- bone X = model left
    elseif k == "pump" then
        -- the wheel turns a quarter turn when the valve opens / closes
        local goal = on and 90 or 0
        ent.AGPWheel = ent.AGPWheel or goal
        local d = goal - ent.AGPWheel
        if math.abs(d) > 0.5 then
            if not ent.AGPWheelSound then ent:EmitSound("ambient/machines/floodgate_move_short1.wav", 55, 150, 0.5); ent.AGPWheelSound = true end
            ent.AGPWheel = ent.AGPWheel + math.Clamp(d, -180 * dt, 180 * dt)
        else
            ent.AGPWheelSound = nil
        end
        setAng(ent, "wheel", Angle(0, ent.AGPWheel * 4, 0))
        show(ent, "flow", on)
        loops(ent, on, SOUNDS.pump)
    elseif k == "waterpump" then
        ent.AGPSpin = ((ent.AGPSpin or 0) + dt * (on and 240 or 0)) % 360
        setAng(ent, "rotor", Angle(0, ent.AGPSpin, 0))
        show(ent, "flow", on)
        loops(ent, on, SOUNDS.waterpump)
        if on then waterParticles(ent) end
    elseif k == "compressor" then
        ent.AGPSpin = ((ent.AGPSpin or 0) + dt * (on and 600 or 0)) % 360
        setAng(ent, "fan1", Angle(0, ent.AGPSpin, 0))
        setAng(ent, "fan2", Angle(0, -ent.AGPSpin, 0))
        show(ent, "flow", on)
        loops(ent, on, SOUNDS.compressor)
        if on then airParticles(ent) end
    elseif k == "dispenser" then
        -- the arm swings out for 2 seconds after E, then folds back
        local t = CurTime() - ent:GetNWFloat("agp_arm", -100)
        local out = t < 0.4 and t / 0.4 or (t < 2.2 and 1 or math.max(0, 1 - (t - 2.2) / 0.5))
        if t < 0.05 and not ent.AGPArmSound then ent:EmitSound("ambient/machines/floodgate_move_short1.wav", 55, 170, 0.5); ent.AGPArmSound = true end
        if t > 1 then ent.AGPArmSound = nil end
        setAng(ent, "arm", Angle(0, 0, -70 * math.sin(out * math.pi / 2)))   -- swings out to the front
    elseif k == "heater" then
        loops(ent, on, SOUNDS.heater)
    elseif k == "cooler" then
        -- the fan runs up and slows down instead of starting / stopping at once
        ent.AGPFanSpeed = Lerp(math.min(1, dt * 1.5), ent.AGPFanSpeed or 0, on and 720 or 0)
        ent.AGPSpin = ((ent.AGPSpin or 0) + dt * ent.AGPFanSpeed) % 360
        setAng(ent, "fan", Angle(0, ent.AGPSpin, 0))
        loops(ent, on, SOUNDS.cooler)
    elseif k == "splitter" then
        -- the bubbles climb one spacing (2.2) and start again, so they seem to rise for ever
        local rise = on and (CurTime() * 5) % 2.2 or 0
        for _, b in ipairs({ "bubbles_h", "bubbles_o" }) do
            show(ent, b, on)
            setPos(ent, b, Vector(0, 0, rise))
        end
        loops(ent, on, SOUNDS.splitter)
        if on and math.random() < dt * 1.5 then
            local mx = ent:OBBMaxs()
            local fx = EffectData(); fx:SetOrigin(ent:LocalToWorld(Vector(0, 0, mx.z - 2))); fx:SetMagnitude(1); fx:SetScale(0.3); fx:SetRadius(2)
            util.Effect("ElectricSpark", fx)
        end
    elseif k == "ramscoop" then
        local speed = ent:GetNWFloat("agp_scoop_speed", 0)
        ent.AGPRingSpeed = Lerp(math.min(1, dt * 1.5), ent.AGPRingSpeed or 0, on and (90 + speed * 0.25) or 0)
        ent.AGPSpin = ((ent.AGPSpin or 0) + dt * ent.AGPRingSpeed) % 360
        setAng(ent, "ring", Angle(ent.AGPSpin, 0, 0))   -- the funnel's axis is the bones' Y (the export turns models by 90 degrees): pitch
        loops(ent, on, SOUNDS.ramscoop)
        if on then scoopParticles(ent, speed) end
    elseif k == "fusion" then
        local f = on and 1 or 0.15
        setAng(ent, "ring1", Angle(0, spin(ent, "AGPR1", dt, 70 * f), 0))
        setAng(ent, "ring2", Angle(0, -spin(ent, "AGPR2", dt, 110 * f), 0))
        setAng(ent, "ring3", Angle(0, spin(ent, "AGPR3", dt, 150 * f), 0))
        loops(ent, on, SOUNDS.fusion)
    elseif k == "hydro" then
        setAng(ent, "wheel", Angle(spin(ent, "AGPWheelA", dt, on and 80 or 0), 0, 0))   -- axle along the bones' Y: pitch
        loops(ent, on, SOUNDS.hydro)
        if on then splashParticles(ent) end
    elseif k == "turbine" then
        setAng(ent, "rotor", Angle(spin(ent, "AGPRotorA", dt, on and 540 or 0), 0, 0))
        loops(ent, on, SOUNDS.turbine)
    elseif k == "fuelcell" then
        loops(ent, on, SOUNDS.fuelcell)
    elseif k == "heavywater" then
        setAng(ent, "rotor", Angle(0, spin(ent, "AGPHwxA", dt, on and 420 or 0), 0))   -- centrifuge: yaw
        loops(ent, on, SOUNDS.heavywater)
    elseif k == "probe" then
        setAng(ent, "head", Angle(0, spin(ent, "AGPHeadA", dt, 45), 0))
    elseif k == "terraformer" then
        setAng(ent, "ring", Angle(0, spin(ent, "AGPRingA", dt, on and 60 or 6), 0))
        loops(ent, on, SOUNDS.terraformer)
        if on then riseParticles(ent, ent:LocalToWorld(Vector(0, 0, ent:OBBMaxs().z - 4)), { 120, 255, 160 }) end
    elseif k == "plant" then
        setAng(ent, "arm", Angle(0, spin(ent, "AGPArmA", dt, on and 35 or 0), 0))
        loops(ent, on, SOUNDS.plant)
    elseif k == "gravity" then
        local g = math.max(0.3, ent:GetNWFloat("agp_grav", 1))
        setAng(ent, "ring1", Angle(spin(ent, "AGPG1", dt, on and 55 * g or 0), 0, 0))
        setAng(ent, "ring2", Angle(-spin(ent, "AGPG2", dt, on and 85 * g or 0), 0, 0))
        loops(ent, on, SOUNDS.gravity)
    elseif k == "cache" then
        ent.AGPSpin = ((ent.AGPSpin or 0) + dt * 50) % 360
        setAng(ent, "rings", Angle(math.sin(CurTime() * 0.7) * 12, ent.AGPSpin, math.cos(CurTime() * 0.5) * 10))
        loops(ent, true, SOUNDS.cache)
    end
end

function AGP.PowerAnimStop(ent)
    for _, s in pairs(ent.AGPSnd or {}) do s:Stop() end
    ent.AGPSndOn = nil
    if ent.AGPMotor then ent.AGPMotor:Stop() end
end

-- glow: $selfillumtint follows the part (ent.AGPGlow, set above); 1 for anything else using these materials
matproxy.Add({
    name = "AGPGlow",
    init = function(self, mat, values)
        self.ResultTo = values.resultvar
    end,
    bind = function(self, mat, ent)
        local v = IsValid(ent) and ent.AGPGlow or 1
        mat:SetVector(self.ResultTo, Vector(v, v, v))
    end,
})
