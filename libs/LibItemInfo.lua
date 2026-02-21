
---------------------------------
-- 物品信息庫 Author: M
---------------------------------

local MAJOR, MINOR = "LibItemInfo.7000", 6
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local locale = GetLocale()

--物品等級匹配規則
local ItemLevelPattern = gsub(ITEM_LEVEL, "%%d", "(%%d+)")
local ItemLevelAltPattern = gsub(ITEM_LEVEL_ALT, "%%d(%s?)%(%%d%)", "%%d+%1%%((%%d+)%%)")

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

function lib:GetItemLevelViaTooltip(tooltipData, link)
    if not tooltipData then
        return 0
    end

    local firstLine = tooltipData.lines[1]
    local firstText = firstLine and firstLine.leftText
    if firstText == RETRIEVING_ITEM_INFO then
        return -1
    end

    local itemLevel
    for i = 2, 5 do
        local line = tooltipData.lines[i]
        if line then
            local text = line.leftText
            local match = (text and text ~= "") and (strmatch(text, ItemLevelAltPattern) or strmatch(text, ItemLevelPattern))
            if match then
                itemLevel = tonumber(match)
            end
        end
    end

    if not itemLevel and link then
        itemLevel = C_Item.GetDetailedItemLevelInfo(link)
    end

    return itemLevel or 0
end

--獲取物品實際等級信息
function lib:GetItemInfo(link, stats, withoutExtra)
    local tooltipData = link and C_TooltipInfo.GetHyperlink(link, nil, nil, true)
    if not tooltipData then
        return 0, 0
    end

    local level = self:GetItemLevelViaTooltip(tooltipData, link)
    if level == -1 then
        return 1, 0
    end

    self:GetStatsViaTooltip(tooltipData, stats)

    if withoutExtra then
        return 0, level
    else
        return 0, level, C_Item.GetItemInfo(link)
    end
end

--獲取容器裏物品裝備等級
function lib:GetContainerItemLevel(pid, id)
    if not pid or not id then
        return 0
    end

    local link = C_Container.GetContainerItemLink(pid, id)
    local tooltipData = C_TooltipInfo.GetBagItem(pid, id)

    return self:GetItemLevelViaTooltip(tooltipData, link)
end

--獲取UNIT物品實際等級信息
function lib:GetUnitItemInfo(unit, index, stats)
    if not UnitExists(unit) then
        return 1, -1
    end

    local link = GetInventoryItemLink(unit, index)
    local tooltipData = C_TooltipInfo.GetInventoryItem(unit, index)
    if not tooltipData then
        return 0, 0
    end

    local level = self:GetItemLevelViaTooltip(tooltipData, link)
    if level == -1 then
        return 1, 0
    end

    self:GetStatsViaTooltip(tooltipData, stats)

    return 0, level, C_Item.GetItemInfo(link)
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
