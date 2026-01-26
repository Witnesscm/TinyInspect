
-------------------------------------
-- 鼠标装等和天赋 Author: M
-------------------------------------
local addon, ns = ...

if ns.IsMidnight then return end

local LibEvent = LibStub:GetLibrary("LibEvent.7000")

-- 使用 tooltipData.lines 查找文本
local function FindLineInTooltipData(tooltipData, keyword)
    if not tooltipData or not tooltipData.lines then return end
    for i, lineData in ipairs(tooltipData.lines) do
        if lineData.leftText and string.find(lineData.leftText, keyword) then
            return i
        end
    end
end

-- 直接在 GameTooltip 中查找行（包含 AddDoubleLine 添加的行）
local function FindLineInGameTooltip(keyword)
    local tooltipName = GameTooltip:GetName()
    for i = 1, GameTooltip:NumLines() do
        local leftLine = _G[tooltipName .. "TextLeft" .. i]
        if leftLine then
            local text = leftLine:GetText()
            if text and string.find(text, keyword, 1, true) then
                return i
            end
        end
    end
end

local LevelLabel = STAT_AVERAGE_ITEM_LEVEL .. ": "

local function AppendToGameTooltip(guid, ilevel, spec, weaponLevel, tooltipData)
    spec = spec or ""
    if TinyInspectDB and not TinyInspectDB.EnableMouseSpecialization then spec = "" end
    
    local _, unit = GameTooltip:GetUnit()
    if not unit then return end
    local unitGuid = SafeUnitAPI.GUID(unit)
    if not unitGuid or unitGuid ~= guid then return end
    
    local ilvlText = format("%s|cffffffff%s|r", LevelLabel, ilevel)
    local specText = format("|cffb8b8b8%s|r", spec)
    if weaponLevel and weaponLevel > 0 and TinyInspectDB.EnableMouseWeaponLevel then
        ilvlText = ilvlText .. format(" (%s)", weaponLevel)
    end
    
    -- 优先直接检查 GameTooltip（包含 AddDoubleLine 添加的行）
    local lineIndex = FindLineInGameTooltip(LevelLabel)
    -- 如果找不到，再检查 tooltipData（用于 ProcessInfo 场景）
    if not lineIndex and tooltipData then
        lineIndex = FindLineInTooltipData(tooltipData, LevelLabel)
    end
    
    if lineIndex then
        local leftLine = _G[GameTooltip:GetName() .. "TextLeft" .. lineIndex]
        local rightLine = _G[GameTooltip:GetName() .. "TextRight" .. lineIndex]
        if leftLine then leftLine:SetText(ilvlText) end
        if rightLine then rightLine:SetText(specText) end
    else
        GameTooltip:AddDoubleLine(ilvlText, specText)
    end
    GameTooltip:Show()
end

-- 觸發觀察
if GameTooltip.ProcessInfo then
    hooksecurefunc(GameTooltip, "ProcessInfo", function(self, info)
        if not info or not info.tooltipData then return end
        local tooltipData = info.tooltipData
        if issecretvalue(tooltipData.type) then return end
        if tooltipData.type ~= 2 then return end

        if TinyInspectDB and (TinyInspectDB.EnableMouseItemLevel or TinyInspectDB.EnableMouseSpecialization) then
            local _, unit = self:GetUnit()
            if not unit then return end
            
            -- 只处理玩家单位，跳过 NPC/怪物
            if not SafeUnitAPI.IsPlayer(unit) then return end
            
            local hp = SafeUnitAPI.HealthMax(unit)
            local data = GetInspectInfo(unit, nil, hp)
            if data and (not hp or data.hp == hp) and data.ilevel > 0 then
                return AppendToGameTooltip(tooltipData.guid, floor(data.ilevel), data.spec, data.weaponLevel, tooltipData)
            end
            if not SafeUnitAPI.CanInspect(unit) or not SafeUnitAPI.IsVisible(unit) then return end
            local inspecting = GetInspecting()
            if inspecting then
                if inspecting.guid ~= tooltipData.guid then
                    return AppendToGameTooltip(tooltipData.guid, "n/a", nil, nil, tooltipData)
                else
                    return AppendToGameTooltip(tooltipData.guid, "......", nil, nil, tooltipData)
                end
            end
            ClearInspectPlayer()
            SafeUnitAPI.NotifyInspect(unit)
            AppendToGameTooltip(tooltipData.guid, "...", nil, nil, tooltipData)
        end
    end)
end

-- @see InspectCore.lua
LibEvent:attachTrigger("UNIT_INSPECT_READY", function(self, data)
    if TinyInspectDB and not TinyInspectDB.EnableMouseItemLevel then return end
    local mouseoverGuid = SafeUnitAPI.GUID("mouseover")
    if mouseoverGuid and data.guid == mouseoverGuid then
        -- 不传入 tooltipData，让函数直接检查 GameTooltip 以避免重复行
        AppendToGameTooltip(data.guid, floor(data.ilevel), data.spec, data.weaponLevel, nil)
    end
end)
