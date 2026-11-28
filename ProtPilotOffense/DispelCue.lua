-- SPDX-License-Identifier: GPL-3.0-or-later
-- AuraContainer registration adapted from JustAC 6.2.1 UISootheCue.lua,
-- Copyright (C) 2024-2026 wealdly. Modified: player disease/poison cue.
local S=ProtPilotSurvival
local container,attempted,activeID
S.dispelStatus='not initialized'
function S.CreateDispelCue(parent,spell,cleanse)
    if not spell or InCombatLockdown() then return end
    if attempted==spell.id then return end
    attempted=spell.id
    if container then pcall(container.Hide,container);container=nil end
    local candidate
    local ok,err=pcall(function()
        local style=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
        local curveType=Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
        if not (style and style.PreserveAsset and curveType and C_CurveUtil and C_CurveUtil.CreateColorCurve) then
            error('AuraContainer display API unavailable')
        end
        local curve=C_CurveUtil.CreateColorCurve()
        curve:SetType(curveType)
        for i=0,10 do
            local visible=i==3 or i==4 or (cleanse and i==1)
            curve:AddPoint(i,CreateColor(1,1,1,visible and 1 or 0))
        end
        candidate=CreateFrame('AuraContainer',nil,parent,'CustomAuraContainerTemplate')
        candidate:SetSize(48,48);candidate:SetPoint('TOPLEFT',parent,'TOPLEFT',290,0)
        candidate:SetUnit('player');candidate:EnableMouse(false)
        local registrationFailed=false
        local function initialize(button)
            local success,message=pcall(function()
                button:SetSize(48,48)
                local icon=button:CreateTexture(nil,'ARTWORK')
                -- All qualifying aura icons share one visual cue position.
                icon:SetSize(48,48);icon:SetPoint('TOPLEFT',candidate,'TOPLEFT',0,0)
                icon:SetTexture(spell.icon);icon:SetTexCoord(.08,.92,.08,.92)
                button:AddDispelTypeTexture(icon,{showAlways=true,style=style.PreserveAsset,customDispelColorCurve=curve})
            end)
            if not success then
                registrationFailed=true
                S.dispelStatus='button setup failed'
                if S.Log then S.Log('dispel error',type(message)=='string' and message:sub(1,300) or 'unknown') end
                pcall(candidate.Hide,candidate)
            end
        end
        candidate:AddAuraGroup('tankPilotDispel','HARMFUL|RAID_PLAYER_DISPELLABLE',
            {maxFrameCount=40,initializeFrame=initialize})
        if registrationFailed then error('Dispel button setup failed') end
        candidate:Hide()
        container=candidate;activeID=spell.id
        S.dispelStatus='registered; visual confirmation needed'
    end)
    if not ok then
        if candidate then pcall(candidate.Hide,candidate) end
        S.dispelStatus='unavailable'
        if S.Log then S.Log('dispel setup error',type(err)=='string' and err:sub(1,300) or 'unknown') end
    end
end
function S.ShowDispelCue(enabled)
    if not container then return end
    -- Never inspect engine-owned buttons or infer aura presence from their visibility.
    local ok=pcall(function()
        if enabled and S.dispelStatus~='button setup failed' then container:Show() else container:Hide() end
    end)
    if not ok then S.dispelStatus='visibility failed' end
end
