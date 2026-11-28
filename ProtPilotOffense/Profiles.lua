-- SPDX-License-Identifier: GPL-3.0-or-later
-- Forever priority adapter. Data derived from JustAC/MythicSim; see THIRD_PARTY.md.
ProtPilotProfiles={}
local P=ProtPilotProfiles
local D=ProtPilotCatalog
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v)=='table' and issecrettable and issecrettable(v) then return nil end
    return v
end
local function read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c,d,e=pcall(fn,...)
    if ok then return plain(a),plain(b),plain(c),plain(d),plain(e) end
end
local function logDiag(key,value)
    if ProtPilotSurvival and type(ProtPilotSurvival.Log)=='function' then pcall(ProtPilotSurvival.Log,key,value) end
end
local holyCreature, confirmedExorcism, pendingCast
local macroExpires, sentExpires, sentGUID
local rejectInferenceUntil
local nextTooltipCheck=0
local tooltipStatus
local targetSource
local function unlimitedExorcism()
    local learned=read(IsPlayerSpell,415076)
    if learned==nil then learned=read(C_SpellBook and C_SpellBook.IsSpellInSpellBook,415076) end
    return learned
end
local function npcID()
    local id=read(UnitCreatureID,'target')
    if type(id)=='number' and id>0 then return tostring(id) end
    local guid=read(UnitGUID,'target')
    return type(guid)=='string' and guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-') or nil
end
function P.MarkExorcism(allow)
    if read(UnitCanAttack,'player','target')~=true then return 'Select an attackable target.' end
    confirmedExorcism=allow or nil
    local id=npcID()
    if id then
        ProtPilotExorcismNPCs=ProtPilotExorcismNPCs or {}
        ProtPilotExorcismNPCs[id]=confirmedExorcism
    end
    if not allow then return 'Cleared Exorcism confirmation.' end
    return id and 'Exorcism confirmed for this NPC type.' or 'Exorcism confirmed until you change targets.'
end
-- Paired with /cast [@target,harm,nodead] Exorcism on the same button.
function P.ArmTargetExorcism()
    macroExpires=nil
    rejectInferenceUntil=nil
    if read(UnitCanAttack,'player','target')==true then
        macroExpires=GetTime()+1
        logDiag('Exorcism learning','target macro armed')
    end
end
function P.CancelTargetExorcism()
    macroExpires,pendingCast,sentExpires,sentGUID=nil,nil,nil,nil
end
function P.ExorcismSent(destination,castGUID)
    pendingCast=nil
    local name=read(UnitName,'target')
    destination=plain(destination)
    rejectInferenceUntil=nil
    if name and destination and destination~='' and destination~=name then
        macroExpires=nil
        rejectInferenceUntil=GetTime()+8
    end
    sentExpires,sentGUID=nil,nil
    if macroExpires and GetTime()<=macroExpires then
        sentExpires,sentGUID=GetTime()+8,plain(castGUID)
    end
    macroExpires=nil
    if type(name)=='string' and name~='' and destination==name and type(plain(castGUID))=='string' then
        pendingCast=castGUID
    end
end
function P.ExorcismSucceeded(castGUID)
    local pairedMacro=macroExpires and GetTime()<=macroExpires
    local guid=plain(castGUID)
    if sentExpires and GetTime()<=sentExpires and (not sentGUID or not guid or sentGUID==guid) then pairedMacro=true end
    local matchedCast=pendingCast and plain(castGUID)==pendingCast
    P.CancelTargetExorcism()
    if pairedMacro or matchedCast then
        local unrestricted=unlimitedExorcism()
        if unrestricted==false then
            logDiag('Exorcism learning',P.MarkExorcism(true))
        elseif unrestricted==nil then
            confirmedExorcism=true
            logDiag('Exorcism learning','confirmed for current target')
        else
            logDiag('Exorcism learning','target restriction unknown or unrestricted')
        end
    elseif (not rejectInferenceUntil or GetTime()>rejectInferenceUntil)
        and read(UnitCanAttack,'player','target')==true and read(UnitIsDeadOrGhost,'target')~=true then
        -- Destination can be hidden even for a successful @target cast. Keep
        -- this inference on the selection only, never in the saved NPC table.
        confirmedExorcism=true
        logDiag('Exorcism learning','successful cast counted for selected target')
    else
        logDiag('Exorcism learning','no stable attackable target for successful cast')
    end
