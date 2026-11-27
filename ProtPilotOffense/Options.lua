-- SPDX-License-Identifier: GPL-3.0-or-later
-- Standalone settings window; no external UI library required.
ProtPilotOptions={}
local O=ProtPilotOptions
local window,pages,refreshers
local function text(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    f:SetPoint('TOPLEFT',x,y);f:SetWidth(width or 490);f:SetJustifyH('LEFT');f:SetText(value)
    return f
end
function O.Open(api)
    if not window then
        window=CreateFrame('Frame','TankPilotOptionsWindow',UIParent,'BackdropTemplate')
        window:SetSize(560,550);window:SetPoint('CENTER');window:SetFrameStrata('DIALOG')
        window:SetClampedToScreen(true);window:EnableMouse(true);window:SetMovable(true)
        window:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
        window:SetBackdropColor(.04,.05,.07,.98)
        window:RegisterForDrag('LeftButton')
        window:SetScript('OnDragStart',function(self) self:StartMoving() end)
        window:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
        local title=text(window,'Tank Pilot settings',22,-20);title:SetFontObject('GameFontNormalLarge')
        local close=CreateFrame('Button',nil,window,'UIPanelCloseButton');close:SetPoint('TOPRIGHT')
        close:SetScript('OnClick',function() window:Hide() end)
        if UISpecialFrames then table.insert(UISpecialFrames,'TankPilotOptionsWindow') end
        pages={};refreshers={}
        local function refresh() for _,f in ipairs(refreshers) do f() end end
        local function button(parent,label,x,y,w,fn)
            local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
            b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y);b:SetText(label)
            b:SetScript('OnClick',function() fn();refresh() end);return b
        end
        local function check(parent,label,key,x,y)
            local b=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate')
            b:SetSize(24,24);b:SetPoint('TOPLEFT',x,y);text(parent,label,x+30,y-5,430)
            b:SetScript('OnClick',function(self) api.set(key,self:GetChecked()==true);refresh() end)
            refreshers[#refreshers+1]=function() b:SetChecked(api.get(key)) end
        end
        local function cycle(parent,label,key,choices,x,y)
            text(parent,label,x,y,180)
            local b
            b=button(parent,'',x+185,y+5,285,function()
                local current=api.get(key);local nextIndex=1
                for i,c in ipairs(choices) do if c[1]==current then nextIndex=i%#choices+1;break end end
                api.set(key,choices[nextIndex][1])
            end)
            refreshers[#refreshers+1]=function()
                local label='Choose'
                for _,c in ipairs(choices) do if c[1]==api.get(key) then label=c[2] end end
                b:SetText(label)
            end
        end
        local function slider(parent,label,key,minimum,maximum,step,x,y)
            local caption=text(parent,'',x,y,470)
            local s=CreateFrame('Slider',nil,parent,'OptionsSliderTemplate')
            s:SetPoint('TOPLEFT',x,y-23);s:SetSize(470,18);s:SetMinMaxValues(minimum,maximum)
            s:SetValueStep(step);s:SetObeyStepOnDrag(true)
            if s.Low then s.Low:SetText(tostring(minimum)) end
            if s.High then s.High:SetText(tostring(maximum)) end
            if s.Text then s.Text:SetText('') end
            local syncing=false
            s:SetScript('OnValueChanged',function(_,value)
                if syncing then return end
                local rounded=math.floor(value/step+.5)*step
                api.set(key,rounded);caption:SetText(label..': '..rounded..'%')
            end)
            refreshers[#refreshers+1]=function()
                syncing=true;local v=api.get(key);s:SetValue(v);caption:SetText(label..': '..v..'%');syncing=false
            end
        end
        for i,name in ipairs({'Display','Survival','Rotation'}) do
            local page=CreateFrame('Frame',nil,window);page:SetPoint('TOPLEFT',24,-100);page:SetSize(510,405)
            pages[i]=page
            button(window,name,24+(i-1)*170,-58,160,function()
                for j,p in ipairs(pages) do if i==j then p:Show() else p:Hide() end end
            end)
        end
        local p=pages[1]
        cycle(p,'Show helper','visibility',{{'auto','Automatic'},{'always','Always'},{'combat','Only in combat'}},0,0)
        check(p,'Lock display position','locked',0,-40)
        text(p,'Uncheck to drag the helper. Position is saved automatically.',30,-70)
        slider(p,'Display size','scalePercent',60,160,5,0,-108)
        check(p,'Show action names','showNames',0,-180)
        check(p,'Show recommendation explanation','showReason',0,-214)
        check(p,'Show class and combat mode','showTitle',0,-248)
        button(p,'Reset position and size',0,-300,225,function() api.resetDisplay() end)
        button(p,'Copy diagnostic report',245,-300,225,function() api.report() end)
        text(p,'NOW is the next action. NEXT and THEN are conditional forecasts.\nDISPEL is a separate cue and is not part of that forecast.',0,-350)
        p=pages[2]
        check(p,'Health-based survival recommendations','health',0,0)
        check(p,'Healing potions from your bags','potions',0,-32)
        check(p,'Paladin self-healing (solo only)','selfheal',0,-64)
        check(p,'Control breaks and racials','breaks',0,-96)
        check(p,'Dispel cue','dispelcue',0,-128)
        check(p,'Defensives for mapped DBM warnings','boss',0,-160)
        check(p,'Experimental health decisions','experimental',0,-192)
        slider(p,'Potion health threshold','potionPercent',5,95,5,0,-240)
        slider(p,'Self-heal health threshold','selfhealPercent',5,95,5,0,-310)
        text(p,'Disabling health recommendations also disables potions and self-heals.\nDispel cues and control breaks have separate switches.',0,-380)
        p=pages[3]
        cycle(p,'Combat mode','targetMode',{{'auto','Automatic enemy count'},{'single','Single target'},{'aoe','Force AoE (4+ targets)'}},0,0)
        cycle(p,'Class profile','profile',api.profileChoices(),0,-40)
        check(p,'Recommend offensive cooldowns','cooldowns',0,-76)
        cycle(p,'Paladin seal','seal',{{'auto','Auto (solo/group)'},{'fury','Fury (tank)'},{'righteousness','Righteousness'},{'manual','Choose manually'}},0,-120)
        cycle(p,'Paladin aura','aura',{{'auto','Automatic'},{'devotion','Devotion'},{'retribution','Retribution'},{'manual','Choose manually'}},0,-160)
        cycle(p,'Paladin blessing','blessing',{{'auto','Automatic'},{'kings','Kings'},{'might','Might'},{'manual','Choose manually'}},0,-200)
        check(p,'Recommend bleeds where allowed','rend',0,-236)
        text(p,'Automatic mode counts engaged hostile nameplates. Enable enemy\nnameplates (V). Hidden or restricted data can limit the count.\nClass profile is saved per character; talent changes refresh out of combat.',0,-280)
        text(p,'All actions remain manual. For a bleed-immune creature:\n/ppoff bleed immune   (undo: /ppoff bleed clear)',0,-352)
        text(window,'Changes save immediately. Close with X or Escape.',24,-520)
        window:SetScript('OnShow',refresh)
        for i,p in ipairs(pages) do if i==1 then p:Show() else p:Hide() end end
        O.Refresh=refresh
    end
    O.Refresh();window:Show()
end

-- Registered lazily after player data is ready; works with modern and legacy menus.
function O.Register(api)
    if O.registered or not api then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory)
        and type(InterfaceOptions_AddCategory)~='function' then return end
    local panel=O.panel
    if not panel then
        panel=CreateFrame('Frame','TankPilotSettingsPanel',UIParent);O.panel=panel
        panel.name='Tank Pilot';panel:Hide()
        local heading=text(panel,'Tank Pilot',20,-20);heading:SetFontObject('GameFontNormalLarge')
        text(panel,'Tank and DPS recommendations for WoW Forever.\nConfigure display, survival, profiles, automatic AoE and cooldowns below.',20,-60,580)
        local button=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
        button:SetSize(240,32);button:SetPoint('TOPLEFT',20,-115);button:SetText('Open Tank Pilot options')
        button:SetScript('OnClick',function() O.Open(api) end)
        text(panel,'You can also open these options with /ppoff. Changes save immediately.\nProfile selection is per character. Other options are shared.',20,-170,580)
    end
    local ok=pcall(function()
        if Settings and Settings.RegisterCanvasLayoutCategory then
            O.category=O.category or Settings.RegisterCanvasLayoutCategory(panel,'Tank Pilot')
            Settings.RegisterAddOnCategory(O.category)
        else InterfaceOptions_AddCategory(panel) end
    end)
    O.registered=ok
end
