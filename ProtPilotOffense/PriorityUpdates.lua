-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pilot adjustments to the supplied baseline, researched November 14, 2026.
-- See README for sources and limitations. Conditions still require readable evidence.
local T=ProtPilotCatalog.trees
local function e(id,gates) return {id=id,gates=gates or {}} end
local function missing(id) return {t='debuff',id=id,neg=true,refresh=true} end
local function mana(n) return {t='power',res='mana',op='>=',n=n,ispct=true} end
local function targets(n) return {t='targets',op='>=',n=n} end
local function buffMissing(id) return {t='buff',id=id,neg=true} end
-- Source preset had Bloodthirst before Whirlwind. Forever's updated guide reverses them.
for _,list in pairs(T.WARRIOR_F.fury) do
    if type(list)=='table' then
        local insertAt
        for i=#list,1,-1 do if list[i].id==1680 then table.remove(list,i) end end
        for i,item in ipairs(list) do if item.id==5308 or item.id==23881 then insertAt=i;break end end
        if insertAt then table.insert(list,insertAt,e(1680)) end
    end
end
-- Ret keeps a damage seal. No Seal of Fury or Righteous Fury in a DPS profile.
-- Echo swapping needs readable stacks/swing timing and is left manual in this build.
local pal={e(20375,{buffMissing(20375),{t='known',id=20375}}),
    e(20154,{buffMissing(20154),{t='known',id=20375,neg=true}}),
    e(24275),e(26573,{mana(20)}),e(20271),e(679),e(879)}
T.PALADIN_F.retribution.st=pal
T.PALADIN_F.retribution.aoe={e(20375,{buffMissing(20375)}),
    e(20154,{buffMissing(20154),{t='known',id=20375,neg=true}}),
    e(24275),e(2812,{targets(2)}),e(26573,{mana(20)}),e(20271),e(679),e(879)}
-- Elemental multi-target Chain Lightning and Fire Nova do not require Clearcasting.
T.SHAMAN_F.elemental.aoe={e(8190,{{t='totem',slot=1,neg=true}}),e(421),e(408341),e(8050,{missing(8050)}),e(403)}
T.SHAMAN_F.elemental.st[1]=e(3599,{{t='totem',slot=1,neg=true},{t='targets',op='<',n=3}})
T.SHAMAN_F.elemental.cleave=T.SHAMAN_F.elemental.st
-- Fire's source AoE list was identical to ST. Add actual area spells, range-gated at runtime.
T.MAGE_F.fire.aoe={e(11129),e(11113),e(120),e(2120),e(1449),e(401502),e(133)}
for _,list in ipairs({T.MAGE_F.fire.st,T.MAGE_F.fire.cleave}) do
    for i,item in ipairs(list) do if item.id==133 then table.insert(list,i,e(401502));break end end
end
-- Affliction's modern filler is Wrack; keep Shadow Bolt for Nightfall or leveling.
for _,key in ipairs({'st','cleave','aoe'}) do
    local list=T.WARLOCK_F.affliction[key]
    if list then
        for i,item in ipairs(list) do if item.id==686 then
            table.insert(list,i,e(686,{{t='buff',id=17941}}))
            table.insert(list,i+1,e(1316697));break
        end end
    end
end
-- A readable long-lived boss target is required for Doom; no invented time-to-die.
-- Runtime suppresses Doom on ordinary mobs and keeps Agony available.
-- Fix incomplete Warlock Destruction Agony refresh gate (missing numeric n threshold).
for _,key in ipairs({'st','cleave','aoe'}) do
    local list=T.WARLOCK_F and T.WARLOCK_F.destruction and T.WARLOCK_F.destruction[key]
    if list then
        for _,item in ipairs(list) do
            for _,g in ipairs(item.gates or {}) do
                if g.t=='debuff' and g.id==980 and g.op=='<=' and g.n==nil then g.n=3 end
            end
        end
    end
end
