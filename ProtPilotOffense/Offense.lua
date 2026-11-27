-- Tank Pilot 0.6.6. All recommendations require a manual player action.
local spells, class, profile = {}, nil, nil
local needsScan, elapsed = true, 0
local casts, effects, observedCooldowns = {}, {}, {}
local playerAuraCache = {}
local survival=ProtPilotSurvival
local lastReason = "Waiting for player data"
local settings
local catalog=ProtPilotProfiles
local profileKey,isTank,enemyCount="protection",true,1
local byID={}
local bookEntries={}
local cachedBaseCooldowns={}
local profiles = {
    WARRIOR = {label="Protection Warrior", families={
        slam={23922}, revenge={6572}, thunder={6343}, sunder={7386},
        rend={772}, shout={6673}, demo={1160}, block={2565},
        stance={71}, taunt={355}, lastStand={12975}, wall={871},
        victoryRush={402927}, bloodrage={2687}, recklessSwings={1329555}, heroic={78}, cleave={845},
    }},
    PALADIN = {label="Protection Paladin", families={
        holyStrike={679,678,1866,680,2495,5569,10332,10333},
        holyShield={20925}, consecration={26573}, judgement={20271}, swiftJudgement={1310994}, hammerWrath={24275}, holyWrath={2812},
        righteousness={20154,21084,20287,20288,20289,20290,20291,20292,20293},
        fury={1311649}, righteousFury={25780}, devotion={465}, retribution={7294},
        kings={20217}, might={19740}, protection={498,5573}, bulwark={1311015}, layHands={633},
        exorcism={879,5614,5615,10312,10313,10314},
    }},
    DRUID = {label="Bear Druid", families={
        primalBite={407995,1238069,1238070},
        lacerate={414644,1328617,1328616,1235826,1235827},
        enrage={5229}, swipe={779}, maul={6807}, faerie={16857}, roar={99},
        mark={1126}, thorns={467}, bear={5487}, direBear={9634},
        barkskin={22812}, regeneration={22842}, growl={6795},
    }},
}
for _,p in pairs(profiles) do
    p.families.willSurvive={1259718}; p.families.forsaken={7744}
    p.families.escapeArtist={20589}
end
profiles.WARRIOR.families.berserkerRage={18499}
profiles.PALADIN.families.purify={1152}
profiles.PALADIN.families.cleanse={4987}
profiles.PALADIN.families.freedom={1044}
profiles.PALADIN.families.holyLight={635}
profiles.PALADIN.families.flashLight={19750}
if catalog then catalog.Extend(profiles) end
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v)=="table" and issecrettable and issecrettable(v) then return nil end
    return v
end
local function read(fn, ...)
    if type(fn)~="function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return plain(a), plain(b) end
end
local function number(v)
    v=plain(v)
    if type(v)=="number" and v==v then return v end
end
local function say(msg) print("Tank Pilot: "..msg) end
local function init()
    if type(ProtPilotOffenseDB)~="table" then ProtPilotOffenseDB={} end
    settings=ProtPilotOffenseDB
    if settings.sealPolicyVersion~=1 then
        if settings.seal==nil or settings.seal=="righteousness" then settings.seal="auto" end
        settings.sealPolicyVersion=1
    end
    local defaults={targetMode="auto", cooldowns=true, aoe=false, seal="auto", aura="auto", blessing="auto",
        locked=true, scale=1, showNames=true, showReason=true, showTitle=true, health=true, dispelcue=true, experimental=true, potions=true, breaks=true, selfheal=true, visibility="auto", boss=true, reserve=30, mana=20, demo=false, rend=true}
    for k,v in pairs(defaults) do if settings[k]==nil then settings[k]=v end end
    if type(settings.thresholds)~="table" then settings.thresholds={} end
    if type(settings.bossSpells)~="table" then settings.bossSpells={} end
    if type(ProtPilotOffenseBleedImmune)~="table" then ProtPilotOffenseBleedImmune={} end
end
local function scan()
    spells = {}
    bookEntries={}
    local _, token = read(UnitClass, "player")
    class, profile = token, profiles[token]
    if not profile then return end
    if type(ProtPilotCharacterDB)~="table" then ProtPilotCharacterDB={} end
    profileKey=catalog and catalog.Select(class,ProtPilotCharacterDB.profile or "auto") or "protection"
    isTank=not catalog or catalog.IsTank(class,profileKey)
    if catalog then profile.label=catalog.Label(class,profileKey) end
    byID={}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not book or bank == nil or not C_Spell then return end
    local names = {}
    local direct, rankOrder = {}, {}
    for family, ids in pairs(profile.families) do
        for rank, id in ipairs(ids) do
            direct[id] = family
            if #ids > 1 then rankOrder[id] = rank end
            local name = read(C_Spell.GetSpellName, id)
            if not name then
                local info = read(C_Spell.GetSpellInfo, id)
                name = info and plain(info.name)
            end
            if name then names[name] = family end
        end
    end
    local count = read(book.GetNumSpellBookSkillLines) or 0
    for line = 1, count do
        local info = read(book.GetSpellBookSkillLineInfo, line)
        local offset = info and plain(info.itemIndexOffset)
        local slots = info and plain(info.numSpellBookItems)
        if offset and slots then
            for slot = offset + 1, offset + slots do
                local item = read(book.GetSpellBookItemInfo, slot, bank)
                local id = item and plain(item.spellID)
                if id then
                    local spellInfo = read(C_Spell.GetSpellInfo, id)
                    local name = spellInfo and plain(spellInfo.name)
                    local family = direct[id] or (name and names[name])
                    if read(book.IsSpellInSpellBook,id,bank,false)==true or read(IsPlayerSpell,id)==true then
                        bookEntries[id]=name or tostring(id)
                    end
                    if family then
                        -- When available, the book's known-spell check excludes unlearned entries.
                        local known = read(book.IsSpellInSpellBook, id, bank, false)
                        if known == nil then known = read(IsPlayerSpell, id) end
                        if known ~= false then
                            local previous = spells[family]
                            local rank = #profile.families[family] > 1 and (rankOrder[id] or 0) or id
                            if not previous or rank > previous.rank then
                                spells[family] = {id = id, rank = rank, name = name or family,
                                    icon = spellInfo and plain(spellInfo.iconID), family = family}
                            end
                        end
                    end
                end
            end
        end
    end
    if class=="PALADIN" then
        local ranks=profile.families.exorcism
        for i=#ranks,1,-1 do
            local id=ranks[i]
            if read(IsPlayerSpell,id)==true then
                local info=read(C_Spell.GetSpellInfo,id)
                if info and (not spells.exorcism or i>spells.exorcism.rank) then
                    spells.exorcism={id=id,rank=i,name=plain(info.name),icon=plain(info.iconID),family="exorcism"}
                end
                break
            end
        end
    end
    for _,spell in pairs(spells) do
        byID[spell.id]=spell
        local ms=number(read(GetSpellBaseCooldown,spell.id))
        if ms then cachedBaseCooldowns[spell.id]=ms/1000 end
    end
