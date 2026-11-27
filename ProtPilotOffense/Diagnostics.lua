-- SPDX-License-Identifier: GPL-3.0-or-later
local S=ProtPilotSurvival
local lines,last={},{}
function S.Log(key,value)
    local text=tostring(value)
    if last[key]==text then return end
    last[key]=text
    if #lines>=200 then table.remove(lines,1) end
    lines[#lines+1]=string.format('%.2f %s | %s=%s',GetTime(),InCombatLockdown() and 'COMBAT' or 'IDLE',key,text)
end
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v)=='table' and issecrettable and issecrettable(v) then return nil end
    return v
end
local lastContext
function S.ProbeAuraAccess()
    local context=InCombatLockdown() and 'combat' or 'idle'
    if lastContext==context then return end
    lastContext=context
    local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not fn then S.Log('aura access','MISSING'); return end
    local ok,result=pcall(fn,'player',1,'HARMFUL')
    if not ok then
        result=plain(result)
        S.Log('aura access '..context,'ERROR: '..(type(result)=='string' and result:sub(1,500) or 'unreadable error'))
    elseif result==nil then S.Log('aura access '..context,'NIL')
    elseif plain(result)==nil then S.Log('aura access '..context,'SECRET')
    else S.Log('aura access '..context,'READABLE (not proof of dispellability)') end
end
local reportFrame,edit
function S.Report(summary)
    if not reportFrame then
        reportFrame=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
        reportFrame:SetSize(720,480);reportFrame:SetPoint('CENTER');reportFrame:SetFrameStrata('DIALOG')
        reportFrame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'})
        reportFrame:SetBackdropColor(.03,.03,.03,.98);reportFrame:EnableMouse(true)
        local title=reportFrame:CreateFontString(nil,'OVERLAY','GameFontNormal')
        title:SetPoint('TOPLEFT',16,-12);title:SetText('Tank Pilot report: Ctrl+A, Ctrl+C. Copy before /reload.')
        local close=CreateFrame('Button',nil,reportFrame,'UIPanelCloseButton');close:SetPoint('TOPRIGHT')
        close:SetScript('OnClick',function() reportFrame:Hide() end)
        local scroll=CreateFrame('ScrollFrame',nil,reportFrame,'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT',16,-38);scroll:SetPoint('BOTTOMRIGHT',-32,16)
        edit=CreateFrame('EditBox',nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal);edit:SetWidth(660);edit:SetMaxLetters(0)
        edit:SetScript('OnEscapePressed',function() reportFrame:Hide() end);scroll:SetScrollChild(edit)
    end
    edit:SetText('Tank Pilot 0.6.6\n'..summary..'\nLast 200 changes; timestamps are session seconds.\n'..table.concat(lines,'\n'))
    reportFrame:Show();edit:SetFocus();edit:HighlightText()
end
