-- Pure movement/combo helpers, shared by server physics and client presentation.
local Motion = {}
function Motion.Approach(value, target, sharpness, dt)
    return target + (value - target) * math.exp(-sharpness * math.max(0, dt))
end
function Motion.CanSlide(now, readyAt, alive, grounded, sprinting, speed, config)
    return alive and grounded and sprinting and now >= readyAt and speed >= config.SlideMinSpeed
end
function Motion.SlideEntrySpeed(speed,config)
    return math.min(config.SlideMaxSpeed,math.max(config.SlideSpeed,speed+config.SlideBoost))
end
function Motion.SlideSpeed(elapsed, config, entrySpeed)
    local start=entrySpeed or config.SlideSpeed
    return config.SlideEndSpeed+(start-config.SlideEndSpeed)*math.exp(-config.SlideFriction*math.max(0,elapsed))
end
function Motion.Combo(previousTime, previousCount, now, window)
    return now - previousTime <= window and previousCount + 1 or 1
end
return Motion