end


-- Read aura existence separately from expiry. Unknown never means missing.
local function readAura(spell, unit)
    if not spell or not C_UnitAuras then return nil end
    if InCombatLockdown() and
        read(C_Secrets and C_Secrets.ShouldSpellAuraBeSecret, spell.id)~=false then return nil end
    local fn=unit=="player" and C_UnitAuras.GetPlayerAuraBySpellID
        or C_UnitAuras.GetAuraDataBySpellName
    if type(fn)~="function" then return nil end
    local ok, value
    if unit=="player" then ok,value=pcall(fn,spell.id)
    else ok,value=pcall(fn,spell.name,unit,"HARMFUL") end
    if not ok then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=="table" and issecrettable and issecrettable(value) then return nil end
    if value==nil and unit=="player" and type(C_UnitAuras.GetAuraDataBySpellName)=="function" then
        ok,value=pcall(C_UnitAuras.GetAuraDataBySpellName,spell.name,"player","HELPFUL")
        if not ok then return nil end
        if issecretvalue and issecretvalue(value) then return nil end
        if type(value)=="table" and issecrettable and issecrettable(value) then return nil end
    end
    if value==nil then return false end
    return true, number(value.expirationTime), number(value.applications)
end
local function aura(spell, unit)
    if not spell then return nil end
    local present,expiration,stacks=readAura(spell,unit)
    if unit~="player" then return present,expiration,stacks end
    if present~=nil then
        playerAuraCache[spell.id]={present=present,expiration=expiration,stacks=stacks}
        return present,expiration,stacks
    end
    local cached=playerAuraCache[spell.id]
    if cached and cached.present and cached.expiration~=nil then
        if cached.expiration==0 or cached.expiration>GetTime() then
            return true,cached.expiration,cached.stacks
        end
    end
    -- A prior absence does not establish absence during restricted combat.
    return nil
end
local function effectKey(family, unit)
    if unit=="player" then return family end
    local guid=read(UnitGUID,"target")
    return guid and family..":"..guid
end
local function due(family, unit, duration, model)
    local spell=spells[family]
    if not spell then return false end
    local key=effectKey(family,unit)
    local simulated=key and model and model.effects[key]
    if simulated then return simulated<=model.time+1 end
    local present, expiration=aura(spell,unit)
    if present==false then return true end
    if present then return expiration and expiration>0 and expiration<=GetTime()+1 or false end
    local applied=key and effects[key]
    return not applied or GetTime() >= applied+duration-1
end
local function active(family)
    local present=aura(spells[family],"player")
    return present==true
end
local function cost(spell)
    local list=read(C_Spell and C_Spell.GetSpellPowerCost,spell.id)
    if type(list)~="table" then return nil end
    local power=read(UnitPowerType,"player")
    for _,entry in ipairs(list) do
        if plain(entry.type)==power then return number(entry.cost) end
    end
    return 0
end
local baseCooldowns={taunt=10,growl=10,block=5,slam=6,revenge=5,thunder=6,
    holyStrike=10,holyShield=10,consecration=8,judgement=10,primalBite=6,faerie=6}
local function expectedCooldown(spell)
    local milliseconds=number(read(GetSpellBaseCooldown,spell.id))
    return observedCooldowns[spell.id] or cachedBaseCooldowns[spell.id] or (milliseconds and milliseconds/1000)
        or baseCooldowns[spell.family]
end
local function cooldown(spell)
    local cd=read(C_Spell and C_Spell.GetSpellCooldown,spell.id)
    if not cd or plain(cd.isEnabled)==false then return nil end
    local activeCD=plain(cd.isActive)
    if activeCD==false or plain(cd.isOnGCD)==true then return 0 end
    local start,duration=number(cd.startTime),number(cd.duration)
    if start and duration then return math.max(0,start+duration-GetTime()) end
    if activeCD==true and casts[spell.id] then
        local expected=expectedCooldown(spell)
        if expected then
            -- A ready flag is still required for "now"; elapsed estimates stay forecasts.
            return math.max(.1,casts[spell.id]+expected-GetTime())
        end
    end
end
local function usable(spell, model, selfSpell)
    if not spell then return false end
    local t=model and model.time or 0
    local castAt=casts[spell.id]
    if castAt and GetTime()-castAt<0.35 and t==0 then return false end
    local available=read(C_Spell and C_Spell.IsSpellUsable,spell.id)
    if available~=true then return false end
    local remaining=cooldown(spell)
    if remaining==nil or remaining>t then return false end
    if model and (model.cooldowns[spell.id] or 0)>t then return false end
    local amount=cost(spell)
    if model and amount and model.power and amount>model.power then return false end
    if not selfSpell and read(C_Spell and C_Spell.IsSpellInRange,spell.id,"target")==false then return false end
    return true
