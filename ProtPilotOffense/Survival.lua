-- SPDX-License-Identifier: GPL-3.0-or-later
-- Health readback approach adapted from JustAC 6.2.1, Copyright (C) 2024-2026 wealdly.
-- Modified for Tank Pilot 0.4.0: guarded tri-state results, limited thresholds,
-- readable-value preference, deterministic control-break selection and potion checks.
ProtPilotSurvival = {}
local S = ProtPilotSurvival
local function safe(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v)=='table' and issecrettable and issecrettable(v) then return nil end
    return v
end
local function call(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok then return safe(a),safe(b),safe(c) end
end
function S.Below(threshold)
    local health=call(UnitHealth,'player')
    local maximum=call(UnitHealthMax,'player')
    if type(health)=='number' and type(maximum)=='number' and maximum>0 then
        S.healthStatus='readable'
        return health/maximum<threshold
    end
    S.healthStatus='visual fallback'
end
-- Narrow, deterministic matching. Never select a general immunity as a CC break.
-- Forever racial ID and mechanics from JustAC Data/CCBreakers.lua.
local breaks={
    STUN={1259718}, STUN_MECHANIC={1259718},
    FEAR={7744,18499}, FEAR_MECHANIC={7744,18499},
    SLEEP={7744}, CHARM={7744}, ROOT={20589,1044},
}
function S.Breaker(ready)
    local api=C_LossOfControl
    local count=call(api and api.GetActiveLossOfControlDataCount)
    if type(count)~='number' then S.controlStatus='unknown'; return nil end
    S.controlStatus=count>0 and 'active' or 'none'
    for i=1,math.min(count,20) do
        local data=call(api.GetActiveLossOfControlData,i)
        local kind=data and safe(data.locType)
        if type(kind)=='string' then
            for _,id in ipairs(breaks[kind] or {}) do
                if ready(id) then return id,kind end
            end
        end
    end
end
-- Healing potion subset of JustAC's Forever consumable catalog, strongest first.
local potions={241650,282011,13446,223913,247242,3928,247241,1710,223914,
    287977,247240,929,268883,4596,247239,858,287967,268882,118}
function S.Potion()
    if not C_Item then return nil end
    for _,id in ipairs(potions) do
        local count=call(C_Item.GetItemCount,id,false,false,false)
        local usable=call(C_Item.IsUsableItem,id)
        local start,duration,enabled=call(C_Item.GetItemCooldown,id)
        if type(count)=='number' and count>0 and usable==true and
            type(start)=='number' and type(duration)=='number' and
            (enabled==1 or enabled==true) and start+duration<=GetTime() then
            local name=call(C_Item.GetItemNameByID,id)
            local icon=call(C_Item.GetItemIconByID,id)
            return {id=id,name=name or ('Healing potion '..id),icon=icon or 134829,item=true}
        end
    end
end

-- Prefer the direct movement boolean; fall back to observed movement events.
-- Do not infer stationary from a secret speed or absence of an event.
local movingEvent
function S.MovementEvent(event)
    if event=='PLAYER_STARTED_MOVING' then movingEvent=true
    elseif event=='PLAYER_STOPPED_MOVING' then movingEvent=false
    elseif event=='PLAYER_ENTERING_WORLD' then movingEvent=nil end
end
function S.Stationary()
    local moving=call(IsPlayerMoving)
    if type(moving)=='boolean' then
        S.movementStatus='IsPlayerMoving';return not moving
    end
    local speed=call(GetUnitSpeed,'player')
    if type(speed)=='number' then S.movementStatus='readable speed';return speed==0 end
    if movingEvent~=nil then S.movementStatus='movement events';return not movingEvent end
    S.movementStatus='unknown';return nil
end
