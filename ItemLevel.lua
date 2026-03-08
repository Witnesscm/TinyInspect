
-------------------------------------
-- 物品等級顯示 Author: M
-------------------------------------

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local ARMOR = ARMOR or "Armor"
local WEAPON = WEAPON or "Weapon"
local MOUNTS = MOUNTS or "Mount"
local RELICSLOT = RELICSLOT or "Relic"
local ARTIFACT_POWER = ARTIFACT_POWER or "Artifact"
if (GetLocale():sub(1,2) == "zh") then ARTIFACT_POWER = "能量" end

--框架 #category Bag|Bank|Merchant|Trade|GuildBank|Auction|AltEquipment|PaperDoll|Loot
local function GetItemLevelFrame(self, category)
    if (not self.ItemLevelFrame) then
        local fontAdjust = GetLocale():sub(1,2) == "zh" and 0 or -3
        -- local anchor, w, h = self.IconBorder or self, self:GetSize()
        -- local ww, hh = anchor:GetSize()
        -- if (ww == 0 or hh == 0) then
        --     anchor = self.Icon or self.icon or self
        --     w, h = anchor:GetSize()
        -- else
        --     w, h = min(w, ww), min(h, hh)
        -- end
        local anchor = self.IconOverlay or self.Icon or self.icon or self
        self.ItemLevelFrame = CreateFrame("Frame", nil, self)
        --self.ItemLevelFrame:SetScale(max(0.75, h<32 and h/32 or 1))
        self.ItemLevelFrame:SetFrameLevel(self:GetFrameLevel() + 1)
        --self.ItemLevelFrame:SetSize(w, h)
       -- self.ItemLevelFrame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        self.ItemLevelFrame:SetAllPoints(anchor)
        self.ItemLevelFrame.slotString = self.ItemLevelFrame:CreateFontString(nil, "OVERLAY")
        self.ItemLevelFrame.slotString:SetFont(STANDARD_TEXT_FONT, 10+fontAdjust, "OUTLINE")
        self.ItemLevelFrame.slotString:SetPoint("BOTTOMRIGHT", 1, 2)
        self.ItemLevelFrame.slotString:SetTextColor(1, 1, 1)
        self.ItemLevelFrame.slotString:SetJustifyH("RIGHT")
        self.ItemLevelFrame.slotString:SetWidth(30)
        self.ItemLevelFrame.slotString:SetHeight(0)
        self.ItemLevelFrame.levelString = self.ItemLevelFrame:CreateFontString(nil, "OVERLAY")
        self.ItemLevelFrame.levelString:SetFont(STANDARD_TEXT_FONT, 14+fontAdjust, "OUTLINE")
        self.ItemLevelFrame.levelString:SetPoint("TOP")
        self.ItemLevelFrame.levelString:SetTextColor(1, 0.82, 0)
        LibEvent:trigger("ITEMLEVEL_FRAME_CREATED", self.ItemLevelFrame, self)
    end
    if (TinyInspectDB and TinyInspectDB.EnableItemLevel) then
        self.ItemLevelFrame:Show()
        LibEvent:trigger("ITEMLEVEL_FRAME_SHOWN", self.ItemLevelFrame, self, category or "")
    else
        self.ItemLevelFrame:Hide()
    end
    if (category) then
        self.ItemLevelCategory = category
    end
    return self.ItemLevelFrame
end

--設置裝等文字
local function SetItemLevelString(self, text, quality, link)
    if not text then
        self:SetText("")
        return
    end
    if (quality and TinyInspectDB and TinyInspectDB.ShowColoredItemLevelString) then
        local r, g, b, hex = C_Item.GetItemQualityColor(quality)
        text = format("|c%s%s|r", hex, text)
    end
    --腐蚀的物品加个标记
    if (TinyInspectDB and TinyInspectDB.ShowCorruptedMark and link and C_Item.IsCorruptedItem(link)) then
        text = text .. "|cffFF3300★|r"
    end
    self:SetText(text)
