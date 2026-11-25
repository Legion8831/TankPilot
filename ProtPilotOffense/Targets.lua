-- SPDX-License-Identifier: GPL-3.0-or-later
-- Adapted from JustAC GetEngagedEnemyCount, Copyright (C) 2024-2026 wealdly.
-- Counts engaged enemies, not every visible or neutral creature. No CVars changed.
ProtPilotTargets={count=1,source='not scanned'}
local T=ProtPilotTargets
local function read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,v=pcall(fn,...)
    if not ok or issecretvalue and issecretvalue(v) then return nil end
    return v
end
function T.Update(mode)
    if mode=='single' then T.count=1;T.source='manual single';return 1 end
    if mode=='aoe' then T.count=4;T.source='manual AoE';return 4 end
    local now=GetTime()
    if T.at and now-T.at<.25 and T.mode==mode then return T.count end
    T.at=now;T.mode=mode
    local count,unknown,targetSeen=0,false,false
    for i=1,40 do
        local unit='nameplate'..i
        local exists=read(UnitExists,unit)
        if exists==nil then unknown=true end
        if exists==true and read(UnitCanAttack,'player',unit)==true and read(UnitIsDeadOrGhost,unit)~=true then
            local threat=read(UnitThreatSituation,'player',unit)
            if type(threat)=='number' then
                count=count+1
                if read(UnitIsUnit,unit,'target')==true then targetSeen=true end
            elseif read(UnitAffectingCombat,unit)==true then
                -- Combat alone does not prove this mob belongs to our pull.
                unknown=true
            end
        end
    end
    if not targetSeen and count==0 and read(UnitCanAttack,'player','target')==true then count=1 end
    -- Delay a downgrade briefly to avoid flicker when nameplates churn.
    if count<T.count and T.source=='engaged nameplates' and T.lastHigher and now-T.lastHigher<.6 then return T.count end
    if count>=T.count or T.source~='engaged nameplates' then T.lastHigher=now end
    T.count=math.max(1,count)
    T.source=count>1 and 'engaged nameplates' or unknown and 'limited visibility / single fallback' or 'engaged nameplates'
    return T.count
end