end
local function queued(spell)
    return spell and read((C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell,spell.id)==true
end
local function creatureID()
    local guid=read(UnitGUID,"target")
    return type(guid)=="string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end
local function bleedAllowed()
    local id=creatureID()
    return settings.rend and not (id and ProtPilotOffenseBleedImmune[id])
end
local function selectedSeal()
    if settings.seal=="manual" then return nil end
    if settings.seal=="auto" then
        if isTank and spells.fury and (not spells.righteousness or read(IsInGroup)~=false) then
            return "fury"
        end
        return "righteousness"
    end
    return settings.seal
end
local function selectedBuff(setting, preferred, fallback)
    if setting=="manual" then return nil end
    if setting~="auto" then return setting end
    if active(preferred) then return preferred end
    if active(fallback) then return fallback end
    return spells[preferred] and preferred or fallback
end
local durations={shout=120, demo=30, rend=21, righteousness=30, fury=30,
    righteousFury=1800, devotion=3600, retribution=3600, kings=300, might=300,
    mark=1800, thorns=600, faerie=40, roar=30, lacerate=15, block=5}
local function entry(family, reason)
    return spells[family] and {spell=spells[family], family=family, reason=reason}
end
local function upkeep(family, unit, model)
    if family and due(family,unit,durations[family] or 30,model)
        and usable(spells[family],model,unit=="player") then
        return entry(family,"Maintain "..spells[family].name)
    end
end
local function setup(model, combat)
    if class=="PALADIN" then
        local seal=selectedSeal()
        local result=(isTank and upkeep("righteousFury","player",model)) or (isTank and upkeep(seal,"player",model))
        if result then return result end
        if not combat then
            return upkeep(selectedBuff(settings.aura,"retribution","devotion"),"player",model)
                or upkeep(selectedBuff(settings.blessing,"kings","might"),"player",model)
        end
    elseif class=="WARRIOR" then
        return upkeep("shout","player",model)
    elseif class=="DRUID" and not combat then
        return upkeep("mark","player",model) or upkeep("thorns","player",model)
    end
end
local function formNeeded()
    if not isTank then
        local id,wanted
        if class=="WARRIOR" then id=profileKey=="fury" and 2458 or 2457; wanted=profileKey=="fury" and 19 or 17
        elseif class=="DRUID" and profileKey=="feral" then id=768;wanted=1 end
        local spell=id and byID[id];local form=read(GetShapeshiftFormID)
        if spell and form~=nil and form~=wanted then return spell.family end
        return nil
    end
    if class=="WARRIOR" and spells.stance then
        local form=read(GetShapeshiftFormID)
        if type(form)=="number" and form~=18 then return "stance" end
    elseif class=="DRUID" then
        local form=read(GetShapeshiftFormID)
        if type(form)=="number" then
            if form~=5 and form~=8 then return spells.direBear and "direBear" or "bear" end
        elseif read(UnitPowerType,"player")~=1 then
            return spells.direBear and "direBear" or "bear"
        end
    end
end
local function dumpReady(family, model)
    local spell=spells[family]
    if not spell or queued(spell) or model.swingQueued then return false end
    -- A minimum reserve protects main attacks and mitigation; no assumed Rage income.
    if not model.power then return false end
    local reserve=settings.reserve
    if class=="DRUID" then reserve=settings.aoe and 50 or 35 end
    local amount=cost(spell) or 15
    return model.power>=reserve+amount and usable(spell,model)
end
local function rotation(model)
    if not isTank and catalog then
        return catalog.Choose({class=class,key=profileKey,tank=false,byID=byID,targets=enemyCount,
            settings=settings,aura=aura,cooldown=cooldown,expectedCooldown=expectedCooldown,usable=usable,bleedAllowed=bleedAllowed,
            stationary=function() return survival and survival.Stationary() end},model)
    end
    local result=setup(model,true)
    if result then return result end
    local function choose(family, reason, selfSpell)
        if usable(spells[family],model,selfSpell) then return entry(family,reason) end
    end
    if class=="WARRIOR" and not active("block") then
        local tanking=read(UnitThreatSituation,"player","target")==3
            or read(UnitIsUnit,"targettarget","player")==true
        if tanking then
            result=choose("block","Block incoming melee",true)
            if result then return result end
        end
    end
    local lostThreat=read(UnitThreatSituation,"player","target")
    if lostThreat==0 or lostThreat==1 or lostThreat==2 then
        local taunt=class=="WARRIOR" and "taunt" or class=="DRUID" and "growl"
        if taunt then
            result=choose(taunt,"Recover lost threat")
            if result then return result end
        end
    end
    local rageLow=model.power and model.power<10 and model.time==0
    if class=="WARRIOR" or class=="DRUID" then
        if rageLow and settings.cooldowns then
            local hp=number(read(UnitHealth,"player"))
            local maximum=number(read(UnitHealthMax,"player"))
            if hp and maximum and maximum>0 and hp/maximum>=.8 then
                if class=="WARRIOR" then
                    result=choose("bloodrage","Generate Rage",true) or choose("recklessSwings","Generate Rage from swings",true)
                else
                    result=choose("enrage","Generate Rage",true)
                end
                if result then return result end
            end
        end
    end
    if class=="WARRIOR" then
        if settings.aoe then
            result=choose("thunder","Area threat")
            if result then return result end
        end
        if model.time==0 then
            result=choose("victoryRush","Use available Victory Rush")
            if result then return result end
        end
        result=choose("slam","Primary threat") or choose("revenge","Reactive threat")
        if result then return result end
        result=upkeep("demo","target",model)
        if result then return result end
        -- Sunder builds armor reduction before lower-priority damage fillers.
        local present,_,stacks=aura(spells.sunder,"target")
        if present==false then stacks=0 end
        stacks=model.sunder or stacks
        if stacks and stacks<5 then
            result=choose("sunder","Build armor reduction")
            if result then return result end
        end
        result=choose("thunder","Damage and attack-speed reduction")
        if result then return result end
        if bleedAllowed() then
            result=upkeep("rend","target",model)
            if result then return result end
        end
        -- Dumping is independent of Sunder and of the GCD.
        local dump=settings.aoe and spells.cleave and "cleave" or "heroic"
        if dumpReady(dump,model) then return entry(dump,"Spend surplus Rage") end
        return choose("sunder","Threat filler")
    elseif class=="PALADIN" then
        local seal=selectedSeal()
        local sealActive=seal and not due(seal,"player",30,model)
        if settings.seal=="manual" then
            for _,id in ipairs({1311649,20154,20375,21082,20164,20165,20166}) do
                local learned=catalog.Resolve({byID=byID},id)
                if learned and active(learned.family) then
                    seal=id==1311649 and "fury" or learned.family
                    sealActive=true
                    break
                end
            end
        end
        local recover=seal=="fury" and (lostThreat==0 or lostThreat==1)
        if recover and sealActive and model.time==0 and not model.recovered then
            result=choose("judgement","Recover threat with Fury") or choose("swiftJudgement","Recover threat with Swift Judgement")
            if result then result.recoversThreat=true;return result end
        end
        local consecration=spells.consecration
        local maximum=number(read(UnitPowerMax,"player"))
        local consecrationCost=consecration and cost(consecration)
        local manaAllows=true
        if model.power and maximum and consecrationCost then
            local needed=maximum*settings.mana/100
            for _,family in ipairs({"holyShield","holyStrike","judgement"}) do
                if spells[family] then needed=math.max(needed,cost(spells[family]) or 0) end
            end
            manaAllows=model.power-consecrationCost>=needed
        end
        if manaAllows and settings.aoe then
            result=choose("consecration","Damage and area threat",true)
            if result then return result end
        end
        result=choose("holyShield","Block mitigation",true)
        if result then return result end
        if manaAllows and not settings.aoe then
            result=choose("consecration","Start ground damage while mana allows",true)
            if result then return result end
        end
        if sealActive then
            result=choose("judgement",seal=="fury" and "Threat and taunt (Fury)" or "Seal damage")
            if result then return result end
        end
        if settings.cooldowns and sealActive and (seal~="fury" or read(IsInGroup)==false) then
            result=choose("swiftJudgement","Additional Judgement from active seal")
            if result then return result end
        end
        local offTank=read(UnitIsUnit,"targettarget","player")==false and (lostThreat==0 or lostThreat==1)
        if offTank and survival.Stationary()==true then
            result=choose("hammerWrath","Execute while off-tanking")
            local kind=read(UnitCreatureType,"target")
            if not result and settings.aoe and (kind=="Demon" or kind=="Undead") then
                result=choose("holyWrath","Off-tank area damage")
            end
            if result then return result end
        end
        if catalog.ValidHolyTarget(879) then
            result=choose("exorcism","Exorcism damage and threat")
            if result then return result end
        end
        result=choose("holyStrike","Holy damage and threat")
        if result then return result end
        
    elseif class=="DRUID" then
        if settings.aoe then
            result=choose("swipe","Area damage and threat")
            if result then return result end
        end
        result=upkeep("faerie","target",model) or upkeep("roar","target",model)
        if result then return result end
        if bleedAllowed() then
            local present,expiration=aura(spells.lacerate,"target")
            local key=effectKey("lacerate","target")
            if not (key and model.effects[key]) and present and expiration and expiration>0 and expiration<GetTime()+3 then
                result=choose("lacerate","Refresh expiring bleed")
                if result then return result end
            end
        end
        result=choose("primalBite","Primary damage and threat")
        if result then return result end
        if dumpReady("maul",model) then return entry("maul","Spend surplus Rage") end
        if settings.aoe then
            result=choose("swipe","Area threat")
            if result then return result end
        end
        if bleedAllowed() then
            result=choose("lacerate","Build bleed stacks and threat")
            if result then return result end
        end
        return choose("swipe","Damage filler")
    end
end

-- Simulate successive decisions using only readable costs and cooldowns.
-- Unreadable resource income and future reactive procs are never invented.
local function advance(model, action)
    local spell,family=action.spell,action.family
    if action.recoversThreat then model.recovered=true end
    if spell.item then return end
    if catalog then catalog.Advance(model,action) end
    local amount=cost(spell)
    if model.power and amount then model.power=math.max(0,model.power-amount) end
    if durations[family] then
        local unit=(family=="rend" or family=="demo" or family=="faerie" or family=="roar"
            or family=="lacerate") and "target" or "player"
        local key=effectKey(family,unit)
        if key then model.effects[key]=model.time+durations[family] end
    end
    if family=="sunder" then
        local _,_,current=aura(spells.sunder,"target")
        model.sunder=math.min(5,(model.sunder or current or 0)+1)
    end
    local cd=expectedCooldown(spell) or 0
    if cd<=0 and (family=="consecration" or family=="holyShield") then cd=baseCooldowns[family] end
    if family=="exorcism" and cd<=0 then cd=15 end
    if family=="swiftJudgement" and cd<=0 then cd=60 end
    model.cooldowns[spell.id]=model.time+cd
    if family=="revenge" or family=="victoryRush" then model.cooldowns[spell.id]=math.huge end
    if family=="heroic" or family=="cleave" or family=="maul" then
        model.swingQueued=true
    elseif family~="judgement" and family~="swiftJudgement" and family~="block" then
        local info=read(C_Spell and C_Spell.GetSpellInfo,spell.id)
        local castTime=info and number(info.castTime)
        model.time=model.time+math.max(1.5,(castTime or 0)/1000)
    end
end
local function buildQueue(combat, firstAction, pullTarget)
    local model={time=0,power=number(read(UnitPower,"player")),cooldowns={},effects={}}
    local queue={}
    for i=1,3 do
        local action
        if i==1 and firstAction then action=firstAction
        elseif combat then action=rotation(model)
        else
            action=setup(model,false)
            if not action and i==1 and pullTarget and class=="PALADIN" and isTank
                and catalog.ValidHolyTarget(879) and usable(spells.exorcism,model) then
                action=entry("exorcism","Ranged pull on eligible target")
            end
        end
        if not action and combat then
            for attempt=1,12 do
                local nextTime
                for _,spell in pairs(spells) do
                    local remaining=cooldown(spell)
                    if remaining then
                        local readyAt=math.max(remaining,model.cooldowns[spell.id] or 0)
                        if readyAt>model.time+.001 and readyAt<=30
                            and (not nextTime or readyAt<nextTime) then nextTime=readyAt end
                    end
                end
                if not nextTime then break end
                model.time=nextTime
                action=rotation(model)
                if action then break end
            end
        end
        if not action then break end
        action.delay=model.time
        queue[i]=action
        advance(model,action)
    end
    return queue
end

-- DBM countdown adapter. Production triggers require an explicit spell mapping.
local timers, registered = {}, {}
local function dbmCallback(event,id,...)
    id=plain(id)
    if type(id)~="string" and type(id)~="number" then return end
    if event=="DBM_TimerBegin" or event=="DBM_TimerStart" then
        local label,duration,_,kind,spellID=...
        label,duration,kind,spellID=plain(label),number(duration),plain(kind),plain(spellID)
        local demo=settings.demo and type(label)=="string" and label:match("^%s*Tank Buster%s*$")
        local mapped=(type(spellID)=="number" or type(spellID)=="string") and settings.bossSpells[tonumber(spellID)]
        if duration and duration>0 and (demo or mapped) then
            timers[id]={finish=GetTime()+duration, kind=mapped or "any",demo=demo}
        end
    elseif event=="DBM_TimerStop" then timers[id]=nil
    elseif timers[id] then
        local timer=timers[id]
        if event=="DBM_TimerUpdate" then
            local spent,total=...
            spent,total=number(spent),number(total)
            if spent and total then timer.finish=GetTime()+total-spent end
        elseif event=="DBM_TimerPause" and not timer.paused then
            timer.paused=math.max(0,timer.finish-GetTime())
        elseif event=="DBM_TimerResume" and timer.paused then
            timer.finish=GetTime()+timer.paused
            timer.paused=nil
        end
    end
end
local function registerDBM()
    if not DBM or type(DBM.RegisterCallback)~="function" then return end
    for _,event in ipairs({"DBM_TimerBegin","DBM_TimerStart","DBM_TimerStop",
        "DBM_TimerUpdate","DBM_TimerPause","DBM_TimerResume"}) do
        if not registered[event] then
            local ok,result=pcall(DBM.RegisterCallback,DBM,event,dbmCallback)
            registered[event]=ok and plain(result)~=false
        end
    end
end
local function incoming()
    if not settings.boss then return nil end
    for id,timer in pairs(timers) do
        local remaining=timer.finish-GetTime()
        if remaining < -1 then timers[id]=nil
        elseif not timer.paused and remaining<=2 and remaining>=0 then return timer end
    end
end
local defensiveRules={
    WARRIOR={{"lastStand",0.40},{"wall",0.25}},
    PALADIN={{"bulwark",0.40},{"layHands",0.20},{"protection",0.35}},
    DRUID={{"barkskin",0.50},{"regeneration",0.35}},
}
local defensiveDurations={lastStand=20,wall=10,protection=8,bulwark=12,layHands=1,barkskin=15,regeneration=10}
local function defensiveActive()
    for _,rule in ipairs(defensiveRules[class] or {}) do
        local spell=spells[rule[1]]
        if spell and (active(rule[1]) or
            (casts[spell.id] and GetTime()-casts[spell.id]<defensiveDurations[rule[1]])) then return true end
    end
end
local function defensive()
    if defensiveActive() then return nil end
    for _,rule in ipairs(defensiveRules[class] or {}) do
        local allowed=rule[1]~="protection" or read(IsInGroup)==false
        if allowed and usable(spells[rule[1]],nil,true) then
            return entry(rule[1],rule[1]=="layHands" and "Emergency self heal" or "Low health"),settings.thresholds[rule[1]] or rule[2]
        end
    end
end
local function planned(timer)
    if not timer or defensiveActive() then return nil end
    if class=="DRUID" and timer.kind=="magic" then return nil end
    if timer.demo and class=="PALADIN" and usable(spells.protection,nil,true) then
        return entry("protection","DBM DEMO — incoming hit")
    end
    local options=class=="WARRIOR" and (timer.kind=="physical" and {"block","wall","lastStand"} or {"wall","lastStand"})
        or class=="DRUID" and {"barkskin"}
        or {"bulwark"}
    for _,family in ipairs(options) do
        if not active(family) and usable(spells[family],nil,true) then return entry(family,timer.demo and "DBM DEMO — incoming hit" or "Incoming mapped boss ability") end
    end
end

local function survivalAction(combat)
    if not combat or not survival then return nil end
    if settings.breaks then
        local chosen,kind=survival.Breaker(function(id)
            for _,spell in pairs(spells) do
                if spell.id==id and usable(spell,nil,true) then return true end
            end
        end)
        if chosen then
            for family,spell in pairs(spells) do
                if spell.id==chosen then return entry(family,"Break "..kind),true end
            end
        end
    end
    if not settings.health then return nil end
    if settings.potions and survival.Below(settings.thresholds.potion or .30,settings.experimental)==true then
        local potion=survival.Potion()
        if potion then return {spell=potion,family="potion",reason="Emergency healing potion"},true end
    end
    if not defensiveActive() then
        -- At critical health prefer emergency recovery; otherwise preserve class ordering.
        local rules=defensiveRules[class] or {}
        if class=="PALADIN" then rules={{"layHands",.20},{"bulwark",.40},{"protection",.35}} end
        for _,rule in ipairs(rules) do
            if (rule[1]~="protection" or read(IsInGroup)==false) and usable(spells[rule[1]],nil,true)
                and survival.Below(settings.thresholds[rule[1]] or rule[2],settings.experimental)==true then
                return entry(rule[1],"Low health: "..spells[rule[1]].name),true
            end
        end
    end
    -- Solo cast-time healing only, stationary and not already casting.
    if settings.selfheal and class=="PALADIN" and read(IsInGroup)==false
        and survival.Stationary()==true
        and survival.Below(settings.thresholds.selfheal or .45,settings.experimental)==true then
        local fn=UnitCastingInfo
        if type(fn)=="function" then
            local ok,current=pcall(fn,"player")
            if ok and not (issecretvalue and issecretvalue(current)) and current==nil then
                for _,family in ipairs({"flashLight","holyLight"}) do
                    if usable(spells[family],nil,true) then return entry(family,"Heal yourself (solo)"),true end
                end
            end
        end
    end
end

local frame=CreateFrame("Frame",nil,UIParent)
frame:SetSize(350,124)
frame:SetPoint("CENTER",UIParent,"CENTER",0,-145)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
frame:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local point,_,relativePoint,x,y=self:GetPoint()
    settings.position={point,relativePoint,x,y}
end)
local slots={}
for i=1,3 do
    local holder=CreateFrame("Frame",nil,frame)
    holder:SetSize(i==1 and 60 or 48,i==1 and 60 or 48)
    holder:SetPoint("TOPLEFT",frame,"TOPLEFT",(i-1)*95,0)
    local icon=holder:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(holder)
    icon:SetTexCoord(.08,.92,.08,.92)
    local label=holder:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetPoint("TOP",holder,"BOTTOM",0,-4)
    label:SetWidth(90)
    label:SetHeight(44)
    label:SetJustifyV("TOP")
    slots[i]={holder=holder,icon=icon,label=label}
