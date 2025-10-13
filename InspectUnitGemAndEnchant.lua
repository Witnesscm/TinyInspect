
-------------------------------------
-- 顯示寶石和附魔信息
-- @Author: M
-- @DepandsOn: InspectUnit.lua
-------------------------------------

local addon, ns = ...

local LibItemGem = LibStub:GetLibrary("LibItemGem.7000")
local LibItemEnchant = LibStub:GetLibrary("LibItemEnchant.7000")

local INVSLOT_SOCKET_ITEMS = {
    [INVSLOT_NECK] = { 213777, 213777 },
    [INVSLOT_FINGER1] = { 213777, 213777 },
    [INVSLOT_FINGER2] = { 213777, 213777 }
}

local PvpItemLevelPattern = gsub(PVP_ITEM_LEVEL_TOOLTIP, "%%d", "(%%d+)")

local function GetPvpItemLevel(link)
    local tooltipData = C_TooltipInfo.GetHyperlink(link, nil, nil, true)
    if not tooltipData then
        return
    end

    local text, level
    for _, lineData in ipairs(tooltipData.lines) do
        text = lineData.leftText
        level = text and string.match(text, PvpItemLevelPattern)
        if (level) then break end
    end
    return tonumber(level)
end

local function GetItemAddableSockets(link, slot, itemLevel)
    local socketItems = INVSLOT_SOCKET_ITEMS[slot]
    if not socketItems then
        return
    end

    if itemLevel < 584 then
        return
    end

    local pvpItemLevel = GetPvpItemLevel(link)
    if pvpItemLevel and pvpItemLevel > 0 then
        return
    end

    local items = {}
    local numSockets = C_Item.GetItemNumSockets(link)
    for i = numSockets + 1, #socketItems do
        tinsert(items, socketItems[i])
    end
    return items
end

local INVSLOT_ENCHANT = {
    [INVSLOT_HEAD] = ns.IsMidnight,
    [INVSLOT_SHOULDER] = ns.IsMidnight,
    [INVSLOT_CHEST] = true,
    [INVSLOT_LEGS] = true,
    [INVSLOT_FEET] = true,
    [INVSLOT_WRIST] = not ns.IsMidnight,
    [INVSLOT_FINGER1] = true,
    [INVSLOT_FINGER2] = true,
    [INVSLOT_BACK] = not ns.IsMidnight,
    [INVSLOT_MAINHAND] = true,
    [INVSLOT_OFFHAND] = true,
}

local function CheckEnchantmentSlot(slotID, quality, classID)
    if INVSLOT_ENCHANT[slotID] then
        if quality == Enum.ItemQuality.Artifact and (slotID == INVSLOT_NECK or slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND) then
            return false
        end
        if slotID == INVSLOT_OFFHAND and classID ~= Enum.ItemClass.Weapon then
            return false
        end
        return true
    end
    return false
end

--創建圖標框架
local function CreateIconFrame(frame, index)
    local icon = CreateFrame("Button", nil, frame)
    icon.index = index
    icon:Hide()
    icon:SetSize(16, 16)
    icon:SetScript("OnEnter", function(self)
        if (self.itemLink) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        elseif (self.spellID) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        elseif (self.title) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.title)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    icon:SetScript("OnDoubleClick", function(self)
        if (self.itemLink or self.title) then
            ChatEdit_ActivateChat(ChatEdit_ChooseBoxForSend())
            ChatEdit_InsertLink(self.itemLink or self.title)
        end
    end)
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetSize(15, 15)
    icon.bg:SetPoint("CENTER")
    icon.bg:SetTexture("Interface\\Masks\\CircleMaskScalable")
    icon.texture = icon:CreateTexture(nil, "BORDER")
    icon.texture:SetSize(12, 12)
    icon.texture:SetPoint("CENTER")
    icon.texture:SetMask("Interface\\Masks\\CircleMaskScalable")
    frame["xicon"..index] = icon
    return frame["xicon"..index]
end

--隱藏所有圖標框架
local function HideAllIconFrame(frame)
    local index = 1
    while (frame["xicon"..index]) do
        frame["xicon"..index].title = nil
        frame["xicon"..index].itemLink = nil
        frame["xicon"..index].spellID = nil
        frame["xicon"..index]:Hide()
        index = index + 1
    end
end

--獲取可用的圖標框架
local function GetIconFrame(frame)
    local index = 1
    while (frame["xicon"..index]) do
        if (not frame["xicon"..index]:IsShown()) then
            return frame["xicon"..index]
        end
        index = index + 1
    end
    return CreateIconFrame(frame, index)
end

