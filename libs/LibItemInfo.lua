
---------------------------------
-- 物品信息庫 Author: M
---------------------------------

local MAJOR, MINOR = "LibItemInfo.7000", 6
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local locale = GetLocale()

--物品等級匹配規則
local ItemLevelPattern = gsub(ITEM_LEVEL, "%%d", "(%%d+)")
local ItemLevelPlusPat = gsub(ITEM_LEVEL_PLUS, "%%d%+", "(%%d+%%+)")

--物品是否已經本地化
function lib:HasLocalCached(item)
    if (not item or item == "" or item == "0") then return true end
    if (tonumber(item)) then
        return select(10, C_Item.GetItemInfo(tonumber(item)))
    else
        local id = string.match(item, "item:(%d+):")
        return self:HasLocalCached(id)
    end
end

--獲取TIP中的屬性信息 (zhTW|zhCN|enUS)
function lib:GetStatsViaTooltip(tooltipData, stats)
    if (type(stats) == "table") then
        local text, r, g, b
        for _, lineData in ipairs(tooltipData.lines) do
            text = lineData.leftText or ""
            r, g, b = lineData.leftColor:GetRGB()
            for statValue, statName in string.gmatch(text, "%+([0-9,]+)([^%+%|]+)") do
                statName = strtrim(statName)
                statName = statName:gsub("與$", "") --zhTW
                statName = statName:gsub("和$", "") --zhTW
                statName = statName:gsub("，", "") --zhCN
                statName = statName:gsub("%s*$", "") --enUS
                statValue = statValue:gsub(",", "")
                statValue = tonumber(statValue) or 0
                if (not stats[statName]) then
                    stats[statName] = { value = statValue, r = r, g = g, b = b }
                else
                    stats[statName].value = stats[statName].value + statValue
                    if (g > stats[statName].g) then
                        stats[statName].r = r
                        stats[statName].g = g
                        stats[statName].b = b
                    end
                end
            end
        end
    end
    return stats
end

-- koKR
if (locale == "koKR") then
    function lib:GetStatsViaTooltip(tooltipData, stats)
        if (type(stats) == "table") then
            local text, r, g, b
            for _, lineData in ipairs(tooltipData.lines) do
                text = lineData.leftText or ""
                r, g, b = lineData.leftColor:GetRGB()
                for statName, statValue in string.gmatch(text, "([^%+]+)%+([0-9,]+)") do
                    statName = statName:gsub("|c%x%x%x%x%x%x%x%x", "")
                    statName = statName:gsub(".-:", "")
                    statName = strtrim(statName)
                    statName = statName:gsub("%s*/%s*", "")
                    statValue = statValue:gsub(",", "")
                    statValue = tonumber(statValue) or 0
                    if (not stats[statName]) then
                        stats[statName] = { value = statValue, r = r, g = g, b = b }
                    else
                        stats[statName].value = stats[statName].value + statValue
                        if (g > stats[statName].g) then
                            stats[statName].r = r
                            stats[statName].g = g
                            stats[statName].b = b
                        end
                    end
                end
            end
        end
        return stats
    end
end


--獲取物品實際等級信息通過Tooltip
function lib:GetItemInfoViaTooltip(link, tooltipData, stats, withoutExtra)
    if (not link or link == "" or not tooltipData) then
        return 0, 0
    end
    if (not string.match(link, "item:%d+:")) then
        return 1, -1
    end
    if (not self:HasLocalCached(link)) then
        return 1, 0
    end
    local text, level
    for _, lineData in ipairs(tooltipData.lines) do
        text = lineData.leftText
        level = text and string.match(text, ItemLevelPattern)
        if (level) then break end
        level = text and string.match(text, ItemLevelPlusPat)
        if (level) then break end
    end
    self:GetStatsViaTooltip(tooltipData, stats)
    if (level and string.find(level, "+")) then else
        level = tonumber(level) or 0
    end
    if (withoutExtra) then
        return 0, level
    else
        return 0, level, C_Item.GetItemInfo(link)
    end
end

--獲取物品實際等級信息
function lib:GetItemInfo(link, stats, withoutExtra)
    local tooltipData = C_TooltipInfo.GetHyperlink(link, nil, nil, true)
    return self:GetItemInfoViaTooltip(link, tooltipData, stats, withoutExtra)
end

--獲取容器裏物品裝備等級
function lib:GetContainerItemLevel(pid, id)
    if (pid < 0) then
        local link = C_Container.GetContainerItemLink(pid, id)
        return self:GetItemInfo(link)
    end
    local text, level
    if (pid and id) then
        local tooltipData = C_TooltipInfo.GetBagItem(pid, id)
        if (tooltipData) then
            for _, lineData in ipairs(tooltipData.lines) do
                text = lineData.leftText
                level = text and string.match(text, ItemLevelPattern)
                if (level) then break end
            end
        end
    end
    return 0, tonumber(level) or 0
end

--獲取UNIT物品實際等級信息
function lib:GetUnitItemInfo(unit, index, stats)
    if (not UnitExists(unit)) then return 1, -1 end  --C_PaperDollInfo.GetInspectItemLevel
    local link = GetInventoryItemLink(unit, index)
    local tooltipData = C_TooltipInfo.GetInventoryItem(unit, index)
    if (not link or link == "" or not tooltipData) then
        return 0, 0
    end
    if (not self:HasLocalCached(link)) then
        return 1, 0
    end
    local text, level
    for _, lineData in ipairs(tooltipData.lines) do
        text = lineData.leftText
        level = text and string.match(text, ItemLevelPattern)
        if (level) then break end
    end
    self:GetStatsViaTooltip(tooltipData, stats)
    if (string.match(link, "item:(%d+):")) then
        return 0, tonumber(level) or 0, C_Item.GetItemInfo(link)
    else
        local lineData = tooltipData.lines[1]
        local name = lineData.leftText and lineData.leftColor:WrapTextInColorCode(lineData.leftText) or ""
        return 0, tonumber(level) or 0, name
    end
end

--獲取UNIT的裝備等級
--@return unknownCount, 平均装等, 装等总和, 最大武器等级, 是否神器, 最大装等
function lib:GetUnitItemLevel(unit, stats)
    local total, counts, maxlevel = 0, 0, 0
    local _, count, level
    for i = 1, 15 do
        if (i ~= 4) then
            count, level = self:GetUnitItemInfo(unit, i, stats)
            total = total + level
            counts = counts + count
            maxlevel = max(maxlevel, level)
        end
    end
    local mcount, mlevel, mquality, mslot, ocount, olevel, oquality, oslot
    mcount, mlevel, _, _, mquality, _, _, _, _, _, mslot = self:GetUnitItemInfo(unit, 16, stats)
    ocount, olevel, _, _, oquality, _, _, _, _, _, oslot = self:GetUnitItemInfo(unit, 17, stats)
    counts = counts + mcount + ocount
    if (mquality == 6 or oquality == 6) then
        total = total + max(mlevel, olevel) * 2
    elseif (oslot == "INVTYPE_2HWEAPON" or mslot == "INVTYPE_2HWEAPON" or mslot == "INVTYPE_RANGED" or mslot == "INVTYPE_RANGEDRIGHT") then 
        total = total + max(mlevel, olevel) * 2
    else
        total = total + mlevel + olevel
    end
    maxlevel = max(maxlevel, mlevel, olevel)
    return counts, total/max(16-counts,1), total, max(mlevel,olevel), (mquality == 6 or oquality == 6), maxlevel
end