end
local emergency=CreateFrame("Frame",nil,frame)
emergency:SetAllPoints(slots[1].holder)
local emergencyIcon=emergency:CreateTexture(nil,"OVERLAY")
emergencyIcon:SetAllPoints(emergency)
emergencyIcon:SetTexCoord(.08,.92,.08,.92)
local emergencyLabel=emergency:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
emergencyLabel:SetPoint("TOP",emergency,"BOTTOM",0,-4)
emergencyLabel:SetWidth(90)
emergencyLabel:SetHeight(44)
emergencyLabel:SetJustifyV("TOP")
local title=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
title:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",0,30)
local reason=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
reason:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-2)
reason:SetWidth(280)
reason:SetHeight(36)
reason:SetJustifyH("LEFT")
reason:SetJustifyV("TOP")
local headers={}
for i,slot in ipairs(slots) do
    local heading=slot.holder:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    heading:SetPoint("BOTTOMLEFT",slot.holder,"TOPLEFT",0,7)
    heading:SetText(({"NOW","NEXT","THEN"})[i]);headers[i]=heading
end
local dispelHeading=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dispelHeading:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",290,7);dispelHeading:SetText("DISPEL")
local moveHint=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
moveHint:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-44)
moveHint:SetText("Drag to move. Lock in /ppoff options.")
local curveCache={}
local function curves(threshold)
    if curveCache[threshold] then return curveCache[threshold][1],curveCache[threshold][2] end
    local function make(low,normal)
        local curve=C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0,CreateColor(1,1,1,low))
        curve:AddPoint(threshold-.001,CreateColor(1,1,1,low))
        curve:AddPoint(threshold,CreateColor(1,1,1,normal))
        curve:AddPoint(1,CreateColor(1,1,1,normal))
        return curve
    end
    local low,normal=make(1,0),make(0,1)
    curveCache[threshold]={low,normal}
    return low,normal
