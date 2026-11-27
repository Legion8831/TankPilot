unpack=table.unpack
local frames,textures,handlers={}, {}, {}
local methods={}
function methods:SetScript(k,v) self[k]=v end
function methods:CreateTexture()
    local t=setmetatable({}, {__index=methods}); textures[#textures+1]=t; return t
end
local hotkeys={}
function methods:CreateFontString(_,_,template)
 local font=setmetatable({}, {__index=methods})
 if template=="NumberFontNormal" then hotkeys[#hotkeys+1]=font end
 return font
end
function methods:SetText(v) self.text=v end
function methods:SetTexture(v) self.texture=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:GetPoint() return "CENTER",nil,"CENTER",0,-145 end
setmetatable(methods,{__index=function() return function() end end})
function CreateFrame() local f=setmetatable({}, {__index=methods}); frames[#frames+1]=f; return f end
UIParent={}; SlashCmdList={}
local combat,clock,class,power=false,0,"PALADIN",100
local learned,cd,unusable={}, {}, {}
local messages={}
print=function(t) messages[#messages+1]=t end
local marker=setmetatable({}, {__tostring=function() error("secret leaked") end})
issecretvalue=function(v) return rawequal(v,marker) end
issecrettable=function() return false end
Enum={SpellBookSpellBank={Player=0},LuaCurveType={Linear=0}}
GetTime=function() return clock end
InCombatLockdown=function() return combat end
UnitClass=function() return class,class end
UnitPower=function() return power end
UnitPowerType=function() return class=="PALADIN" and 0 or 1 end
UnitGUID=function() return "Creature-0-0-0-0-123-0" end
UnitCanAttack=function() return true end
UnitIsDeadOrGhost=function() return false end
UnitThreatSituation=function() return 3 end
UnitIsUnit=function() return true end
IsInGroup=function() return false end
local names={[20154]="Righteousness",[20271]="Judgement",[679]="Holy Strike",
 [1311649]="Fury",[2565]="Shield Block",[498]="Divine Protection"}
local costs={[20154]=10,[20271]=10,[679]=10,[6807]=15}
C_Spell={
 GetSpellInfo=function(id) return {name=names[id] or "Spell"..id,iconID=id} end,
 IsSpellUsable=function(id) return not unusable[id],false end,
 GetSpellCooldown=function(id)
    return {isActive=cd[id] or false,isEnabled=true,startTime=marker,duration=marker}
 end,
 GetSpellPowerCost=function(id) return {{type=class=="PALADIN" and 0 or 1,cost=costs[id] or 0}} end,
 IsCurrentSpell=function() return false end,
}
C_SpellBook={
 GetNumSpellBookSkillLines=function() return 1 end,
 GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=#learned} end,
 GetSpellBookItemInfo=function(i) return {spellID=learned[i]} end,
 IsSpellInSpellBook=function() return true end,
}
local callbacks={}
DBM={RegisterCallback=function(_,event,callback) assert(not callbacks[event]); callbacks[event]=callback end}
local hp=.2
CreateColor=function(r,g,b,a) return {GetRGBA=function() return r,g,b,a end} end
C_CurveUtil={CreateColorCurve=function()
 local curve={points={}}
 function curve:SetType() end
 function curve:AddPoint(x,color) self.points[#self.points+1]={x,color} end
 return curve
end}
UnitHealthPercent=function(_,_,curve)
 local point=curve.points[1]
 for _,p in ipairs(curve.points) do if hp>=p[1] then point=p end end
 return point[2]
end
dofile("ProtPilotOffense/Survival.lua")
dofile("ProtPilotOffense/Diagnostics.lua")
dofile("ProtPilotOffense/DispelCue.lua")
dofile("ProtPilotOffense/Options.lua")
dofile("ProtPilotOffense/ForeverData.lua")
dofile("ProtPilotOffense/PriorityUpdates.lua")
dofile("ProtPilotOffense/Profiles.lua")
dofile("ProtPilotOffense/Targets.lua")
dofile("ProtPilotOffense/Offense.lua")
local driver=frames[#frames]
local function tick() driver.OnUpdate(driver,.1) end
local function event(...) driver.OnEvent(driver,...) end
local function fresh(c,ids)
 combat=false; class=c; learned=ids; cd={}; unusable={}; clock=clock+100
 event("PLAYER_ENTERING_WORLD"); combat=true; tick()
end
local function cast(id) event("UNIT_SPELLCAST_SUCCEEDED","player",marker,id); clock=clock+1; tick() end
local function cmd(v) SlashCmdList.PROTPILOTOFFENSE(v) end
-- Paladin level-independent seal, repeatable forecasts, cast tracking.
fresh("PALADIN",{20154,20271,679,498})
assert(textures[1].texture==20154)
cast(20154)
assert(textures[1].texture==20271)
assert(textures[2].texture==679)
assert(ProtPilotOffenseDB.health==true)
assert(textures[4].texture==498 and frames[5].shown)
assert(frames[2].alpha==0, "low health masks underlying slot")
hp=1; tick(); assert(frames[2].alpha==1)
cd[498]=true; hp=.1; tick(); assert(not frames[5].shown)
-- Known cooldown becoming secret cannot be treated as ready.
cd[498]=marker; tick(); assert(not frames[5].shown)
-- Learned Fury is maintained without a level ban, manual choice persists.
fresh("PALADIN",{1311649,20271,679})
cmd("seal fury"); assert(textures[1].texture==1311649)
cast(1311649); assert(textures[1].texture==20271)
-- Demo callback, exact label with trailing spaces, threshold and stop.
fresh("PALADIN",{20154,679,498})
cast(20154)
cmd("demo on")
callbacks.DBM_TimerBegin("DBM_TimerBegin","test","Tank Buster      ",32,nil,"next",nil)
clock=clock+29; tick(); assert(textures[1].texture~=498)
clock=clock+1.2; tick(); assert(textures[1].texture==498)
callbacks.DBM_TimerStop("DBM_TimerStop","test"); tick(); assert(textures[1].texture~=498)
callbacks.DBM_TimerBegin("DBM_TimerBegin","secret",marker,marker,nil,"next",marker)
-- Timer pause/resume and unmapped bars ignored.
callbacks.DBM_TimerBegin("DBM_TimerBegin","test","Tank Buster",2,nil,"next",nil)
callbacks.DBM_TimerPause("DBM_TimerPause","test"); tick(); assert(textures[1].texture~=498)
callbacks.DBM_TimerResume("DBM_TimerResume","test"); tick(); assert(textures[1].texture==498)
cmd("demo off")
-- Sunder can repeat and remains available with queued swings, Clap in single target.
fresh("WARRIOR",{7386})
assert(textures[1].texture==7386 and textures[2].texture==7386 and textures[3].texture==7386)
fresh("WARRIOR",{7386,6343})
assert(textures[1].texture==6343)
C_Spell.IsCurrentSpell=function() return true end
cd[6343]=true; tick(); assert(textures[1].texture==7386)
-- Bear repeated Lacerate filler, Primal Bite first, no insufficient Rage Maul.
C_Spell.IsCurrentSpell=function() return false end
fresh("DRUID",{407995,414644,6807})
power=30; tick()
assert(textures[1].texture==407995 and textures[2].texture==414644 and textures[3].texture==414644)
cmd("aoe")
fresh("DRUID",{407995,779,6807}); power=10; tick()
assert(textures[1].texture==779, "AoE Bear prioritizes Swipe")

-- Tank stance and out-of-combat buff upkeep.
GetShapeshiftFormID=function() return 1 end
fresh("WARRIOR",{71,7386})
assert(textures[1].texture==71)
GetShapeshiftFormID=function() return 18 end
tick(); assert(textures[1].texture==7386)
GetShapeshiftFormID=function() return 5 end
fresh("DRUID",{5487,779})
assert(textures[1].texture==779)
GetShapeshiftFormID=nil
fresh("PALADIN",{19740})
combat=false; tick(); assert(textures[1].texture==19740, "out-of-combat blessing")
-- Mana reserve prevents Consecration starving remaining spells.
fresh("PALADIN",{26573,679})
power=25
UnitPowerMax=function() return 100 end
costs[26573]=20
tick(); assert(textures[1].texture==679)
-- Secret aura table isn't reported as absent or accessed.
C_Secrets={ShouldSpellAuraBeSecret=function() return false end}
C_UnitAuras={GetPlayerAuraBySpellID=function() return marker end}
fresh("PALADIN",{20154,20271,498})
power=100
cast(20154)
assert(textures[1].texture==20271)
C_UnitAuras=nil
-- Real spell mapping without English label dependence.
cmd("bossmap 123 magic")
callbacks.DBM_TimerBegin("DBM_TimerBegin","mapped","Localized spell",1,nil,"next",123)
-- Group protection immunity excluded from normal health prompts.
IsInGroup=function() return true end
hp=.1; tick(); assert(not frames[5].shown)
IsInGroup=function() return false end
cmd("threshold protection 45")
assert(ProtPilotOffenseDB.thresholds.protection==.45)

-- Existing buffs are snapshotted before combat; restricted reads retain known expiry.
fresh("PALADIN",{20154,20271,465,7294,19740,20217})
combat=false
local buffExpiry=clock+300
local sealExpiry=clock+30
C_Secrets={ShouldSpellAuraBeSecret=function() return combat end}
C_UnitAuras={GetPlayerAuraBySpellID=function(id)
    if combat then return marker end
    if id==465 then return {expirationTime=0,applications=0} end
    if id==19740 then return {expirationTime=buffExpiry,applications=0} end
    if id==20154 then return {expirationTime=sealExpiry,applications=0} end
end}
tick()
assert(not frames[1].shown, "respect existing Devotion and Might in auto mode")
combat=true; tick()
assert(textures[1].texture==20271, "precombat seal snapshot supports combat Judgement")
cd[20271]=true; tick()
assert(textures[1].texture==132337, "empty combat rotation must not fall through to buffs")
-- A lower-rank aura is found by localized name instead of prompting a recast.
combat=false
C_UnitAuras.GetPlayerAuraBySpellID=function() return nil end
C_UnitAuras.GetAuraDataBySpellName=function(name,unit,filter)
    assert(unit=="player" and filter=="HELPFUL")
    if name==names[20154] then return {expirationTime=clock+30} end
    if name=="Spell465" then return {expirationTime=0} end
    if name=="Spell19740" then return {expirationTime=clock+300} end
end
tick()
assert(not frames[1].shown, "rank-independent helpful aura lookup")
C_UnitAuras=nil

-- Forecast waits through a cooldown gap and chooses the earlier ready spell.
C_UnitAuras=nil
fresh("PALADIN",{679,26573})
power=100
local originalCooldown=C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown=function(id)
    local duration=id==679 and 2 or 5
    return {isActive=true,isEnabled=true,startTime=clock,duration=duration}
end
tick()
assert(textures[1].texture==679, "earlier Holy Strike before Consecration")
assert(frames[2].shown~=false)
assert(textures[2].texture==26573, "forecast advances to next cooldown gap")
C_Spell.GetSpellCooldown=originalCooldown
-- Secret timing can be forecast after a successful cast, without calling it ready now.
fresh("PALADIN",{679})
cast(679)
cd[679]=true
tick()
assert(textures[1].texture==679, "cast-based cooldown forecast")
assert(frames[2].alpha==1)

-- Solo damage preference changes to tanking seal on joining a group.
fresh("PALADIN",{20154,1311649,20271})
cmd("seal auto")
assert(textures[1].texture==20154)
IsInGroup=function() return true end;tick()
assert(textures[1].texture==1311649)
cast(20154)
assert(ProtPilotOffenseDB.seal=="auto")
assert(textures[1].texture==1311649)
cmd("seal righteousness")
IsInGroup=function() return false end
assert(ProtPilotOffenseDB.seal=="righteousness")
-- Integrated survival: control break beats attacks even without a hostile target.
C_LossOfControl={GetActiveLossOfControlDataCount=function() return 1 end,
 GetActiveLossOfControlData=function() return {locType="STUN"} end}
fresh("PALADIN",{20154,1311649,20271,1259718})
assert(textures[1].texture==1259718,"stun racial first")
UnitCanAttack=function() return false end; tick()
assert(textures[1].texture==1259718,"racial without target")
UnitCanAttack=function() return true end
C_LossOfControl.GetActiveLossOfControlData=function() return {locType=marker} end
tick(); assert(textures[1].texture~=1259718,"secret control must not guess")
C_LossOfControl.GetActiveLossOfControlDataCount=function() return 0 end
UnitHealth=function() return 15 end; UnitHealthMax=function() return 100 end
C_Item={GetItemCount=function(id) return id==858 and 2 or 0 end,
 IsUsableItem=function() return true end,
 GetItemCooldown=function() return 0,0,1 end,
 GetItemNameByID=function() return "Lesser Healing Potion" end,
 GetItemIconByID=function(id) return id end}
fresh("PALADIN",{20154,20271,633,498})
assert(textures[1].texture==858,"carried potion before emergency spell")
C_Item.GetItemCooldown=function() return clock,120,1 end
tick(); assert(textures[1].texture==633,"cooling potion falls through to LoH")
cmd("health off"); assert(textures[1].texture~=633)
cmd("health on")
UnitHealth=function() return 42 end
GetUnitSpeed=function() return 0 end
UnitCastingInfo=function() return nil end
fresh("PALADIN",{20154,20271,635})
assert(textures[1].texture==635,"solo heal")
GetUnitSpeed=function() return 7 end; tick()
assert(textures[1].texture~=635,"no moving cast-time heal")
GetUnitSpeed=function() return 0 end
IsInGroup=function() return true end; tick()
assert(textures[1].texture~=635,"no unsolicited group cast-time heal")
cmd("visibility combat"); combat=false; tick(); assert(not frames[1].shown)
cmd("visibility always"); assert(frames[1].shown)
-- Experimental health method: simulate engine numeric curves and secret text output.
local stored=methods.SetText
function methods:GetText() return rawget(self,"text") end
function methods:ClearText() self.text=nil end
function methods:SetText(v) if v=="" then self.text=nil else self.text=v end end
C_CurveUtil.CreateCurve=function()
 local curve={}
 function curve:SetType() end
 function curve:AddPoint(x,y) if x>0 and y==100 then self.cut=x end end
 function curve:Evaluate(x) return x<=self.cut and 100 or 0 end
 return curve
end
local raw=100
UnitHealth=function() return marker end
UnitHealthPercent=function() return marker end
C_StringUtil={TruncateWhenZero=function() return raw==0 and "" or marker end}
assert(ProtPilotSurvival.Below(.3,true)==true)
raw=0; assert(ProtPilotSurvival.Below(.3,true)==false)
C_StringUtil.TruncateWhenZero=function() error("unavailable") end
assert(ProtPilotSurvival.Below(.3,true)==nil,"broken readback unknown")
assert(ProtPilotSurvival.Below(.3,false)==nil,"experimental switch")
-- Missing APIs: readable cooldown no longer assumed; diagnostics remain usable.
C_Spell.GetSpellCooldown=nil
tick(); cmd("status")

-- Secret speed no longer blocks a readable movement flag or confirmed stop event.
GetUnitSpeed=function() return marker end
IsPlayerMoving=function() return false end
assert(ProtPilotSurvival.Stationary()==true)
IsPlayerMoving=function() return true end
assert(ProtPilotSurvival.Stationary()==false)
IsPlayerMoving=function() return marker end
ProtPilotSurvival.MovementEvent('PLAYER_ENTERING_WORLD')
assert(ProtPilotSurvival.Stationary()==nil)
ProtPilotSurvival.MovementEvent('PLAYER_STOPPED_MOVING')
assert(ProtPilotSurvival.Stationary()==true)
ProtPilotSurvival.MovementEvent('PLAYER_STARTED_MOVING')
assert(ProtPilotSurvival.Stationary()==false)
cmd('report')
-- Dispel container configuration, narrow filter, texture registration, and failure handling.
local oldCreate=CreateFrame
local registrations,groups=0,0
Enum.LuaCurveType.Step=1
Enum.CustomAuraButtonDispelTypeTextureStyle={PreserveAsset=1}
local capturedContainer
CreateFrame=function(kind,...)
 local f=oldCreate(kind,...)
 if kind=='AuraContainer' then
  capturedContainer=f
  function f:SetUnit(unit) assert(unit=='player') end
  function f:AddAuraGroup(name,filter,opts)
   assert(filter=='HARMFUL|RAID_PLAYER_DISPELLABLE')
   assert(opts.maxFrameCount==40)
   groups=groups+1
   local b=oldCreate('Frame')
   function b:AddDispelTypeTexture(tex,options)
    assert(options.showAlways and options.style==1)
    local p=options.customDispelColorCurve.points
    assert(select(4,p[4][2]:GetRGBA())==1,'disease visible')
    assert(select(4,p[5][2]:GetRGBA())==1,'poison visible')
    assert(select(4,p[2][2]:GetRGBA())==0,'Purify must not cue magic')
    registrations=registrations+1
   end
   opts.initializeFrame(b)
  end
 end
 return f
end
combat=false
ProtPilotSurvival.CreateDispelCue(frames[1],{id=1152,icon=1152},false)
assert(groups==1 and registrations==1)
ProtPilotSurvival.CreateDispelCue(frames[1],{id=1152,icon=1152},false)
assert(groups==1,'no rebuilding each tick')
ProtPilotSurvival.ShowDispelCue(true);assert(capturedContainer.shown)
ProtPilotSurvival.ShowDispelCue(false);assert(not capturedContainer.shown)
CreateFrame=function(kind,...)
 if kind=='AuraContainer' then error('unsupported frame') end
 return oldCreate(kind,...)
end
ProtPilotSurvival.CreateDispelCue(frames[1],{id=4987,icon=4987},true)
assert(ProtPilotSurvival.dispelStatus=='unavailable')
-- Options UI opens and changes real saved settings through its callbacks.
local makeFrame=CreateFrame
CreateFrame=function(kind,name,parent,template)
 local f=makeFrame(kind,name,parent,template);f.kind=kind;f.template=template
 if kind=='Slider' then
  f.Low={SetText=function() end};f.High={SetText=function() end};f.Text={SetText=function() end}
  function f:SetValue(v) self.value=v;if self.OnValueChanged then self.OnValueChanged(self,v) end end
 end
 if kind=='CheckButton' then
  function f:GetChecked() return self.checked end
  function f:SetChecked(v) self.checked=v end
 end
 return f
end
local firstOptionsFrame=#frames+1
cmd('options')
local scaleSlider,lockCheck
for i=firstOptionsFrame,#frames do
 local f=frames[i]
 if f.kind=='Slider' and not scaleSlider then scaleSlider=f end
 if f.kind=='CheckButton' and not lockCheck then lockCheck=f end
end
assert(scaleSlider and lockCheck,'settings controls created')
scaleSlider.OnValueChanged(scaleSlider,125)
assert(ProtPilotOffenseDB.scale==1.25)
lockCheck.checked=false;lockCheck.OnClick(lockCheck)
assert(ProtPilotOffenseDB.locked==false)
cmd('lock');assert(ProtPilotOffenseDB.locked==true)
ProtPilotSettingsAPI.set('potionPercent',40)
assert(ProtPilotOffenseDB.thresholds.potion==.4)
ProtPilotSettingsAPI.set('showNames',false)
assert(ProtPilotOffenseDB.showNames==false)
ProtPilotSettingsAPI.resetDisplay()
assert(ProtPilotOffenseDB.scale==1 and ProtPilotOffenseDB.position==nil)
cmd('scale 500');assert(ProtPilotOffenseDB.scale==1.6)
cmd('scale 1');assert(ProtPilotOffenseDB.scale==.6)
cmd('resetposition');assert(ProtPilotOffenseDB.scale==1)
local frameCount=#frames
cmd('options');assert(#frames==frameCount,'reuse options window')

-- 0.6.0: menu registration, nameplate detection and every class/tree.
combat=false
local registeredCategory,registerCount=nil,0
Settings={RegisterCanvasLayoutCategory=function(panel,name)
 assert(name=='Tank Pilot' and panel.name==name);return {ID=111}
end,RegisterAddOnCategory=function(cat) registeredCategory=cat;registerCount=registerCount+1 end}
ProtPilotOptions.Register(ProtPilotSettingsAPI)
ProtPilotOptions.Register(ProtPilotSettingsAPI)
assert(registeredCategory.ID==111 and registerCount==1,'register native category once')

local npCount=3
UnitExists=function(unit) return unit=='target' or unit=='pet' or (tonumber(unit:match('nameplate(%d+)')) or 99)<=npCount end
UnitCanAttack=function(_,unit) return unit~='pet' end
UnitIsUnit=function(a,b) return a==b or a=='nameplate1' and b=='target' end
UnitThreatSituation=function(_,unit) return unit=='nameplate4' and nil or 1 end
UnitAffectingCombat=function() return true end
clock=clock+10
assert(ProtPilotTargets.Update('auto')==3)
npCount=1;clock=clock+.3;assert(ProtPilotTargets.Update('auto')==3,'short downgrade hysteresis')
clock=clock+1;assert(ProtPilotTargets.Update('auto')==1)
assert(ProtPilotTargets.Update('aoe')==4)
clock=clock+1;assert(ProtPilotTargets.Update('single')==1)
local threat=UnitThreatSituation
UnitThreatSituation=function() return marker end
npCount=5;clock=clock+1
assert(ProtPilotTargets.Update('auto')==1,'secret threat never compared or counted')
UnitThreatSituation=threat

C_Spell.GetSpellCooldown=originalCooldown
C_Secrets={ShouldSpellAuraBeSecret=function() return false end}
local auraMap={}
C_UnitAuras={GetPlayerAuraBySpellID=function(id) return auraMap['player:'..id] end,
 GetAuraDataBySpellName=function(name,unit,filter)
   assert(unit=='player' or unit=='target','correct GetAuraDataBySpellName order')
   for _,id in ipairs(learned) do
     if name==(names[id] or 'Spell'..id) then return auraMap[unit..':'..id] end
   end
 end}
IsPlayerSpell=function(id) for _,v in ipairs(learned) do if v==id then return true end end return false end
C_SpellBook.IsSpellInSpellBook=IsPlayerSpell
UnitPowerType=function() return (class=='WARRIOR' and 1) or (class=='ROGUE' and 3) or 0 end
local combo=0
UnitPower=function(_,id) if id==4 then return combo end return power end
UnitPowerMax=function(_,id) return id==4 and 5 or 100 end
GetComboPoints=function() return combo end
UnitHealth=function() return 100 end;UnitHealthMax=function() return 100 end
C_Spell.GetSpellPowerCost=function() return {{type=UnitPowerType(),cost=10}} end
C_Spell.GetSpellName=function(id) return names[id] or 'Spell'..id end
C_Spell.IsSpellInRange=function() return true end
GetSpellBaseCooldown=function(id)
 local base=ProtPilotProfiles.Base(id)
 return ({[1680]=10000,[23881]=6000,[3044]=6000,[20271]=10000,[679]=10000,[26573]=8000,[3045]=300000,[19574]=120000,[13750]=300000,[13877]=120000,[11129]=180000,[16166]=180000,[8092]=8000})[base] or 0
end
ProtPilotSettingsAPI.set('health',false)
ProtPilotSettingsAPI.set('cooldowns',false)
cmd('single')
local checked=0
for token,trees in pairs(ProtPilotCatalog.trees) do
 local c=token:gsub('_F$','')
 for key,tree in pairs(trees) do
  if type(tree)=='table' then
   ProtPilotCharacterDB={profile=key};auraMap={};combo=3;power=100
   local ids=ProtPilotCatalog.classSpells[token]
   fresh(c,ids)
   assert(textures[1].texture~=132337,'empty class profile: '..c..' '..key)
   local previousGroup=IsInGroup
   local knownIcons={}
   for _,id in ipairs(ids) do knownIcons[id]=true end
   for _,group in ipairs({false,true}) do
    IsInGroup=function() return group end
    for _,count in ipairs({1,2,4}) do
     npCount=count;cmd('auto');clock=clock+2;tick()
     for slot=1,3 do
      local icon=textures[slot].texture
      assert(icon==132337 or knownIcons[icon],c..' '..key..' invalid slot '..slot)
     end
    end
   end
   IsInGroup=previousGroup;npCount=1;cmd('single')
   checked=checked+1
  end
 end
end
assert(checked==28,'all 28 tank/damage tree profiles exercised')

-- Fury: Whirlwind before Bloodthirst; cooldowns sequence into second action.
ProtPilotCharacterDB={profile='fury'};combo=0;power=100
fresh('WARRIOR',{1680,23881,78})
assert(textures[1].texture==1680 and textures[2].texture==23881,'Fury priority and forecast cooldowns')
-- Ranks: resolve highest known Arcane Shot, never the level-one version.
ProtPilotCharacterDB={profile='marksmanship'}
fresh('HUNTER',{3044,14281})
assert(textures[1].texture==14281,'highest learned rank')
-- Hunter burst toggle and cooldown must appear only once in a forecast.
ProtPilotCharacterDB={profile='beast_mastery'}
fresh('HUNTER',{3045,3044})
assert(textures[1].texture==3044)
ProtPilotSettingsAPI.set('cooldowns',true);tick()
assert(textures[1].texture==3045 and textures[2].texture~=3045 and textures[3].texture~=3045)
ProtPilotSettingsAPI.set('cooldowns',false)
-- Paladin DPS must not inherit Fury seal or Righteous Fury tank maintenance.
ProtPilotCharacterDB={profile='retribution'}
fresh('PALADIN',{20154,1311649,25780,20271,679})
assert(textures[1].texture==20154 and textures[2].texture==20271,'Ret seal into Judgement')
assert(textures[1].texture~=25780 and textures[1].texture~=1311649)
-- Automatic AoE actually changes the tank priority, then returns to single.
ProtPilotCharacterDB={profile='protection'};power=100
fresh('PALADIN',{679,26573,20925})
cmd('auto');npCount=3;clock=clock+1;tick()
assert(textures[1].texture==26573 and ProtPilotOffenseDB.aoe)
npCount=1;clock=clock+2;tick()
assert(textures[1].texture==20925 and textures[2].texture==26573 and not ProtPilotOffenseDB.aoe)
cd[20925]=true;tick()
assert(textures[1].texture==26573 and textures[2].texture==679,'single-target ground damage before filler')
-- Unknown proc stacks cannot become a positive recommendation.
local ctx={byID={},targets=1,aura=function() return nil end}
assert(ProtPilotProfiles.Gate({t='stack',id=400625,op='>=',n=3},ctx,{time=0})==nil)
ProtPilotCharacterDB={profile='protection'}
ProtPilotSettingsAPI.set('cooldowns',true)
cmd('seal righteousness')
cmd('single')
IsInGroup=function() return false end
fresh('PALADIN',{20154,20271,1310994})
auraMap['player:20154']={expirationTime=clock+25}
clock=clock+1;tick()
assert(textures[1].texture==20271 and textures[2].texture==1310994,'independent Swift Judgement forecast')
assert(textures[3].texture~=1310994,'Swift cannot repeat immediately')
cd[20271]=true;tick()
assert(textures[1].texture==1310994,'Swift ready while normal Judgement cools down')
cd[1310994]=true;tick()
assert(textures[1].texture~=1310994,'Swift cooldown respected')
UnitCreatureType=function() return 'Mort-vivant',6 end
fresh('PALADIN',{879,5614,679})
assert(textures[1].texture==5614 and textures[2].texture==679,'highest Exorcism rank before melee filler')
combat=false;tick();assert(textures[1].texture==5614,'eligible pull')
UnitCreatureType=function() return 'Humanoid',7 end
tick();assert(textures[1].texture~=5614,'ineligible pull')
combat=true;tick();assert(textures[1].texture==679,'ineligible target in combat')
UnitCreatureType=function() return marker,marker end
tick();assert(textures[1].texture==679,'unreadable target type')
UnitCreatureType=function() return 'Demon',3 end
C_Spell.IsSpellInRange=function(id) return id~=5614 end
tick();assert(textures[1].texture==679,'out of range')
C_Spell.IsSpellInRange=function() return true end
combat=false; UnitCreatureType=function() return 'Undead' end
event('PLAYER_TARGET_CHANGED');tick()
combat=true;UnitCreatureType=function() return marker,marker end;tick()
assert(textures[1].texture==5614,'retain same-target observation during combat')
event('PLAYER_TARGET_CHANGED');tick()
assert(textures[1].texture==679,'clear observation before evaluating new target')
local mobID='111'
UnitGUID=function() return 'Creature-0-0-0-0-'..mobID..'-0' end
UnitName=function() return 'Dungeon ghoul' end
event('UNIT_SPELLCAST_SENT','player','Dungeon ghoul','cast-one',5614)
event('UNIT_SPELLCAST_SUCCEEDED','player','cast-one',5614)
assert(ProtPilotProfiles.ValidHolyTarget(879),'learn from matched successful cast')
assert(not ProtPilotProfiles.ValidHolyTarget(2812),'confirmation is spell specific')
event('PLAYER_TARGET_CHANGED')
assert(ProtPilotProfiles.ValidHolyTarget(879),'same NPC type')
mobID='222';event('PLAYER_TARGET_CHANGED')
assert(not ProtPilotProfiles.ValidHolyTarget(879),'different NPC')
cmd('exorcism allow');assert(ProtPilotProfiles.ValidHolyTarget(879))
cmd('exorcism clear');assert(not ProtPilotProfiles.ValidHolyTarget(879))
IsInGroup=function() return false end
UnitClassification=function() return 'worldboss' end
fresh('PALADIN',{20154,21082,20271,20164})
cmd('seal auto');tick()
assert(textures[1].texture==21082 and textures[2].texture==20271 and textures[3].texture==20154,'boss seal sequence')
UnitClassification=function() return 'normal' end
event('PLAYER_TARGET_CHANGED')
event('CHAT_MSG_MONSTER_EMOTE','%s attempts to run away in fear!','Dungeon ghoul')
assert(textures[1].texture==20164 and textures[2].texture==20271 and textures[3].texture==20154,'runner seal sequence')

-- Interrupts need an interruptible, in-range live cast, then resume the profile.
UnitCastingInfo=function(unit)
 if unit=='target' then return 'Enemy heal',nil,nil,clock*1000,(clock+2)*1000,nil,nil,false end
end
for _,row in ipairs({{'MAGE','fire',2139,133},{'ROGUE','combat',1766,1752},
 {'SHAMAN','elemental',8042,403},{'WARRIOR','fury',6552,23881}}) do
 ProtPilotCharacterDB={profile=row[2]}
 fresh(row[1],{row[3],row[4]})
 assert(textures[1].texture==row[3] and textures[2].texture~=row[3],row[1]..' interrupt followed by rotation')
end
UnitCastingInfo=function() return 'Protected',nil,nil,nil,(clock+2)*1000,nil,nil,true end
ProtPilotCharacterDB={profile='fire'};fresh('MAGE',{2139,133})
assert(textures[1].texture==133,'protected cast skips Counterspell')
UnitCastingInfo=nil
ProtPilotCharacterDB={profile='holy'};power=25
UnitGroupRolesAssigned=function() return 'HEALER' end
IsInGroup=function() return true end
fresh('PRIEST',{585,5019})
C_Spell.GetSpellPowerCost=function(id) return {{type=0,cost=id==5019 and 0 or 10}} end
tick();assert(textures[1].texture==5019,'group healer saves mana and wands')
IsInGroup=function() return false end;tick();assert(textures[1].texture==585,'solo priest spends mana')

-- Change one encounter signal at a time; keep gear and the spellbook fixed.
UnitGroupRolesAssigned=function(unit) return unit=='targettarget' and 'TANK' or 'DAMAGER' end
UnitIsUnit=function(a,b) return a==b end
IsInGroup=function() return true end
power=100; hp=1
ProtPilotCharacterDB={profile='protection'}
fresh('PALADIN',{1311649,20154,20271})
assert(textures[1].texture==20154,'other tank owns target: use damage seal')
for _,row in ipairs({{'WARRIOR','protection',355,23922},{'DRUID','feral_bear',6795,407995}}) do
 ProtPilotCharacterDB={profile=row[2]}
 fresh(row[1],{row[3],row[4]})
 assert(textures[1].texture~=row[3],'do not taunt another tank')
 UnitGroupRolesAssigned=function() return 'DAMAGER' end;tick()
 assert(textures[1].texture==row[3] and textures[2].texture~=row[3],'recover party aggro once')
 UnitGroupRolesAssigned=function() return 'TANK' end
end
IsInGroup=function() return false end
UnitIsUnit=function(a,b) return a=='targettarget' and b=='player' or a==b end
ProtPilotCharacterDB={profile='combat'}
fresh('ROGUE',{53,1752});assert(textures[1].texture==1752,'solo frontal rogue builder')
ProtPilotCharacterDB={profile='survival'}
fresh('HUNTER',{75,2973});assert(textures[1].texture==2973,'melee survival starts melee attack')
UnitClassification=function() return 'normal' end
UnitHealth=function(unit) return unit=='target' and 10 or 100 end
ProtPilotCharacterDB={profile='affliction'}
fresh('WARLOCK',{172,686});assert(textures[1].texture==686,'do not start Corruption on dying trash')
ProtPilotCharacterDB={profile='restoration'}
fresh('DRUID',{8921,5176});assert(textures[1].texture==8921 or textures[1].texture==5176)
-- Pet-dependent cooldowns require a live pet. The cooldowns option still controls burst.
ProtPilotCharacterDB={profile='beast_mastery'};ProtPilotSettingsAPI.set('cooldowns',true)
local unitDead=UnitIsDeadOrGhost
UnitIsDeadOrGhost=function(unit) return unit=='pet' end
fresh('HUNTER',{19574,3044}); assert(textures[1].texture==3044,'dead pet suppresses Bestial Wrath')
UnitIsDeadOrGhost=unitDead
-- A protected channel must not offer Kick; an interruptible channel must.
UnitCastingInfo=function() end
local channelLocked=true
UnitChannelInfo=function(unit)
 if unit=='target' then return 'Channel',nil,nil,nil,(clock+2)*1000,nil,channelLocked end
end
ProtPilotCharacterDB={profile='combat'};fresh('ROGUE',{1766,1752})
assert(textures[1].texture==1752)
channelLocked=false;tick();assert(textures[1].texture==1766 and textures[2].texture==1752)
C_Spell.IsSpellInRange=function(id) return id~=1766 end;tick();assert(textures[1].texture==1752)
UnitChannelInfo=nil;C_Spell.IsSpellInRange=function() return true end
ProtPilotCharacterDB={profile='protection'};power=100;fresh('PALADIN',{26573})
ActionButton5={action=5}
local key='5'
GetBindingKey=function(cmd) if cmd=='ACTIONBUTTON5' then return key end end
GetBindingAction=function(k) if k==key then return 'ACTIONBUTTON5' end end
GetActionInfo=function(slot) if slot==5 then return 'spell',26573 end end
event('UPDATE_BINDINGS');assert(hotkeys[1].text=='5',tostring(textures[1].texture)..' key '..tostring(hotkeys[1].text))
key='SHIFT-5';event('UPDATE_BINDINGS');assert(hotkeys[1].text=='S-5')
ActionButton5.action=17;event('ACTIONBAR_PAGE_CHANGED');assert(rawget(hotkeys[1],'text')==nil)
