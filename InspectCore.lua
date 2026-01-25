
-------------------------------------
-- InspectCore Author: M
-------------------------------------

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local guids, inspecting = {}, false

-------------------------------------
-- SafeUnitAPI: 安全的 unit API 包装器
-- 用于在受保护执行环境中安全调用 unit API
-------------------------------------
local SafeUnitAPI = {}

-- 通用保护包装函数
local function safeCall(func, default)
    local result, success = default, false
    success = pcall(function() result = func() end)
    return success and result or default
end

-- UnitGUID: 返回 guid 或 nil
function SafeUnitAPI.GUID(unit)
    if not unit then return nil end
    return safeCall(function() return UnitGUID(unit) end, nil)
end

-- UnitHealthMax: 返回 hp 或 nil
function SafeUnitAPI.HealthMax(unit)
    if not unit then return nil end
    return safeCall(function() return UnitHealthMax(unit) end, nil)
end

-- UnitName: 返回 name, realm 或 nil, nil
function SafeUnitAPI.Name(unit)
    if not unit then return nil, nil end
    local name, realm = nil, nil
    local success = pcall(function() name, realm = UnitName(unit) end)
    return success and name or nil, success and realm or nil
end

-- UnitClass: 返回 class 或 nil
function SafeUnitAPI.Class(unit)
    if not unit then return nil end
    local class = nil
    local success = pcall(function() class = select(2, UnitClass(unit)) end)
    return success and class or nil
end

-- UnitLevel: 返回 level 或 nil
function SafeUnitAPI.Level(unit)
    if not unit then return nil end
    return safeCall(function() return UnitLevel(unit) end, nil)
end

-- UnitIsPlayer: 返回 true/false
function SafeUnitAPI.IsPlayer(unit)
    if not unit then return false end
    return safeCall(function() return UnitIsPlayer(unit) end, false)
end

-- CanInspect: 返回 true/false
function SafeUnitAPI.CanInspect(unit)
    if not unit then return false end
    return safeCall(function() return CanInspect(unit) end, false)
end

-- UnitIsVisible: 返回 true/false
function SafeUnitAPI.IsVisible(unit)
    if not unit then return false end
    return safeCall(function() return UnitIsVisible(unit) end, false)
end

-- NotifyInspect: 返回是否成功
function SafeUnitAPI.NotifyInspect(unit)
    if not unit then return false end
    local success = false
    pcall(function() NotifyInspect(unit) success = true end)
    return success
end

-- 导出为全局，方便其他文件使用
_G.SafeUnitAPI = SafeUnitAPI

-- Global API
function GetInspectInfo(unit, timelimit, checkhp)
    if not unit then return end
    local guid = SafeUnitAPI.GUID(unit)
    if (not guid or not guids[guid]) then return end
    if (checkhp) then
        local currentHp = SafeUnitAPI.HealthMax(unit)
        if (currentHp and currentHp ~= guids[guid].hp) then return end
    end
    if (not timelimit or timelimit == 0) then
        return guids[guid]
    end
    if (guids[guid].timer > time()-timelimit) then
        return guids[guid]
    end
end

-- Global API
function GetInspecting()
    if (InspectFrame and InspectFrame.unit) then
        local guid = SafeUnitAPI.GUID(InspectFrame.unit)
        if guid then
            return guids[guid] or { inuse = true }
        end
    end
    if (inspecting and inspecting.expired > time()) then
        return inspecting
    end
end

-- Global API @trigger UNIT_REINSPECT_READY
function ReInspect(unit)
    local guid = SafeUnitAPI.GUID(unit)
    if (not guid) then return end
    local data = guids[guid]
    if (not data) then return end
    LibSchedule:AddTask({
        identity  = guid,
        timer     = 0.5,
        elasped   = 0.5,
        expired   = GetTime() + 3,
        data      = data,
        unit      = unit,
        onExecute = function(self)
            local count, ilevel, _, weaponLevel, isArtifact, maxLevel = LibItemInfo:GetUnitItemLevel(self.unit)
            if (ilevel <= 0) then return true end
            if (count == 0 and ilevel > 0) then
                self.data.timer = time()
                self.data.ilevel = ilevel
                self.data.maxLevel = maxLevel
                self.data.weaponLevel = weaponLevel
                self.data.isArtifact = isArtifact
                LibEvent:trigger("UNIT_REINSPECT_READY", self.data)
                return true
            end
        end,
    })
end

-- Global API
function GetInspectSpec(unit)
    local specID, specName
    if (unit == "player") then
        specID = C_SpecializationInfo.GetSpecialization()
        specName = select(2, C_SpecializationInfo.GetSpecializationInfo(specID))
    else
        specID = GetInspectSpecialization(unit)
        if (specID and specID > 0) then
            specName = select(2, GetSpecializationInfoByID(specID))
        end
    end
    return specName or ""
end

-- Clear
hooksecurefunc("ClearInspectPlayer", function()
    inspecting = false
end)

-- @trigger UNIT_INSPECT_STARTED
hooksecurefunc("NotifyInspect", function(unit)
    local guid = SafeUnitAPI.GUID(unit)
    if (not guid) then return end
    local data = guids[guid]
    if (data) then
        data.unit = unit
        data.name, data.realm = SafeUnitAPI.Name(unit)
    else
        data = {
            unit   = unit,
            guid   = guid,
            class  = SafeUnitAPI.Class(unit),
            level  = SafeUnitAPI.Level(unit),
            ilevel = -1,
            spec   = nil,
            hp     = SafeUnitAPI.HealthMax(unit),
            timer  = time(),
        }
        data.name, data.realm = SafeUnitAPI.Name(unit)
        guids[guid] = data
    end
    if (not data.realm) then
        data.realm = GetRealmName()
    end
    data.expired = time() + 3
    inspecting = data
    LibEvent:trigger("UNIT_INSPECT_STARTED", data)
end)

-- @trigger UNIT_INSPECT_READY
LibEvent:attachEvent("INSPECT_READY", function(this, guid)
    if (not guids[guid]) then return end
    LibSchedule:AddTask({
        identity  = guid,
        timer     = 0.1,
        elasped   = 0,
        expired   = GetTime() + 5,
        repeats   = 2,  --重复次数 10.x里GetInventoryItemLink居然有概率返回nil,所以这里扫两次
        data      = guids[guid],
        onTimeout = function(self) inspecting = false end,
        onExecute = function(self)
            local count, ilevel, _, weaponLevel, isArtifact, maxLevel = LibItemInfo:GetUnitItemLevel(self.data.unit)
            if (ilevel <= 0) then return true end
            if (count == 0 and ilevel > 0) then
                --if (UnitIsVisible(self.data.unit) or self.data.ilevel == ilevel) then
                    self.repeats = self.repeats - 1
                    if (self.repeats <= 0) then
                        self.data.timer = time()
                        self.data.name = SafeUnitAPI.Name(self.data.unit)
                        self.data.class = SafeUnitAPI.Class(self.data.unit)
                        self.data.ilevel = ilevel
                        self.data.maxLevel = maxLevel
                        self.data.spec = GetInspectSpec(self.data.unit)
                        self.data.hp = SafeUnitAPI.HealthMax(self.data.unit)
                        self.data.weaponLevel = weaponLevel
                        self.data.isArtifact = isArtifact
                        LibEvent:trigger("UNIT_INSPECT_READY", self.data)
                        inspecting = false
                        return true
                    end
                --else
                --    self.data.ilevel = ilevel
                --    self.data.maxLevel = maxLevel
                --end
            end
        end,
    })
end)