end
local function paintEmergency(action,threshold)
    local low,normal=curves(threshold)
    local lowColor=UnitHealthPercent("player",true,low)
    local normalColor=UnitHealthPercent("player",true,normal)
    emergencyIcon:SetTexture(action.spell.icon)
    emergencyLabel:SetText(action.spell.name..(action.family=="layHands" and " (self)" or ""))
    emergency:SetAlpha(select(4,lowColor:GetRGBA()))
    slots[1].holder:SetAlpha(select(4,normalColor:GetRGBA()))
    emergency:Show()
end
local unlocked,preview=false,false
local function update()
    if not settings then init() end
    if needsScan and not InCombatLockdown() then scan(); needsScan=false; registerDBM() end
    if ProtPilotOptions.Register then ProtPilotOptions.Register(ProtPilotSettingsAPI) end
    if not profile then frame:Hide(); return end
    enemyCount=ProtPilotTargets and ProtPilotTargets.Update(settings.targetMode) or (settings.aoe and 4 or 1)
    if ProtPilotTargets then settings.aoe=enemyCount>=2 end
    if survival then survival.Log('targets',tostring(enemyCount)..' | '..(ProtPilotTargets and ProtPilotTargets.source or 'manual')) end
    unlocked=not settings.locked
    frame:EnableMouse(unlocked)
    local size=tonumber(settings.scale) or 1
    frame:SetScale(math.max(.6,math.min(1.6,size)))
    moveHint:SetShown(unlocked)
    title:SetShown(settings.showTitle)
    reason:SetShown(settings.showReason)
    for _,slot in ipairs(slots) do slot.label:SetShown(settings.showNames) end
    emergencyLabel:SetShown(settings.showNames)
    dispelHeading:SetShown(settings.dispelcue and (spells.purify~=nil or spells.cleanse~=nil))
    local combat=InCombatLockdown()
    if survival then
        survival.ProbeAuraAccess()
        survival.Stationary()
        if not combat then survival.CreateDispelCue(frame,spells.cleanse or spells.purify,spells.cleanse~=nil) end
    end
    if not combat then
        for _,spell in pairs(spells) do aura(spell,"player") end
    end
    if class=="PALADIN" then catalog.ObserveHolyTarget() end
    local target=read(UnitCanAttack,"player","target")==true
        and read(UnitIsDeadOrGhost,"target")~=true
    if read(UnitIsDeadOrGhost,"player")==true then frame:Hide(); return end
    local form=formNeeded()
    local timer=incoming()
    local plan=not form and planned(timer)
    if not combat and not (timer and timer.demo) then plan=nil end
    local urgent=survivalAction(combat)
    if survival then
        local dispel=spells.cleanse or spells.purify
        survival.ShowDispelCue(settings.dispelcue and combat and not urgent and usable(dispel,nil,true))
    end
    local queue=buildQueue(combat and target,urgent or plan,not combat and target)
    if combat and not target and not plan and not urgent then queue={} end
    if form and spells[form] and not urgent and (combat or not queue[1]) then
        queue={entry(form,"Tank stance / form required")}
    end
    if not queue[1] and combat and target then
        lastReason="Pool resources / wait for a readable usable ability"
    elseif queue[1] then lastReason=queue[1].reason
    else lastReason="Ready to pull" end
    for i,slot in ipairs(slots) do
        local action=queue[i]
        slot.icon:SetTexture(action and action.spell.icon or 132337)
        local label=action and action.spell.name or (i==1 and "Wait" or "")
        if action and (action.family=="layHands" or action.family=="holyLight" or action.family=="flashLight") then label=label.." (self)" end
        if action and action.delay and action.delay>.05 then
            label=label..string.format("\n~%.1fs",action.delay)
        end
        slot.label:SetText(label)
        slot.holder:SetAlpha(i==1 and 1 or (action and .75 or .25))
    end
    emergency:Hide()
    if preview then
        local action=defensive()
        if action then
            emergencyIcon:SetTexture(action.spell.icon)
            emergencyLabel:SetText(action.spell.name..(action.family=="layHands" and " (self)" or ""))
            emergency:SetAlpha(1); emergency:Show(); slots[1].holder:SetAlpha(0)
        end
    elseif combat and target and not form and not urgent and settings.health then
        local action,threshold=defensive()
        if action and (not survival or survival.Below(threshold,settings.experimental)==nil) then
            local ok=pcall(paintEmergency,action,threshold)
            if not ok then
                emergency:Hide(); slots[1].holder:SetAlpha(1)
                lastReason="Health display unavailable — /ppoff status"
            end
        end
    end
    if survival then
        survival.Log('health source',survival.healthStatus or 'not evaluated')
        survival.Log('movement source',survival.movementStatus or 'unknown')
        survival.Log('next action',queue[1] and queue[1].spell.name or 'Wait')
    end
    title:SetText(profile.label..(settings.aoe and " · AoE" or " · Single").." ("..enemyCount..")".." · Now / Forecast")
    reason:SetText(lastReason)
    if urgent then reason:SetText(lastReason.."; forecast assumes this action succeeds") end
    if settings.visibility=="combat" and not combat and not unlocked and not preview then frame:Hide()
    elseif settings.visibility=="always" or combat and target or queue[1] or unlocked or preview or plan then frame:Show() else frame:Hide() end
