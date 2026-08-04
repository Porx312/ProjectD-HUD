--[[ Battle gap indicator — smooth interpolation between poll snapshots. ]]

local gap_anim = {}

local SMOOTH_HZ = 12
local METERS_SMOOTH_HZ = 14
local PULSE_VEL_THRESHOLD = 0.35

local anim = {
    display_ratio = 0,
    display_signed = 0,
    display_meters = 0,
    target_ratio = 0,
    target_signed = 0,
    target_meters = 0,
    velocity = 0,
    battle_id = "",
    pulse = 0,
}

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function gap_anim.reset()
    anim.display_ratio = 0
    anim.display_signed = 0
    anim.display_meters = 0
    anim.target_ratio = 0
    anim.target_signed = 0
    anim.target_meters = 0
    anim.velocity = 0
    anim.battle_id = ""
    anim.pulse = 0
end

function gap_anim.set_battle_id(battle_id)
    battle_id = tostring(battle_id or "")
    if battle_id == anim.battle_id then return end
    anim.battle_id = battle_id
    anim.display_ratio = 0
    anim.display_signed = 0
    anim.display_meters = 0
    anim.velocity = 0
    anim.pulse = 0
end

function gap_anim.set_target(signed, max_m, opponent_ahead, gap_m)
    max_m = math.max(1, tonumber(max_m) or 250)
    local abs_m = math.max(0, tonumber(gap_m))
    if abs_m <= 0 then
        abs_m = math.abs(tonumber(signed) or 0)
    end
    anim.target_meters = abs_m
    local ratio = clamp(abs_m / max_m, 0, 1)

    if opponent_ahead == nil then
        anim.target_ratio = ratio
        anim.target_signed = 0
        return
    end

    local sign = opponent_ahead and -1 or 1
    if signed ~= nil and signed ~= 0 then
        sign = signed > 0 and 1 or -1
    end
    anim.target_ratio = ratio
    anim.target_signed = ratio * sign
end

function gap_anim.tick(dt, signed, max_m, opponent_ahead, battle_id, gap_m)
    dt = math.max(0, tonumber(dt) or 0)
    gap_anim.set_battle_id(battle_id)
    gap_anim.set_target(signed, max_m, opponent_ahead, gap_m)

    local prev = anim.display_signed
    if dt > 0 then
        local alpha = 1 - math.exp(-dt * SMOOTH_HZ)
        anim.display_signed = anim.display_signed + (anim.target_signed - anim.display_signed) * alpha
        local meters_alpha = 1 - math.exp(-dt * METERS_SMOOTH_HZ)
        anim.display_meters = anim.display_meters + (anim.target_meters - anim.display_meters) * meters_alpha
    else
        anim.display_signed = anim.target_signed
        anim.display_meters = anim.target_meters
    end
    anim.display_ratio = math.abs(anim.display_signed)

    if dt > 0 then
        anim.velocity = (anim.display_signed - prev) / dt
    else
        anim.velocity = 0
    end

    local vel_abs = math.abs(anim.velocity)
    if vel_abs > PULSE_VEL_THRESHOLD then
        anim.pulse = math.min(1, anim.pulse + dt * 4)
    else
        anim.pulse = math.max(0, anim.pulse - dt * 3)
    end

    local closing = anim.velocity * anim.display_signed < 0
    return {
        display_ratio = anim.display_ratio,
        display_signed = anim.display_signed,
        display_meters = anim.display_meters,
        velocity = anim.velocity,
        pulse = anim.pulse,
        closing = closing,
        target_signed = anim.target_signed,
    }
end

return gap_anim
