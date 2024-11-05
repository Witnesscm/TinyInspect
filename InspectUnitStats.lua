
-------------------------------------
-- 觀察目標裝備屬性統計
-- @Author: M
-- @DepandsOn: InspectUnit.lua
-------------------------------------

local locale = GetLocale()

if (locale == "koKR" or locale == "enUS" or locale == "zhCN" or locale == "zhTW") then
else return end

local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local attributesCategory = {
    ITEM_MOD_STRENGTH_SHORT,
    ITEM_MOD_AGILITY_SHORT,
    ITEM_MOD_INTELLECT_SHORT,
    ITEM_MOD_STAMINA_SHORT
}

local enhancementsCategory = {
    ITEM_MOD_CRIT_RATING_SHORT,
    ITEM_MOD_HASTE_RATING_SHORT,
    ITEM_MOD_MASTERY_RATING_SHORT,
    ITEM_MOD_VERSATILITY,
    ITEM_MOD_CR_LIFESTEAL_SHORT,
    ITEM_MOD_CR_AVOIDANCE_SHORT,
    ITEM_MOD_CR_SPEED_SHORT
}

local function GetStatFrame(frame, index)
    if not frame["stat"..index] then
        frame["stat"..index] = CreateFrame("FRAME", nil, frame, "CharacterStatFrameTemplate")
        frame["stat"..index]:EnableMouse(false)
        frame["stat"..index]:SetWidth(197)
        frame["stat"..index]:SetPoint("TOPLEFT", 0, -17*index+13)
        frame["stat"..index].Background:SetVertexColor(0, 0, 0)
        frame["stat"..index].Value:SetPoint("RIGHT", -64, 0)
        frame["stat"..index].Label:SetFontObject(ChatFontNormal)
        frame["stat"..index].Value:SetFontObject(ChatFontNormal)
        frame["stat"..index].PlayerValue = frame["stat"..index]:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        frame["stat"..index].PlayerValue:SetPoint("LEFT", frame["stat"..index], "RIGHT", -54, 0)
    end

    return frame["stat"..index]
end

function ShowInspectItemStatsFrame(frame, unit)
    if (not frame.expandButton) then
        local expandButton = CreateFrame("Button", nil, frame)
        expandButton:SetSize(12, 12)
        expandButton:SetPoint("TOPRIGHT", -5, -5)
        expandButton:SetNormalTexture("Interface\\Cursor\\Item")
        expandButton:GetNormalTexture():SetTexCoord(12/32, 0, 0, 12/32)
        expandButton:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            ToggleFrame(parent.statsFrame)
            if (parent.statsFrame:IsShown()) then
                ShowInspectItemStatsFrame(parent, parent.unit)
            end
        end)
        frame.expandButton = expandButton
    end
    if (not frame.statsFrame) then
        local statsFrame = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
        statsFrame:SetSize(197, 157)
        statsFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -1)
        local mask = statsFrame:CreateTexture()
        mask:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        mask:SetPoint("TOPLEFT", statsFrame, "TOPRIGHT", -58, -3)
        mask:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -3, 2)
        mask:SetBlendMode("ADD")
        --mask:SetGradientAlpha("VERTICAL", 0.1, 0.4, 0.4, 0.8, 0.1, 0.2, 0.2, 0.8)
        mask:SetAlpha(0.2)
        frame.statsFrame = statsFrame
    end
    if (not frame.statsFrame:IsShown()) then return end
    local inspectStats, playerStats = {}, {}
    local _, inspectItemLevel = LibItemInfo:GetUnitItemLevel(unit, inspectStats)
    local _, playerItemLevel  = LibItemInfo:GetUnitItemLevel("player", playerStats)
    local baseInfo = {}
    table.insert(baseInfo, {label = LEVEL, iv = UnitLevel(unit), pv = UnitLevel("player") })
    table.insert(baseInfo, {label = HEALTH, iv = AbbreviateLargeNumbers(UnitHealthMax(unit)), pv = AbbreviateLargeNumbers(UnitHealthMax("player")) })
    table.insert(baseInfo, {label = STAT_AVERAGE_ITEM_LEVEL, iv = format("%.1f",inspectItemLevel), pv = format("%.1f",playerItemLevel) })
    local index = 1
    local stat
    for _, v in pairs(baseInfo) do
        stat = GetStatFrame(frame.statsFrame, index)
        stat.Label:SetText(v.label)
        stat.Label:SetTextColor(0.2, 1, 1)
        stat.Value:SetText(v.iv)
        stat.Value:SetTextColor(0, 0.7, 0.9)
        stat.PlayerValue:SetText(v.pv)
        stat.PlayerValue:SetTextColor(0, 0.7, 0.9)
        stat.Background:SetShown(index%2~=0)
        stat:Show()
        index = index + 1
    end
    for _, k in ipairs(attributesCategory) do
        stat = GetStatFrame(frame.statsFrame, index)
        stat.Label:SetText(k)
        stat.Label:SetTextColor(1, 0.82, 0)
        if inspectStats[k] then
            stat.Value:SetText(inspectStats[k].value)
            stat.Value:SetTextColor(inspectStats[k].r, inspectStats[k].g, inspectStats[k].b)
        else
            stat.Value:SetText("-")
        end
        if playerStats[k] then
            stat.PlayerValue:SetText(playerStats[k].value)
            stat.PlayerValue:SetTextColor(playerStats[k].r, playerStats[k].g, playerStats[k].b)
        else
            stat.PlayerValue:SetText("-")
        end
        stat.Background:SetShown(index%2~=0)
        stat:Show()
        index = index + 1
    end
    for _, k in ipairs(enhancementsCategory) do
        stat = GetStatFrame(frame.statsFrame, index)
        stat.Label:SetText(k)
        stat.Label:SetTextColor(0, 1, 0)
        stat.Value:SetText(inspectStats[k] and inspectStats[k].value or "-")
        stat.Value:SetTextColor(0, 1, 0)
        stat.PlayerValue:SetText(playerStats[k] and playerStats[k].value or "-")
        stat.PlayerValue:SetTextColor(0, 1, 0)
        stat.Background:SetShown(index%2~=0)
        stat:Show()
        index = index + 1
    end
    frame.statsFrame:SetHeight(index*17-10)
    while (frame.statsFrame["stat"..index]) do
        frame.statsFrame["stat"..index]:Hide()
        index = index + 1
    end
end

hooksecurefunc("ShowInspectItemListFrame", function(unit, parent, itemLevel, maxLevel)
    local frame = parent.inspectFrame
    if (not frame) then return end
    if (unit == "player") then return end
    if (TinyInspectDB and not TinyInspectDB.ShowItemStats) then
        if (frame.statsFrame) then frame.statsFrame:Hide() end
        return
    end
    ShowInspectItemStatsFrame(frame, unit)
end)