end
local function recordCast(id)
    local now=GetTime()
    casts[id]=now
    if catalog then catalog.RecordCast(id) end
    playerAuraCache[id]=nil
    for family,spell in pairs(spells) do
        if spell.id==id then
            local targetEffect=family=="rend" or family=="demo" or family=="roar" or family=="faerie" or family=="lacerate"
            local key=effectKey(family,targetEffect and "target" or "player")
            if key then effects[key]=now end
            local cd=cooldown(spell)
            if cd and cd>1.5 then observedCooldowns[id]=cd end
        end
    end
end
local driver=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","SPELLS_CHANGED","PLAYER_REGEN_ENABLED",
    "TRAIT_CONFIG_UPDATED","PLAYER_TALENT_UPDATE","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_STARTED_MOVING","PLAYER_STOPPED_MOVING","LOSS_OF_CONTROL_ADDED","LOSS_OF_CONTROL_UPDATE","BAG_UPDATE_DELAYED","PLAYER_TARGET_CHANGED","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UPDATE_SHAPESHIFT_FORM","UNIT_AURA"}) do
    pcall(driver.RegisterEvent,driver,event)
end
driver:SetScript("OnEvent",function(_,event,unit,castArg,id,sentID)
    if not settings then init() end
    if event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_ENTERING_WORLD" then catalog.ClearTarget() end
    if survival then survival.MovementEvent(event) end
    if event=="PLAYER_ENTERING_WORLD" or event=="SPELLS_CHANGED" or event=="TRAIT_CONFIG_UPDATED" or event=="PLAYER_TALENT_UPDATE" or event=="UPDATE_SHAPESHIFT_FORM" then needsScan=true end
    if event=="UNIT_SPELLCAST_SENT" and plain(unit)=="player" and spells.exorcism and number(sentID)==spells.exorcism.id then
        catalog.ExorcismSent(castArg,id)
    end
    if event=="UNIT_SPELLCAST_SUCCEEDED" and plain(unit)=="player" then
        id=number(id)
        if spells.exorcism and id==spells.exorcism.id then catalog.ExorcismSucceeded(castArg) end
        if id then recordCast(id); if survival then survival.Log("cast",id) end end
    end
    if event=="PLAYER_ENTERING_WORLD" and type(settings.position)=="table" then
        frame:ClearAllPoints()
        frame:SetPoint(settings.position[1],UIParent,settings.position[2],settings.position[3],settings.position[4])
    end
    update()
end)
driver:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=.1 then elapsed=0; update() end
end)
SLASH_PROTPILOTOFFENSE1="/ppoff"
SlashCmdList.PROTPILOTOFFENSE=function(message)
    if not settings then init() end
    local command=(message or ""):lower():match("^%s*(.-)%s*$")
    local key,value=command:match("^(%a+)%s+(%S+)$")
    if command=="" or command=="options" then ProtPilotOptions.Open(ProtPilotSettingsAPI)
    elseif key=="scale" and tonumber(value) then settings.scale=math.max(.6,math.min(1.6,tonumber(value)/100))
    elseif command=="resetposition" then
        settings.position=nil;settings.scale=1;frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",0,-145)
    elseif command=="single" or command=="aoe" or command=="auto" then settings.targetMode=command; settings.aoe=command=="aoe"
    elseif key=="cooldowns" and (value=="on" or value=="off") then settings.cooldowns=value=="on"
    elseif key=="profile" and catalog then
        for _,choice in ipairs(catalog.Choices(class)) do
            if choice[1]==value then ProtPilotCharacterDB.profile=value;needsScan=true end
        end
    elseif command=="move" or command=="lock" then
        unlocked=command=="move"; settings.locked=not unlocked; frame:EnableMouse(unlocked)
    elseif key=="seal" and (value=="righteousness" or value=="fury" or value=="auto" or value=="manual") then settings.seal=value
    elseif key=="aura" and (value=="auto" or value=="devotion" or value=="retribution" or value=="manual") then settings.aura=value
    elseif key=="blessing" and (value=="auto" or value=="kings" or value=="might" or value=="manual") then settings.blessing=value
    elseif key=="health" or key=="boss" or key=="demo" then
        if value=="on" or value=="off" then settings[key]=value=="on"; timers={} end
    elseif command=="healthtest on" or command=="healthtest off" then
        settings.health=command=="healthtest on"; preview=false
    elseif command=="healthtest preview" then preview=true
    elseif (key=="reserve" or key=="mana") and tonumber(value) and tonumber(value)>=0 and tonumber(value)<=100 then settings[key]=tonumber(value)
    elseif command=="bleed immune" or command=="bleed clear" then
        local id=creatureID()
        if id then ProtPilotOffenseBleedImmune[id]=command=="bleed immune" or nil
        else say("Creature ID unavailable; use /ppoff bleed off.") end
    elseif command=="bleed off" or command=="bleed on" then settings.rend=command=="bleed on"
    elseif command:match("^threshold ") then
        local family,percent=command:match("^threshold (%a+) (%d+)$")
        percent=tonumber(percent)
        local valid=family=="potion" or family=="selfheal"
        for _,rule in ipairs(defensiveRules[class] or {}) do if rule[1]:lower()==family then family=rule[1]; valid=true end end
        if valid and percent and percent>=5 and percent<=95 then
            settings.thresholds[family]=percent/100
            say("Health threshold updated.")
        else say("Use a defensive family shown by /ppoff status and a percentage from 5 to 95.") end
    elseif command:match("^bossmap ") then
        local id,kind=command:match("^bossmap (%d+) (%a+)$")
        if id and (kind=="physical" or kind=="magic" or kind=="any" or kind=="clear") then
            settings.bossSpells[tonumber(id)]=kind~="clear" and kind or nil
            say("Boss mapping updated.")
        end
    elseif key=="dispelcue" or key=="experimental" or key=="potions" or key=="breaks" or key=="selfheal" then
        if value=="on" or value=="off" then settings[key]=value=="on" end
    elseif key=="visibility" and (value=="always" or value=="combat" or value=="auto") then settings.visibility=value
    elseif command=="exorcism allow" or command=="exorcism clear" then
        say(catalog.MarkExorcism(value=="allow"))
    elseif command=="exorcism" then
        local spell=spells.exorcism
        local function field(value) return value==nil and "unknown" or tostring(value) end
        local lines={"Profile "..field(profileKey),"Learned rank ID "..field(spell and spell.id),
            "Target attackable "..field(read(UnitCanAttack,"player","target")),
            "Undead or demon (current target) "..field(catalog.ObserveHolyTarget()),
            "Exorcism target eligible "..field(catalog.ValidHolyTarget(879)),
            "Visibility "..field(settings.visibility),"Current recommendation "..lastReason}
        if spell then
            lines[#lines+1]="Spell usable "..field(read(C_Spell.IsSpellUsable,spell.id))
            lines[#lines+1]="In range "..field(read(C_Spell.IsSpellInRange,spell.id,"target"))
            lines[#lines+1]="Cooldown seconds "..field(cooldown(spell))
            lines[#lines+1]="Cost "..field(cost(spell)).." / power "..field(read(UnitPower,"player"))
        end
        survival.Report(table.concat(lines,"\n"))
    elseif command=="audit" then
        local rows={}
        for id,name in pairs(bookEntries) do
            rows[#rows+1]=string.format("%s (%d) | %s",name,id,byID[id] and "selected spell rank" or "other rank or outside selected spell list")
        end
        table.sort(rows)
        survival.Report("Learned spellbook from latest out-of-combat scan. Compare with TANK-ABILITIES.md for tank rules.\n"..table.concat(rows,"\n"))
    elseif command=="report" then
        survival.Report("Profile="..tostring(profileKey).." | Targets="..enemyCount.." ("..tostring(ProtPilotTargets and ProtPilotTargets.source)..") | Health="..tostring(survival.healthStatus).." | Movement="..tostring(survival.movementStatus).." | Dispel="..tostring(survival.dispelStatus))
    elseif command=="status" or command=="healthtest status" then
        say("Profile="..tostring(profileKey).." | Targets="..enemyCount.." | "..tostring(ProtPilotTargets and ProtPilotTargets.source))
        say("Movement="..tostring(survival.movementStatus).." | Dispel cue="..tostring(survival.dispelStatus))
        say("Survival: health="..tostring(survival and survival.healthStatus).." control="..tostring(survival and survival.controlStatus))
        say("Experimental="..tostring(settings.experimental).." potions="..tostring(settings.potions).." breaks="..tostring(settings.breaks).." selfheal="..tostring(settings.selfheal))
        say("0.6.6 | "..(class or "unknown").." | "..lastReason)
        say("Seal="..settings.seal.." | health="..tostring(settings.health).." | DBM="..tostring(DBM~=nil)
            .." | demo="..tostring(settings.demo))
        for family,spell in pairs(spells) do
            local ok=read(C_Spell and C_Spell.IsSpellUsable,spell.id)
            say(family.." ("..spell.id..") usable="..tostring(ok).." cooldown="..tostring(cooldown(spell)))
        end
    else
        say("/ppoff auto | single | aoe | move | lock | status | report; profile NAME; cooldowns on|off")
        say("/ppoff seal righteousness|fury|auto|manual; aura auto|devotion|retribution|manual")
        say("/ppoff blessing auto|kings|might|manual; health on|off; demo on|off; boss on|off")
        say("/ppoff threshold DEFENSIVE|potion|selfheal PERCENT; experimental|potions|breaks|selfheal on|off; visibility auto|always|combat")
        say("/ppoff bossmap SPELLID physical|magic|any|clear; reserve NUMBER; mana PERCENT; bleed immune|clear|on|off")
    end
    preview=preview and command=="healthtest preview"
    update()
end
frame:Hide()

-- Small interface between settings controls and the recommendation engine.
ProtPilotSettingsAPI={
    get=function(key)
        if not settings then init() end
        if key=="scalePercent" then return math.floor((settings.scale or 1)*100+.5) end
        if key=="potionPercent" then return math.floor((settings.thresholds.potion or .30)*100+.5) end
        if key=="selfhealPercent" then return math.floor((settings.thresholds.selfheal or .45)*100+.5) end
        if key=="profile" then return ProtPilotCharacterDB and ProtPilotCharacterDB.profile or "auto" end
        return settings[key]
    end,
    set=function(key,value)
        if not settings then init() end
        if key=="scalePercent" then settings.scale=math.max(.6,math.min(1.6,value/100))
        elseif key=="potionPercent" then settings.thresholds.potion=math.max(.05,math.min(.95,value/100))
        elseif key=="selfhealPercent" then settings.thresholds.selfheal=math.max(.05,math.min(.95,value/100))
        elseif key=="profile" then
            if not ProtPilotCharacterDB then ProtPilotCharacterDB={} end
            ProtPilotCharacterDB.profile=value;needsScan=true
        else settings[key]=value end
        update()
    end,
    profileChoices=function() return catalog and catalog.Choices(class) or {{"auto","Automatic"}} end,
    resetDisplay=function()
        settings.position=nil;settings.scale=1
        frame:ClearAllPoints();frame:SetPoint("CENTER",UIParent,"CENTER",0,-145);update()
    end,
    report=function() SlashCmdList.PROTPILOTOFFENSE("report") end,
}
