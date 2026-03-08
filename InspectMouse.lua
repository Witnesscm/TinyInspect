
-------------------------------------
-- 鼠标装等和天赋 Author: M
-------------------------------------
local _, ns = ...
local T = ns.T

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local tierSlots = { 1, 3, 5, 7, 10 }

local function GetUnitTierSetCount(unit)
    local sets = 0
    if TinyInspectDB and TinyInspectDB.TierSetTable then
        for _, index in ipairs(tierSlots) do
            local setID = select(18, LibItemInfo:GetUnitItemInfo(unit, index))
            if setID and TinyInspectDB.TierSetTable[setID] then
                sets = sets + 1
            end
        end
    end
    return sets
end

local function GetTooltipUnit(self)
    local data = self:GetTooltipData()
    local guid = data and T:NotSecretValue(data.guid) and data.guid
    local mouseover = UnitExists("mouseover") and "mouseover"
    local unit = guid and UnitTokenFromGUID(guid) or mouseover
    return unit, guid
end

local function FindLine(tooltip, keyword)
    local line, text
    for i = 2, tooltip:NumLines() do
        line = _G[tooltip:GetName() .. "TextLeft" .. i]
        text = line:GetText() or ""
        if (text and T:NotSecretValue(text) and string.find(text, keyword)) then
            return line, i, _G[tooltip:GetName() .. "TextRight" .. i]
        end
    end
end

local LevelLabel = STAT_AVERAGE_ITEM_LEVEL .. ": "

local function AppendToGameTooltip(ilevel, spec, weaponLevel, sets)
    if (TinyInspectDB and not TinyInspectDB.EnableMouseItemLevel) then return end
    spec = spec or ""
    if (TinyInspectDB and not TinyInspectDB.EnableMouseSpecialization) then spec = "" end
    local ilvlLine, _, lineRight = FindLine(GameTooltip, LevelLabel)
    local ilvlText = format("%s|cffffffff%s|r", LevelLabel, ilevel)
    local specText = format("|cffb8b8b8%s|r", spec)
    if (sets and sets > 0 and TinyInspectDB.EnableMouseTierSet) then
        ilvlText = ilvlText .. (ns.formatSets[sets] or "")
    end
    if (weaponLevel and weaponLevel > 0 and TinyInspectDB.EnableMouseWeaponLevel) then
        ilvlText = ilvlText .. format(" (%s)", weaponLevel)
    end
    if (ilvlLine) then
        ilvlLine:SetText(ilvlText)
        lineRight:SetText(specText)
    else
        GameTooltip:AddDoubleLine(ilvlText, specText)
    end
    GameTooltip:Show()
end

local function OnTooltipSetUnit(self)
    if self:IsForbidden() or self ~= GameTooltip then return end

    local unit, guid = GetTooltipUnit(self)
    if not unit or not CanInspect(unit) then return end

    local data = GetInspectInfo(unit, nil, true)
    if (data and data.ilevel > 0) then
        local sets = GetUnitTierSetCount(unit)
        return AppendToGameTooltip(format("%.1f", data.ilevel), data.spec, data.weaponLevel, sets)
    end
    local inspecting = GetInspecting()
    if (inspecting) then
        if (inspecting.guid ~= guid) then
            return AppendToGameTooltip("n/a")
        else
            return AppendToGameTooltip("......")
        end
    end
    ClearInspectPlayer()
    NotifyInspect(unit)
    AppendToGameTooltip("...")
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetUnit)

--@see InspectCore.lua
LibEvent:attachTrigger("UNIT_INSPECT_READY", function(self, data)
    if (TinyInspectDB and not TinyInspectDB.EnableMouseItemLevel) then return end
    local unit = "mouseover"
    if (T:UnitExists(unit) and data.guid == UnitGUID(unit)) then
        local sets = GetUnitTierSetCount(unit)
        AppendToGameTooltip(format("%.1f", data.ilevel), data.spec, data.weaponLevel, sets)
    end
end)