end
function P.ClearTarget()
    if confirmedExorcism then logDiag('Exorcism learning','current target confirmation cleared on target change or world entry') end
    rejectInferenceUntil=GetTime()+1
    if sentExpires or pendingCast or macroExpires then rejectInferenceUntil=GetTime()+8 end
    P.CancelTargetExorcism()
    holyCreature,confirmedExorcism=nil,nil
    nextTooltipCheck,targetSource,tooltipStatus=0,nil,nil
end
-- Only read ordinary tooltip values. Creature names and flavor text can
-- contain "Undead" too, so only accept a type line or a level/type label.
local function tooltipHolyTarget()
    if not C_TooltipInfo or read(UnitIsPlayer,'target')==true then return false end
    local data=read(C_TooltipInfo.GetUnit,'target')
    local lines=data and plain(data.lines)
    if type(lines)~='table' then return false end
    tooltipStatus='no matching readable type line'
    local previousWasLevel=false
    local types=Enum and Enum.TooltipDataLineType or {}
    for index,line in ipairs(lines) do
        line=plain(line)
        local text=line and plain(line.leftText)
        local levelLine=false
        if index>1 and type(text)=='string' then
            text=text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):match('^%s*(.-)%s*$')
            local kind=plain(line.type)
            levelLine=(kind~=nil and kind==types.UnitLevel) or text:match('^Level%s+[%d?]+%f[%D]') or text:match('^Level%s+[%d?]+$')
            for _,id in ipairs({3,6}) do
                local info=read(C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo,id)
                local label=info and plain(info.name) or (id==3 and 'Demon' or 'Undead')
                if type(label)=='string' and label~='' then
                    if text==label and (previousWasLevel or (kind~=nil and kind==types.UnitType)) then return true end
                    if levelLine and text:sub(-#label-1)==' '..label then return true end
                end
            end
        end
        previousWasLevel=levelLine
    end
    return false
end
-- Snapshot only on request. Never format a secret value.
function P.ExorcismEvidenceReport()
    local function describe(v)
        if issecretvalue and issecretvalue(v) then return '<restricted>' end
        if type(v)=='nil' then return '<absent>' end
        if type(v)=='string' then return v:sub(1,100):gsub('|','||') end
        if type(v)=='number' then return tostring(v) end
        return '<'..type(v)..'>'
    end
    local rows={'Target snapshot | NPC ID '..(npcID() or '<unavailable>')..' | name '..(read(UnitName,'target') or '<unavailable>')}
    local function collect()
        local data=C_TooltipInfo.GetUnit('target')
        if not plain(data) or not plain(data.lines) then
            rows[#rows+1]='Tooltip lines unavailable'
            return
        end
        local count=#data.lines
        rows[#rows+1]='Tooltip lines '..count
        for i=1,math.min(count,12) do
            local line=plain(data.lines[i])
            rows[#rows+1]=line and ('Row '..i..' | type '..describe(line.type)..' | left '..describe(line.leftText)..' | right '..describe(line.rightText)) or ('Row '..i..' unavailable')
        end
    end
    local ok=pcall(collect)
    if not ok then rows[#rows+1]='Tooltip read failed' end
    return table.concat(rows,'\n')
end
function P.ObserveHolyTarget()
    local name,typeID=read(UnitCreatureType,'target')
    if type(typeID)=='number' and typeID>0 then
        holyCreature=typeID==3 or typeID==6
    elseif type(name)=='string' and name~='' then
        holyCreature=name=='Demon' or name=='Undead'
        if not holyCreature then
            for _,id in ipairs({3,6}) do
                local info=read(C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo,id)
                if info and name==plain(info.name) then holyCreature=true;break end
            end
        end
    end
    if type(typeID)=='number' and typeID>0 or type(name)=='string' and name~='' then
        targetSource='creature type'
    elseif holyCreature==nil and GetTime()>=nextTooltipCheck then
        nextTooltipCheck=GetTime()+1
        tooltipStatus='unit tooltip unavailable'
        if read(tooltipHolyTarget) then holyCreature,targetSource=true,'unit tooltip' end
    end
    return holyCreature
end
function P.HolyTargetSource()
    return targetSource or (confirmedExorcism and 'confirmed target') or (ProtPilotExorcismNPCs and ProtPilotExorcismNPCs[npcID()] and 'confirmed NPC') or tooltipStatus or 'unknown'
end
function P.ValidHolyTarget(baseID)
    if baseID==879 and unlimitedExorcism()==true then return true end
    local observed=P.ObserveHolyTarget()
    if observed~=nil then return observed end
    if baseID~=879 then return false end
    return confirmedExorcism==true or (ProtPilotExorcismNPCs and ProtPilotExorcismNPCs[npcID()]==true) or false
end
local labels={beast_mastery='Beast Mastery',marksmanship='Marksmanship',survival='Survival',
    protection='Protection',arms='Arms',fury='Fury',retribution='Retribution',holy='Holy damage',
    balance='Balance',feral='Feral Cat',feral_bear='Bear',restoration='Restoration damage',
    shadow='Shadow',discipline='Discipline damage',arcane='Arcane',fire='Fire',frost='Frost',
    assassination='Assassination',combat='Combat',subtlety='Subtlety',elemental='Elemental',
    enhancement='Enhancement',affliction='Affliction',demonology='Demonology',destruction='Destruction'}
P.burst={[3045]=true,[19574]=true,[12042]=true,[11129]=true,[12043]=true,[13750]=true,
    [13877]=true,[14177]=true,[14183]=true,[14185]=true,[1856]=true,[16166]=true,
    [10060]=true,[12292]=true,[1719]=true,[12328]=true,[20572]=true,[20554]=true,
    [1259821]=true,[1259813]=true,[1259823]=true,[18288]=true}
local extras={HUNTER={19574,3045},MAGE={12042},ROGUE={13877,1943},SHAMAN={16166},
    WARRIOR={12328},PALADIN={20375,879,2812,24275},PRIEST={10060}}
-- Register these as ordinary learned spell families so the same rank,
-- readiness and affordability checks apply to interrupts and attacks.
P.interrupts={WARRIOR={6552,72},ROGUE={1766},MAGE={2139},SHAMAN={8042}}
P.personalGuard={ROGUE=5277,HUNTER=19263,MAGE=11426,PRIEST=19236}
local tanks={WARRIOR='protection',PALADIN='protection',DRUID='feral_bear'}
local treeOrder={WARRIOR={'arms','fury','protection'},PALADIN={'holy','protection','retribution'},
    DRUID={'balance','feral','restoration'},HUNTER={'beast_mastery','marksmanship','survival'},
    MAGE={'arcane','fire','frost'},PRIEST={'discipline','holy','shadow'},ROGUE={'assassination','combat','subtlety'},
    SHAMAN={'elemental','enhancement','restoration'},WARLOCK={'affliction','demonology','destruction'}}
function P.Choices(class)
    local choices={{'auto','Automatic by talents'}}
    for _,key in ipairs(treeOrder[class] or {}) do choices[#choices+1]={key,labels[key]} end
    if class=='DRUID' then choices[#choices+1]={'feral_bear','Bear tank'} end
    return choices
end
function P.Select(class,requested)
    local trees=D.trees[class..'_F']; if not trees then return end
    if requested~='auto' and trees[requested] then return requested end
    local best,points=nil,0
    -- Forever uses trait groups. Classic talent tabs are a compatibility fallback.
    local cfg=read(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    local spec=read(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization)
    local specID=spec and read(C_SpecializationInfo.GetSpecializationInfo,spec)
    local tree=specID and read(C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec,specID)
    local displays=tree and read(C_Traits and C_Traits.GetGroupDisplayInfoByTreeID,tree)
    if cfg and type(displays)=='table' then
        local ids={}
        for _,raw in ipairs(displays) do local d=plain(raw); if d and plain(d.groupID) then ids[#ids+1]=plain(d.groupID) end end
        local infos=read(C_Traits.GetGroupCurrencyInfo,cfg,ids)
        local spent={}
        for _,raw in ipairs(type(infos)=='table' and infos or {}) do
            local gi=plain(raw);local currencies=gi and plain(gi.currencyInfos)
            local c=currencies and plain(currencies[1]);local id=gi and plain(gi.traitNodeGroupID)
            if id and c then spent[id]=plain(c.spentInTree) or plain(c.spent) end
        end
        for _,raw in ipairs(displays) do
            local d=plain(raw);local name=d and plain(d.displayName);local id=d and plain(d.groupID)
            local n=id and spent[id]
            if type(name)=='string' and type(n)=='number' and n>points then
                local slug=name:lower():gsub('[^%a]+','_'):gsub('_$','')
                local first=slug:match('^[^_]+');local key=trees[slug] and slug or trees[first] and first
                if key then best,points=key,n end
            end
        end
    end
    for i,key in ipairs(treeOrder[class] or {}) do
        local _,_,n=read(GetTalentTabInfo,i)
        if type(n)=='number' and n>points then best,points=key,n end
    end
    best=best or tanks[class] or trees.default
    if class=='DRUID' and best=='feral' then
        local form=read(GetShapeshiftFormID)
        if form==5 or form==8 then best='feral_bear' end
    end
    return best
end
function P.IsTank(class,key) return tanks[class]==key end
function P.Label(class,key) return (labels[key] or key or 'Unknown')..' '..class:sub(1,1)..class:sub(2):lower() end
function P.Extend(profiles)
    for classKey,trees in pairs(D.trees) do
        local class=classKey:gsub('_F$','')
        local p=profiles[class] or {families={}}; profiles[class]=p
        local occupied={}
        for family,ids in pairs(p.families) do
            for _,id in ipairs(ids) do occupied[id]=family end
        end
        local function add(id)
            local chain=D.chains[id] or {id};local family=occupied[id]
            for _,rank in ipairs(chain) do family=family or occupied[rank] end
            if not family then family='spell'..id;p.families[family]=chain end
            for _,rank in ipairs(p.families[family]) do occupied[rank]=family end
        end
        for _,id in ipairs(D.classSpells[classKey]) do add(id) end
        for _,id in ipairs(extras[class] or {}) do add(id) end
        if P.personalGuard[class] then add(P.personalGuard[class]) end
        for _,id in ipairs(P.interrupts[class] or {}) do add(id) end
        p.families.willSurvive={1259718};p.families.forsaken={7744};p.families.escapeArtist={20589}
    end
end
local base={};for id,chain in pairs(D.chains) do for _,rank in ipairs(chain) do base[rank]=id end end
function P.Base(id) return base[id] or id end
-- Effect durations are only used for forecasting an action just recommended.
local effectDurations={[772]=21,[6673]=120,[1160]=30,[7386]=30,[1978]=15,[1130]=120,
 [5570]=12,[8921]=12,[1079]=12,[1822]=9,[770]=40,[5171]=6,[1943]=16,[703]=18,
 [8050]=12,[589]=18,[2944]=24,[172]=18,[348]=15,[980]=24,[603]=60,[18265]=30,
 [440892]=120,[2120]=8,[20154]=30,[20375]=30,[1311649]=30,[15473]=3600,[768]=3600,
 [24858]=3600,[11426]=60,[8075]=120,[8190]=60,[3599]=30}
local selfEffects={[6673]=true,[5171]=true,[20154]=true,[20375]=true,[1311649]=true,
 [15473]=true,[768]=true,[24858]=true,[11426]=true}
local recentEffects={}
function P.RecordCast(id)
    id=P.Base(id)
    if not effectDurations[id] then return end
    local unit=selfEffects[id] and 'player' or read(UnitGUID,'target')
    if type(unit)=='string' then recentEffects[unit..':'..id]=GetTime()+effectDurations[id] end
end
local generators={[1752]=1,[53]=1,[399956]=2,[16511]=1,[703]=1,[8676]=1,[1833]=2,
 [1082]=1,[5221]=1,[1822]=1,[6785]=1,[14183]=2}
local finishers={[2098]=true,[1943]=true,[5171]=true,[1316709]=true,[1079]=true,[1328618]=true}
local bleeds={[772]=true,[703]=true,[1943]=true,[1079]=true,[1822]=true,[1328617]=true}
local resourceID={mana=0,rage=1,energy=3,combo_points=4}
local function compare(v,op,n)
    if type(v)~='number' or type(n)~='number' then return nil end
    if op=='<' then return v<n elseif op=='<=' then return v<=n elseif op=='>' then return v>n
    elseif op=='>=' then return v>=n elseif op=='!=' then return v~=n else return v==n end
end
local function invert(v,neg) if v==nil then return nil end;if neg then return not v end;return v end
local function resolve(ctx,id)
    local chain=D.chains[id] or {id}
    for i=#chain,1,-1 do if ctx.byID[chain[i]] then return ctx.byID[chain[i]] end end
end
local gate
local function gates(list,ctx,m,any)
    local unknown=false
    for _,g in ipairs(list or {}) do
        local v=gate(g,ctx,m)
        if any and v==true then return true end
        if not any and v==false then return false end
        if v==nil then unknown=true end
    end
    if unknown then return nil end
    return not any
end
local function auraState(ctx,id,unit,m)
    local key=unit..':'..id
    if m.consumed and m.consumed[key] then return false,0,0 end
    if m.applied and m.applied[key] then
        local remaining=m.applied[key]-m.time
        return remaining>0,math.max(0,remaining),remaining>0 and 1 or 0
    end
    local spell=resolve(ctx,id) or {id=id,name=read(C_Spell.GetSpellName,id)}
    local present,expiration,stacks=ctx.aura(spell,unit)
    local remaining=expiration and (expiration==0 and math.huge or expiration-GetTime()-m.time)
    if present==false then return false,0,0 end
    if present==true and remaining and remaining<=0 then return false,0,0 end
    if present==nil then
        local guid=unit=='player' and 'player' or read(UnitGUID,'target')
        local expiry=type(guid)=='string' and recentEffects[guid..':'..id]
        if expiry and expiry>GetTime()+m.time then return true,expiry-GetTime()-m.time,nil end
    end
    return present,remaining,stacks
end
function gate(g,ctx,m)
    local t=g.t
    if t=='all' or t=='any' then return gates(g.g,ctx,m,t=='any') end
    if t=='targets' then return compare(ctx.targets,g.op,g.n) end
    if t=='known' then
        local v=resolve(ctx,g.id)~=nil
        if not v then v=read(IsPlayerSpell,g.id) end
        return invert(v,g.neg)
    end
    if t=='power' or t=='resource' then
        local id=resourceID[g.res];if id==nil then return nil end
        local value=id==4 and m.combo or id==read(UnitPowerType,'player') and m.power or read(UnitPower,'player',id)
        if g.ispct then local maximum=read(UnitPowerMax,'player',id)
            if type(maximum)~='number' or maximum<=0 or type(value)~='number' then return nil end
            value=value/maximum*100
        end
        return compare(value,g.op,g.n)
    end
    if t=='buff' or t=='debuff' or t=='dot' or t=='stack' then
        local unit=(t=='debuff' or t=='dot' or g.tgt) and 'target' or 'player'
        local present,remaining,stacks=auraState(ctx,g.id,unit,m)
        if t=='stack' then return compare(stacks,g.op,g.n) end
        if g.op then return compare(remaining,g.op,g.n) end
        if t=='dot' or g.refresh then
            if remaining then return remaining<=1 end
            return invert(present,true)
        end
        return invert(present,g.neg)
    end
    if t=='cd' then
        local spell=resolve(ctx,g.id); if not spell then return nil end
        local v=ctx.cooldown(spell)
        if v==nil then return nil end
        return invert(math.max(v,m.cooldowns[spell.id] or 0)<=m.time,g.neg)
    end
    if t=='stealth' then
        if m.brokeStealth then return invert(false,g.neg) end
        return invert(read(IsStealthed),g.neg)
    end
    if t=='totem' then
        if m.totems and m.totems[g.slot] then return invert(true,g.neg) end
        return invert(read(GetTotemInfo,g.slot),g.neg)
    end
    if t=='execute' or t=='health' then
        local unit=t=='execute' and 'target' or 'player'
        local hp,max=read(UnitHealth,unit),read(UnitHealthMax,unit)
        if type(hp)~='number' or type(max)~='number' or max<=0 then return nil end
        return compare(hp/max*100,g.op,g.pct)
    end
    if t=='near' then
        -- A range-checked spell is stronger evidence than nameplate visibility.
        local id=ctx.class=='MAGE' and 120 or ctx.class=='WARLOCK' and 1949
        return id and read(C_Spell.IsSpellInRange,id,'target') or nil
    end
    -- Unsupported timing, unconfirmed proc, or starvation conditions stay unknown.
    return nil
end
local openers={[1833]=true,[703]=true,[8676]=true,[6785]=true}
local positional={[53]=true,[5221]=true}
local longDots={[1978]=true,[589]=true,[2944]=true,[172]=true,[980]=true,[603]=true,
    [1079]=true,[1943]=true,[5570]=true}
local healerTree={restoration=true,holy=true,discipline=true}
local function situational(ctx,m,id,spell)
    if openers[id] and (m.brokeStealth or read(IsStealthed)~=true) then return false end
    if id==1833 and ctx.grouped and not ctx.targetingPlayer and not ctx.boss then return false end
    if id==1833 and ctx.boss then return false end
    if id==5676 and ctx.grouped and ctx.targetingPlayer then return false end
    if id==75 and ctx.key=='survival' and ctx.meleeHunter then return false end
    if id==29166 and ctx.manaFraction and ctx.manaFraction>.35 then return false end
    if (id==12051 or id==1949 or id==15407 or id==5143) and ctx.stationary()==false then return false end
    if positional[id] and ctx.targetingPlayer then return false end
    if ctx.grouped and ctx.targetingPlayer and (P.burst[id] or id==1949 or id==1454) then return false end
    if id==1949 and ctx.targetingPlayer then return false end
    if id==122 and ctx.grouped and not ctx.targetingPlayer then return false end
    if (longDots[id] or id==7386 or id==1130) and ctx.dyingTrash then return false end
    if ctx.healReserve and m.power then
        local amount=ctx.cost(spell)
        if amount and amount>0 and m.power-amount<ctx.healReserve then return false end
    end
    return true
end
function P.Context(ctx)
    ctx.grouped=read(IsInGroup)==true
    ctx.targetingPlayer=read(UnitIsUnit,'targettarget','player')==true
    local hp,maximum=read(UnitHealth,'target'),read(UnitHealthMax,'target')
    local kind=read(UnitClassification,'target')
    ctx.boss=kind=='worldboss' or (read(UnitExists,'boss1')==true and read(UnitIsUnit,'boss1','target')==true)
    if ctx.class=='HUNTER' then
        local melee=resolve(ctx,2973)
        ctx.meleeHunter=melee and read(C_Spell.IsSpellInRange,melee.id,'target')==true
    elseif ctx.class=='DRUID' then
        local mana,cap=read(UnitPower,'player',0),read(UnitPowerMax,'player',0)
        if type(mana)=='number' and type(cap)=='number' and cap>0 then ctx.manaFraction=mana/cap end
    end
    ctx.dyingTrash=(kind=='normal' or kind=='minus') and type(hp)=='number' and
        type(maximum)=='number' and maximum>0 and hp<=maximum*.2
    if ctx.grouped and healerTree[ctx.key] and read(UnitGroupRolesAssigned,'player')=='HEALER' then
        local mana=read(UnitPowerMax,'player',0)
        if type(mana)=='number' then ctx.healReserve=mana*ctx.settings.mana/100 end
    end
    return ctx
end
local function candidate(ctx,m,e)
    local spell=resolve(ctx,e.id);if not spell then return end
    local id=P.Base(spell.id)
    if not situational(ctx,m,id,spell) then return end
    if P.burst[id] and not ctx.settings.cooldowns then return end
    if (id==8042 or id==8050 or id==8056) and m.shockUntil and m.shockUntil>m.time then return end
    -- Never repeat an unknown cooldown in the same forecast. Verified zero-CD fillers can repeat.
    local fillers={[133]=true,[116]=true,[401502]=true,[400574]=true,[686]=true,[1316697]=true,
        [585]=true,[15407]=true,[5176]=true,[2912]=true,[403]=true,[1752]=true,[53]=true,
        [399956]=true,[16511]=true,[1082]=true,[5221]=true,[1449]=true}
    if m.used and m.used[id] and not fillers[id] and ctx.expectedCooldown(spell)==nil then return end
    if generators[id] and type(m.combo)=='number' and m.combo>=5 then return end
    if id==603 and not ctx.boss then return end
    if id==24275 then
        -- Usability is the game's execute gate; it is already checked below.
        if m.used and m.used[id] then return end
    end
    if id==20271 and ctx.class=='PALADIN' then
        local sealed=auraState(ctx,20154,'player',m)==true or auraState(ctx,20375,'player',m)==true
        if not sealed then return end
    end
    if (id==20154 or id==20375 or id==1311649) and ctx.class=='PALADIN' then
        if ctx.settings.seal=='manual' then return end
        if ctx.settings.seal=='righteousness' and id~=20154 then return end
    end
    if (id==1329555 or id==2687) and (type(m.power)~='number' or m.power>60) then return end
    if (id==12328 or id==1719) and read(UnitThreatSituation,'player','target')==3 then return end
    if id==19574 and (read(UnitExists,'pet')~=true or read(UnitIsDeadOrGhost,'pet')==true) then return end
    if id==768 and read(GetShapeshiftFormID)==1 then return end
    if id==2457 and read(GetShapeshiftFormID)==17 then return end
    if id==2458 and read(GetShapeshiftFormID)==19 then return end
    if effectDurations[id] and id~=7386 and id~=8075 and id~=8190 and id~=3599 then
        local present,remaining=auraState(ctx,id,selfEffects[id] and 'player' or 'target',m)
        if present==true and (remaining==nil or remaining>1) then return end
    end
    if m.used and m.used[id] and (P.burst[id] or e.delegated or e.w or id==75 or id==5019) then return end
    if bleeds[id] and not ctx.bleedAllowed() then return end
    if id==1856 or id==14185 then return end -- leave threat drops/reset planning manual
    if id==11426 and auraState(ctx,id,'player',m)~=false then return end
    if (id==75 or id==5019) and read(C_Spell.IsCurrentSpell or IsCurrentSpell,spell.id)==true then return end
    if id==879 or id==2812 then
        if not P.ValidHolyTarget(id) then return end
    end
    if id==1329555 or id==2687 or id==12328 or id==1719 then
        local hp,max=read(UnitHealth,'player'),read(UnitHealthMax,'player')
        if type(hp)~='number' or type(max)~='number' or hp<max*.7 then return end
        if ctx.tank and (id==12328 or id==1719) then return end
    end
    if id==2973 or id==1495 then
        if read(C_Spell.IsSpellInRange,spell.id,'target')~=true then return end
    end
    if id==120 or id==1949 or id==11113 or id==1449 then
        local inRange=read(C_Spell.IsSpellInRange,spell.id,'target')
        if inRange==nil then inRange=read(CheckInteractDistance,'target',3) end
        if inRange~=true then return end
    end
    if finishers[id] and (type(m.combo)~='number' or m.combo<1) then return end
    if (id==78 or id==845) and (m.swingQueued or type(m.power)~='number' or m.power<ctx.settings.reserve+15) then return end
    if gates(e.gates,ctx,m,false)~=true then return end
    if m.time>0 and e.delegated and not fillers[id] then return end
    if not ctx.usable(spell,m,P.burst[id] or selfEffects[id]) then return end
    local info=read(C_Spell.GetSpellInfo,spell.id)
    local castMS=info and plain(info.castTime)
    if type(castMS)=='number' and castMS>0 and ctx.stationary()==false then return end
    return {spell=spell,family=spell.family,baseID=id,catalogEntry=e,
        reason=P.burst[id] and 'Offensive cooldown' or 'Damage priority: '..spell.name}
end
function P.Choose(ctx,m)
    m.combo=m.combo or read(GetComboPoints,'player','target') or read(UnitPower,'player',4)
    local tree=D.trees[ctx.class..'_F'][ctx.key]
    local list=ctx.targets>=3 and (tree.aoe or tree.cleave or tree.st)
        or ctx.targets>=2 and (tree.cleave or tree.aoe or tree.st) or tree.st
    -- Additional cooldowns omitted by the source simulator's automatic cooldown manager.
    local cds={HUNTER={{id=19574,gates={}},{id=3045,gates={}}},
        MAGE=ctx.key=='arcane' and {{id=12042,gates={{t='power',res='mana',op='>=',n=40,ispct=true}}}} or {},
        ROGUE={{id=13877,gates={{t='targets',op='>=',n=2}}}},SHAMAN={{id=16166,gates={}}},
        WARRIOR={{id=12328,gates={{t='power',res='rage',op='>=',n=40}}}}}
    if ctx.class=='PRIEST' and ctx.key=='shadow' then
        local a=candidate(ctx,m,{id=15473,gates={{t='buff',id=15473,neg=true}}});if a then return a end
    elseif ctx.class=='DRUID' and ctx.key=='balance' then
        local a=candidate(ctx,m,{id=24858,gates={{t='buff',id=24858,neg=true}}});if a then return a end
    end
    if InCombatLockdown() then
        for _,e in ipairs(cds[ctx.class] or {}) do local a=candidate(ctx,m,e);if a then return a end end
    end
    if ctx.class=='PALADIN' and ctx.settings.seal=='righteousness' then
        local a=candidate(ctx,m,{id=20154,gates={{t='buff',id=20154,neg=true}}});if a then return a end
    end
    for _,e in ipairs(list or {}) do local a=candidate(ctx,m,e);if a then return a end end
    -- Learned leveling fillers when a level-cap APL assumes unavailable spells/talents.
    local fallback={MAGE={133,116},WARLOCK={686},PRIEST={585},DRUID=ctx.key=='balance' and {5176} or {},
        HUNTER=ctx.key=='survival' and {2973,3044} or {3044},SHAMAN={403},ROGUE={1752}}
    for _,id in ipairs(fallback[ctx.class] or {}) do local a=candidate(ctx,m,{id=id,gates={}});if a then return a end end
end
function P.Advance(m,action)
    local id=action.baseID or P.Base(action.spell.id)
    m.used=m.used or {};m.used[id]=true
    if action.catalogEntry then
        local proc=id==686 and 17941 or id==5143 and 44404
        if proc then
            m.consumed=m.consumed or {}
            m.consumed['player:'..proc]=true
        end
        if openers[id] or generators[id] and id~=14183 then m.brokeStealth=true end
        if finishers[id] then m.combo=0 elseif generators[id] and m.combo then m.combo=math.min(5,m.combo+generators[id]) end
        if id==5308 then m.power=0 end
        local duration=effectDurations[id]
        if duration then
            m.applied=m.applied or {};m.applied[(selfEffects[id] and 'player:' or 'target:')..id]=m.time+duration
        end
        for _,g in ipairs(action.catalogEntry.gates or {}) do
            if g.t=='totem' then m.totems=m.totems or {};m.totems[g.slot]=true end
        end
        -- Shared shock cooldown, including subsequent ranks.
        if id==8042 or id==8050 or id==8056 then
            m.shockUntil=m.time+6
        end
    end
end
P.Resolve=resolve
P.Gate=gate