end

--設置部位文字
local function GetItemSlotString(equipSlot, classID, subclassID, link, itemID)
    local text = ""
    if (equipSlot and string.find(equipSlot, "INVTYPE_") and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE") then
        text = _G[equipSlot] or ""
    elseif (link and C_Item.IsArtifactPowerItem(link)) then
        text = ARTIFACT_POWER
    elseif (link and C_ItemSocketInfo.IsArtifactRelicItem(link)) then
        text = RELICSLOT
    elseif (classID == Enum.ItemClass.Miscellaneous) then
        if (subclassID == Enum.ItemMiscellaneousSubclass.Mount) then
            text = MOUNTS
        elseif (subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet) then
            text = PET
        elseif (itemID and C_ToyBox.GetToyInfo(itemID)) then
            text = TOY
        end
    end
    return text
end

local function SetItemSlotString(self, slotText)
    self:SetText(TinyInspectDB and TinyInspectDB.ShowItemSlotString and slotText or "")
end

--部分裝備無法一次讀取
local function SetItemLevelScheduled(button, ItemLevelFrame, link)
    local itemID = link and tonumber(strmatch(link, "item:(%d+)"))
    if (not itemID) then return end
    LibSchedule:AddTask({
        identity  = link,
        elasped   = 1,
        expired   = GetTime() + 5,
        frame     = ItemLevelFrame,
        button    = button,
        onExecute = function(self)
            local count, level, _, _, quality, _, _, _, _, _, equipSlot, _, _, classID, subclassID = LibItemInfo:GetItemInfo(self.identity)
            if (count == 0) then
                local levelText = ""
                if level > 1 and quality > Enum.ItemQuality.Common then
                    levelText = level
                end
                SetItemLevelString(self.frame.levelString, levelText, quality)
                local slotText = GetItemSlotString(equipSlot, classID, subclassID, link, itemID)
                SetItemSlotString(self.frame.slotString, slotText)
                self.frame.itemInfo.link = link
                self.frame.itemInfo.level = levelText
                self.frame.itemInfo.quality = quality
                self.frame.itemInfo.slotText = slotText
                return true
            end
        end
    })
end

local iLvlClassIDs = {
    [Enum.ItemClass.Weapon] = true,
    [Enum.ItemClass.Armor] = true,
    [Enum.ItemClass.Gem] = {
        [Enum.ItemGemSubclass.Artifactrelic] = true,
    },
    [Enum.ItemClass.Profession] = true,
    [Enum.ItemClass.Miscellaneous] = {
        [Enum.ItemMiscellaneousSubclass.Junk] = true,
    },
    [Enum.ItemClass.Reagent] = {
        [Enum.ItemReagentSubclass.ContextToken] = true,
    },
}

local function isItemHasLevel(classID, subClassID)
    local entry = iLvlClassIDs[classID]
    if not entry then
        return false
    end

    if entry == true then
        return true
    end

    return subClassID and entry[subClassID] or false
end

--設置物品等級
local function SetItemLevel(self, link, category)
    if not self then return end
    local frame = GetItemLevelFrame(self, category)
    frame.itemInfo = frame.itemInfo or {}

    if frame.itemInfo.link == link then
        SetItemLevelString(frame.levelString, frame.itemInfo.level, frame.itemInfo.quality, link)
        SetItemSlotString(frame.slotString, frame.itemInfo.slotText)
        return
    end

    local levelText, slotText = "", ""
    local _, quality, equipSlot, classID, subclassID

    if link then
        local linkType, id = string.match(link, "|H(%a+):(%d+):.-|h.-|h")
        if linkType == "item" then
            _, _, quality, _, _, _, _, _, equipSlot, _, _, classID, subclassID = C_Item.GetItemInfo(link)

            if isItemHasLevel(classID, subclassID) then
                local count, level = LibItemInfo:GetItemInfo(link, nil, true)
                if count > 0 then
                    SetItemLevelString(frame.levelString, "...")
                    return SetItemLevelScheduled(self, frame, link)
                end

                if level > 1 and quality > Enum.ItemQuality.Common then
                    levelText = level
                end
            end
            slotText = GetItemSlotString(equipSlot, classID, subclassID, link, tonumber(id))
        elseif linkType == "keystone" then
            quality = select(3, C_Item.GetItemInfo(id))
            levelText = strmatch(link, "|Hkeystone:%d+:%d+:(%d+):.-|h.-|h")
        elseif linkType == "battlepet" then
            levelText, quality = strmatch(link, "|Hbattlepet:%d+:(%d+):(%d+):.-|h.-|h")
            slotText = PET
        end
    end

    SetItemLevelString(frame.levelString, levelText, quality, link)
    SetItemSlotString(frame.slotString, slotText)

    frame.itemInfo.link = link
    frame.itemInfo.level = levelText
    frame.itemInfo.quality = quality
    frame.itemInfo.slotText = slotText
end

-- Gem
local socketWatchList = {
	["BLUE"] = true,
	["RED"] = true,
	["YELLOW"] = true,
	["COGWHEEL"] = true,
	["HYDRAULIC"] = true,
	["META"] = true,
	["PRISMATIC"] = true,
	["PUNCHCARDBLUE"] = true,
	["PUNCHCARDRED"] = true,
	["PUNCHCARDYELLOW"] = true,
	["DOMINATION"] = true,
	["PRIMORDIAL"] = true,
}

local function GetSocketTexture(socket, count)
	return strrep("|TInterface\\ItemSocketingFrame\\UI-EmptySocket-"..socket..":0|t", count)
end

local function IsItemHasGem(link)
	local text = ""
	local stats = C_Item.GetItemStats(link)
	if stats then
		for stat, count in pairs(stats) do
			local socket = strmatch(stat, "EMPTY_SOCKET_(%S+)")
			if socket and socketWatchList[socket] then
				if socket == "PRIMORDIAL" then socket = "META" end -- primordial texture is missing, use meta instead, needs review
				text = text..GetSocketTexture(socket, count)
			end
		end
	end
	return text
end

--[[ All ]]
hooksecurefunc("SetItemButtonQuality", function(self, quality, itemIDOrLink, suppressOverlays, isBound)
    if (self.ItemLevelCategory or self.isBag) then return end
    local frame = GetItemLevelFrame(self)
    if (TinyInspectDB and not TinyInspectDB.EnableItemLevelOther) then
        return frame:Hide()
    end
    if (itemIDOrLink and not tonumber(itemIDOrLink)) then
        local link
        --QuestInfo
        if (self.type and self.objectType == "item") then
            link = GetQuestItemLink(self.type, self:GetID())
            if (not link) then
                link = select(2, C_Item.GetItemInfo(itemIDOrLink))
            end
            SetItemLevel(self, link)
        --EncounterJournal
        elseif (self.encounterID and self.link) then
            local itemInfo = C_EncounterJournal.GetLootInfoByIndex(self.index)
            SetItemLevel(self, itemInfo.link or self.link)
        --EmbeddedItemTooltip
        elseif (self.Tooltip) then
            link = select(2, self.Tooltip:GetItem())
            SetItemLevel(self, link)
        else
            SetItemLevel(self, itemIDOrLink)
        end
    else
        SetItemLevelString(frame.levelString)
        SetItemSlotString(frame.slotString)
    end
end)

-- Bag
local function SetContainerItemLevel(self)
    for _, button in self:EnumerateValidItems() do
        SetItemLevel(button, C_Container.GetContainerItemLink(button:GetBagID(), button:GetID()), "Bag")
    end
end

for i = 1, NUM_CONTAINER_FRAMES do
    local ContainerFrame = _G["ContainerFrame"..i]
    if ContainerFrame and ContainerFrame.UpdateItems then
        hooksecurefunc(ContainerFrame, "UpdateItems", SetContainerItemLevel)
    end
end

if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", SetContainerItemLevel)
end

-- Bank
if BankPanelItemButtonMixin then
    hooksecurefunc(BankPanelItemButtonMixin, "Refresh", function(self)
        SetItemLevel(self, self.itemInfo and self.itemInfo.hyperlink, "Bank")
    end)
end

-- Merchant
if MerchantFrameItem_UpdateQuality then
    hooksecurefunc("MerchantFrameItem_UpdateQuality", function(self, link)
        SetItemLevel(self.ItemButton, link, "Merchant")
    end)
end

-- ALT
if (EquipmentFlyout_DisplayButton) then
    hooksecurefunc("EquipmentFlyout_DisplayButton", function(button)
        local location = button.location
        if (not location) then return end
        local locationData = EquipmentManager_GetLocationData(location)
        if (not locationData.isPlayer and not locationData.isBank and not locationData.isBags) then return end
        if (locationData.isBags) then
            local link = C_Container.GetContainerItemLink(locationData.bag, locationData.slot)
            SetItemLevel(button, link, "AltEquipment")
        else
            local link = GetInventoryItemLink("player", locationData.slot)
            SetItemLevel(button, link, "AltEquipment")
        end
    end)
end

-- GuildNews
local GuildNewsItemCache = {}
if GuildNewsButton_SetText then
    hooksecurefunc("GuildNewsButton_SetText", function(button, text_color, text, text1, text2, ...)
        if (not TinyInspectDB or
            not TinyInspectDB.EnableItemLevel or
            not TinyInspectDB.EnableItemLevelGuildNews) then
            return
        end

        if (text2 and type(text2) == "string") then
            local link = string.match(text2, "|H(item:%d+:.-)|h.-|h")
            if (link) then
                local level = GuildNewsItemCache[link] or select(2, LibItemInfo:GetItemInfo(link))
                if (level > 0) then
                    GuildNewsItemCache[link] = level
                    text2 = text2:gsub("(%|Hitem:%d+:.-%|h%[)(.-)(%]%|h)", "%1"..level..":%2%3"..IsItemHasGem(link))
                    button.text:SetFormattedText(text, text1, text2, ...)
                end
            end
        end
    end)
end

-- Others
if InboxFrame_Update then
    hooksecurefunc("InboxFrame_Update", function()
        for i = 1, _G.INBOXITEMS_TO_DISPLAY do
            local button = _G["MailItem" .. i .. "Button"]
            if (button.index and button:IsShown()) then
                local firstItemQuantity = select(14, GetInboxHeaderInfo(button.index))
                if (not firstItemQuantity) then
                    SetItemButtonQuality(button, nil)
                end
            end
        end
    end)
end

if OpenMailFrame_UpdateButtonPositions then
    hooksecurefunc("OpenMailFrame_UpdateButtonPositions", function()
        if (TinyInspectDB and not TinyInspectDB.EnableItemLevelOther) then
            return
        end
        for i = 1, _G.ATTACHMENTS_MAX_RECEIVE do
            local button = _G.OpenMailFrame.OpenMailAttachments[i]
            if HasInboxItem(_G.InboxFrame.openMailID, i) then
                local itemLink = GetInboxItemLink(InboxFrame.openMailID, i)
                SetItemLevel(button, itemLink)
            end
        end
    end)
end

if SendMailFrame_Update then
    hooksecurefunc("SendMailFrame_Update", function()
        if (TinyInspectDB and not TinyInspectDB.EnableItemLevelOther) then
            return
        end
        for i = 1, _G.ATTACHMENTS_MAX_SEND do
            local button = SendMailFrame.SendMailAttachments[i]
            if HasSendMailItem(i) then
                local itemLink = GetSendMailItemLink(i)
                SetItemLevel(button, itemLink)
            end
        end
    end)
end

-------------------
--   PaperDoll  --
-------------------

local function SetPaperDollItemLevel(self, unit)
    if (not self) then return end
    local id = self:GetID()
    local frame = GetItemLevelFrame(self, "PaperDoll")
    if (unit and GetInventoryItemTexture(unit, id)) then
        local _, level, _, link, quality, _, _, _, _, _, equipSlot, _, _, classID, subclassID = LibItemInfo:GetUnitItemInfo(unit, id)
        local itemID = link and tonumber(strmatch(link, "item:(%d+)"))
        SetItemLevelString(frame.levelString, level > 1 and level or "", quality, link)
        SetItemSlotString(frame.slotString, GetItemSlotString(equipSlot, classID, subclassID, link, itemID))
        if (id == 16 or id == 17) then
            local _, mlevel, _, _, mquality = LibItemInfo:GetUnitItemInfo(unit, 16)
            local _, olevel, _, _, oquality = LibItemInfo:GetUnitItemInfo(unit, 17)
            if (mlevel > 0 and olevel > 0 and (mquality == 6 or oquality == 6)) then
                SetItemLevelString(frame.levelString, max(mlevel,olevel), mquality or oquality, link)
            end
        end
    else
        SetItemLevelString(frame.levelString)
        SetItemSlotString(frame.slotString)
    end
    if (unit == "player") then
        SetItemSlotString(frame.slotString)
    end
end

local EquipmentSlots = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger0",
    [12] = "Finger1",
    [13] = "Trinket0",
    [14] = "Trinket1",
    [15] = "Back",
    [16] = "MainHand",
    [17] = "SecondaryHand"
}

