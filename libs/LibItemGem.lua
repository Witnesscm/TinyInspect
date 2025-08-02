
-------------------------------------
-- 物品寶石庫 Author: M
-------------------------------------

local MAJOR, MINOR = "LibItemGem.7000", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

function lib:GetItemGemInfo(ItemLink)
    local info = {}
    local stats = C_Item.GetItemStats(ItemLink)
    for key, num in pairs(stats) do
        if (string.find(key, "EMPTY_SOCKET_")) then
            for i = 1, num do
                table.insert(info, { name = _G[key] or EMPTY, link = nil })
            end
        end
    end
    local name, link
    for i = 1, 4 do
        name, link = C_Item.GetItemGem(ItemLink, i)
        if (link) then
            if (info[i]) then
                info[i].name = name
                info[i].link = link
            else
                table.insert(info, { name = name, link = link })
            end
        end
    end
    return #info, info
end