-- Credit: ElvUI_WindTools
local function UpdateIconTexture(type, icon, data)
    if type == "itemId" then
        local item = Item:CreateFromItemID(data)
        item:ContinueOnItemLoad(
            function()
                local qualityColor = item:GetItemQualityColor()
                icon.bg:SetVertexColor(qualityColor.r, qualityColor.g, qualityColor.b)
                icon.texture:SetTexture(item:GetItemIcon())
                icon.itemLink = item:GetItemLink()
            end
        )
    elseif type == "itemLink" then
        local item = Item:CreateFromItemLink(data)
        item:ContinueOnItemLoad(
            function()
                local qualityColor = item:GetItemQualityColor()
                icon.bg:SetVertexColor(qualityColor.r, qualityColor.g, qualityColor.b)
                icon.texture:SetTexture(item:GetItemIcon())
                icon.itemLink = item:GetItemLink()
            end
        )
    elseif type == "spellId" then
        local spell = Spell:CreateFromSpellID(data)
        spell:ContinueOnSpellLoad(
            function()
                icon.texture:SetTexture(spell:GetSpellTexture())
                icon.spellID = spell:GetSpellID()
            end
        )
    end
end

--讀取並顯示圖標
local function ShowGemAndEnchant(frame, ItemLink, anchorFrame, itemframe)
    if (not ItemLink) then return 0 end
    local num, info = LibItemGem:GetItemGemInfo(ItemLink)
    local icon
    for i, v in ipairs(info) do
        icon = GetIconFrame(frame)
        if (v.link) then
            UpdateIconTexture("itemLink", icon, v.link)
        else
            icon.bg:SetVertexColor(1, 0.82, 0, 0.5)
            icon.texture:SetTexture("Interface\\Cursor\\Quest")
        end
        icon.title = v.name
        icon.itemLink = v.link
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchorFrame, "RIGHT", i == 1 and 6 or 1, 0)
        icon:Show()
        anchorFrame = icon
    end
    local socketItems = GetItemAddableSockets(ItemLink, itemframe.index, itemframe.level)
    if socketItems then
        for _, socketItemId in ipairs(socketItems) do
            num = num + 1
            icon = GetIconFrame(frame)
            icon.bg:SetVertexColor(1, 0.82, 0, 0.5)
            icon.texture:SetTexture("Interface\\Cursor\\Quest")
            local item = Item:CreateFromItemID(socketItemId)
            item:ContinueOnItemLoad(
                function()
                    icon.itemLink = item:GetItemLink()
                end
            )
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", anchorFrame, "RIGHT", num == 1 and 6 or 1, 0)
            icon:Show()
            anchorFrame = icon
        end
    end
    local enchantItemID, enchantID = LibItemEnchant:GetEnchantItemID(ItemLink)
    local enchantSpellID = LibItemEnchant:GetEnchantSpellID(ItemLink)
    if (enchantItemID) then
        num = num + 1
        icon = GetIconFrame(frame)
        UpdateIconTexture("itemId", icon, enchantItemID)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchorFrame, "RIGHT", num == 1 and 6 or 1, 0)
        icon:Show()
        anchorFrame = icon
    elseif (enchantSpellID) then
        num = num + 1
        icon = GetIconFrame(frame)
        icon.bg:SetVertexColor(1,0.82,0)
        UpdateIconTexture("spellId", icon, enchantSpellID)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchorFrame, "RIGHT", num == 1 and 6 or 1, 0)
        icon:Show()
        anchorFrame = icon
    elseif (enchantID) then
        num = num + 1
        icon = GetIconFrame(frame)
        icon.title = "#" .. enchantID
        icon.bg:SetVertexColor(0.1, 0.1, 0.1)
        icon.texture:SetTexture("Interface\\FriendsFrame\\InformationIcon")
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchorFrame, "RIGHT", num == 1 and 6 or 1, 0)
        icon:Show()
        anchorFrame = icon
    elseif (not enchantID and CheckEnchantmentSlot(itemframe.index, itemframe.quality, itemframe.classID)) then
        num = num + 1
        icon = GetIconFrame(frame)
        icon.title = ENCHANTS..": "..itemframe.slot
        icon.bg:SetVertexColor(1, 0.2, 0.2, 0.6)
        icon.texture:SetTexture("Interface\\Cursor\\Quest")     --QuestRepeatable
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchorFrame, "RIGHT", num == 1 and 6 or 1, 0)
        icon:Show()
        anchorFrame = icon
    end
    return num * 18
end

--功能附着
hooksecurefunc("ShowInspectItemListFrame", function(unit, parent, itemLevel, maxLevel)
    if PlayerIsTimerunning() then return end
    local frame = parent.inspectFrame
    if (not frame) then return end
    if (TinyInspectDB and TinyInspectDB.ShowGemAndEnchant) then
        local i = 1
        local itemframe
        local width, iconWidth = frame:GetWidth(), 0
        HideAllIconFrame(frame)
        while (frame["item"..i]) do
            itemframe = frame["item"..i]
            iconWidth = ShowGemAndEnchant(frame, itemframe.link, itemframe.itemString, itemframe)
            if (width < itemframe.width + iconWidth + 36) then
                width = itemframe.width + iconWidth + 36
            end
            i = i + 1
        end
        if (width > frame:GetWidth()) then
            frame:SetWidth(width)
        end
    else
        HideAllIconFrame(frame)
    end
end)