PaperDollFrame:HookScript("OnShow", function()
    for _, slot in pairs(EquipmentSlots) do
        SetPaperDollItemLevel(_G["Character"..slot.."Slot"], "player")
    end
end)

LibEvent:attachEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotID)
    if CharacterFrame:IsShown() and EquipmentSlots[slotID] then
        SetPaperDollItemLevel(_G["Character"..EquipmentSlots[slotID].."Slot"], "player")
    end
end)

LibEvent:attachTrigger("UNIT_INSPECT_READY", function(self, data)
    if (InspectFrame and InspectFrame.unit and UnitGUID(InspectFrame.unit) == data.guid) then
        for _, slot in pairs(EquipmentSlots) do
            SetPaperDollItemLevel(_G["Inspect"..slot.."Slot"], InspectFrame.unit)
        end
    end
end)

LibEvent:attachEvent("ADDON_LOADED", function(self, addonName)
    if (addonName == "Blizzard_InspectUI") then
        hooksecurefunc(InspectFrame, "Hide", function()
            for _, slot in pairs(EquipmentSlots) do
                SetPaperDollItemLevel(_G["Inspect"..slot.."Slot"])
            end
        end)
    end
end)

----------------------
--  Chat ItemLevel  --
----------------------

local itemCache = {}
local function ReplaceChatHyperlink(link, linkType, value)
    if not link then return end

    if not itemCache[link] then
        if linkType == "item" then
            local count, level, name, _, quality, _, _, class, subclass, _, equipSlot, _, _, classID, subclassID = LibItemInfo:GetItemInfo(link)
            level = level > 1 and level or ""
            local prefix
            if (equipSlot == "INVTYPE_CLOAK" or equipSlot == "INVTYPE_TRINKET" or equipSlot == "INVTYPE_FINGER" or equipSlot == "INVTYPE_NECK") then
                prefix = format("%s(%s)", level, _G[equipSlot] or equipSlot)
            elseif (equipSlot and string.find(equipSlot, "INVTYPE_") and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE") then
                prefix = format("%s(%s-%s)", level, subclass or "", _G[equipSlot] or equipSlot)
            elseif (class == ARMOR) then
                prefix = format("%s(%s-%s)", level, subclass or "", class)
            elseif (subclass and string.find(subclass, RELICSLOT)) then
                prefix = format("%s(%s)", level, RELICSLOT)
            elseif (classID == Enum.ItemClass.Miscellaneous) then
                if (subclassID == Enum.ItemMiscellaneousSubclass.Mount) then
                    prefix = format("(%s)", MOUNTS)
                elseif (subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet) then
                    prefix = format("(%s)", PET)
                elseif (value and C_ToyBox.GetToyInfo(value)) then
                    prefix = format("(%s)", TOY)
                end
            end
            if prefix then
                local gem = IsItemHasGem(link)
                if (quality == 6 and class == WEAPON) then gem = "" end
                itemCache[link] = gsub(link, "|h%[(.-)%]|h", "|h[" .. prefix .. ":" .. name .. "]|h" .. gem)
            elseif (count == 0) then
                itemCache[link] = link
            end
        elseif linkType == "battlepet" then
            local level = strmatch(link, "|Hbattlepet:%d+:(%d+):%d+:.-|h.-|h") or ""
            local prefix = format("%s(%s)", level, PET)
            itemCache[link] = gsub(link, "|h%[(.-)%]|h", "|h[" .. prefix .. ":%1]|h")
        end
    end
    return itemCache[link]
end

local function filter(self, event, msg, ...)
    if (TinyInspectDB and TinyInspectDB.EnableItemLevel and TinyInspectDB.EnableItemLevelChat) then
        msg = gsub(msg, "(|H([^:]+):(%d+):.-|h.-|h)", ReplaceChatHyperlink)
    end
    return false, msg, ...
end

ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SAY", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_YELL", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_RAID", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_PARTY", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_GUILD", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", filter)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_LOOT", filter)

