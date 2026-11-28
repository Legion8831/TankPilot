-- SPDX-License-Identifier: GPL-3.0-or-later
-- Adapted from JustAC GetEngagedEnemyCount, Copyright (C) 2024-2026 wealdly.
-- Counts engaged enemies, not every visible or neutral creature. No CVars changed.
ProtPilotTargets={count=1,source='not scanned'}
local T=ProtPilotTargets
local function read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,v=pcall(fn,...)
    if not ok or (issecretvalue and issecretvalue(v)) or (type(v)=='table' and issecrettable and issecrettable(v)) then return nil end
    return v
end
function T.Update(mode)
    if mode=='single' then T.count=1;T.source='manual single';return 1 end
    if mode=='aoe' then T.count=4;T.source='manual AoE';return 4 end
    local now=GetTime()
    if T.at and now-T.at<.25 and T.mode==mode then return T.count end
    T.at=now;T.mode=mode
    local count,unknown,targetSeen,identityUnknown=0,false,false,false
    for i=1,40 do
        local unit='nameplate'..i
        local exists=read(UnitExists,unit)
        if exists==nil then unknown=true end
        if exists==true and read(UnitCanAttack,'player',unit)==true and read(UnitIsDeadOrGhost,unit)~=true then
            local threat=read(UnitThreatSituation,'player',unit)
            if type(threat)=='number' then
                count=count+1
                local same=read(UnitIsUnit,unit,'target')
                if same==true then targetSeen=true elseif same==nil then identityUnknown=true end
            elseif read(UnitAffectingCombat,unit)==true then
                -- Combat alone does not prove this mob belongs to our pull.
                unknown=true
            end
        end
    end
    if count>0 and not targetSeen and not identityUnknown
        and read(UnitCanAttack,'player','target')==true and read(UnitIsDeadOrGhost,'target')==false
        and type(read(UnitThreatSituation,'player','target'))=='number' then
        count=count+1
    end
    if not targetSeen and count==0 and read(UnitCanAttack,'player','target')==true then count=1 end
    -- Delay a downgrade briefly to avoid flicker when nameplates churn.
    if count<T.count and T.source=='engaged nameplates' and T.lastHigher and now-T.lastHigher<.6 then return T.count end
    T.lastHigher=now
    T.count=math.max(1,count)
    T.source=count>1 and 'engaged nameplates' or unknown and 'limited visibility / single fallback' or 'engaged nameplates'
    return T.count
end