-- 位置設置
LibEvent:attachTrigger("ITEMLEVEL_FRAME_SHOWN", function(self, frame, parent, category)
    if (TinyInspectDB and not TinyInspectDB["EnableItemLevel"..category]) then
        return frame:Hide()
    end
    if (TinyInspectDB and TinyInspectDB.PaperDollItemLevelOutsideString) then
        return
    end
    local anchorPoint = TinyInspectDB and TinyInspectDB.ItemLevelAnchorPoint
    if (frame.anchorPoint ~= anchorPoint) then
        frame.anchorPoint = anchorPoint
        frame.levelString:ClearAllPoints()
        frame.levelString:SetPoint(anchorPoint or "TOP")
    end
end)

-- OutsideString For PaperDoll ItemLevel
LibEvent:attachTrigger("ITEMLEVEL_FRAME_CREATED", function(self, frame, parent)
    if (TinyInspectDB and TinyInspectDB.PaperDollItemLevelOutsideString) then
        local name = parent:GetName()
        if (name and string.match(name, "^[IC].+Slot$")) then
            local id = parent:GetID()
            frame:ClearAllPoints()
            frame.levelString:ClearAllPoints()
            if (id <= 5 or id == 9 or id == 15 or id == 19) then
                frame:SetPoint("LEFT", parent, "RIGHT", 7, -1)
                frame.levelString:SetPoint("TOPLEFT")
                frame.levelString:SetJustifyH("LEFT")
            elseif (id == 17) then
                frame:SetPoint("LEFT", parent, "RIGHT", 5, 1)
                frame.levelString:SetPoint("TOPLEFT")
                frame.levelString:SetJustifyH("LEFT")
            elseif (id == 16) then
                frame:SetPoint("RIGHT", parent, "LEFT", -5, 1)
                frame.levelString:SetPoint("TOPRIGHT")
                frame.levelString:SetJustifyH("RIGHT")
            else
                frame:SetPoint("RIGHT", parent, "LEFT", -7, -1)
                frame.levelString:SetPoint("TOPRIGHT")
                frame.levelString:SetJustifyH("RIGHT")
            end
        end
    end
end)
