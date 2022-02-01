E2Lib.RegisterExtension("LineCore", true, "")

local MAX_LINES = CreateConVar("linecore_maxlines", 400, FCVAR_ARCHIVE, "Limit the maximum number of lines an E2 can create", 1)
local MAX_POINTS = CreateConVar("linecore_maxpoints", 80, FCVAR_ARCHIVE, "Limit the maximum of points an E2 can create", 1)

E2Lib.registerConstant("MAX_LINES", MAX_LINES:GetInt())
E2Lib.registerConstant("MAX_POINTS", MAX_POINTS:GetInt())

local IndexDictionnary = {}
local AnchorIndex = {}
local LineLink = {}

local KEY = 0

local function validIndex(...)
    local args = { ... }

    for _,key in ipairs(args) do
        if key % 1 ~= 0 then return false end
    end

    if #args > 1 then
        return args[1] ~= args[2]
    end

    return true
end

local function storeIndex(self, index)
    KEY = KEY + 1
    IndexDictionnary[self] = IndexDictionnary[self] or {}
    IndexDictionnary[self][index] = KEY
    return KEY
end

local function pair(u, v)
    x, y = math.min(u, v), math.max(u, v)
    return x >= y and x^2 + x + y or y^2 + x
end

local function unpair(uuid)
    local sqrtz = math.floor(math.sqrt(uuid))
    local sqz = sqrtz^2
    return (uuid - sqz >= sqrtz and sqrtz or uuid - sqz), (uuid - sqz >= sqrtz and uuid - sqz - sqrtz or sqrtz)
end

-- NETWORK

util.AddNetworkString("LineCoreSync")

timer.Create("LineCoreSync", 45, 0, function()
    local count = 0
    for _,lines in pairs(LineLink) do
        count = count + table.Count(lines)
    end

    net.Start("LineCoreSync")
        net.WriteBool(true)
        net.WriteUInt(count, 14)
    net.Broadcast()
end)

net.Receive("LineCoreSync", function(len, ply)
    local json = util.TableToJSON(LineLink)
    local data = util.Compress(json)

    net.Start("LineCoreSync")
        net.WriteBool(false)
        net.WriteUInt(#data, 16)
        net.WriteData(data)
    net.Send(ply)
end)

-- ENTITY

registerCallback("destruct", function(self)
    if not self.entity then return end
    local chip = self.entity:EntIndex()

    AnchorIndex[chip] = nil
    IndexDictionnary[chip] = nil
    LineLink[chip] = nil
end)

-- POINTCREATE

local function pointSpawn(chip, index, pos, parent)
    AnchorIndex[chip.entity:EntIndex()] = AnchorIndex[chip.entity:EntIndex()] or {}
    local auto_index = storeIndex(chip.entity:EntIndex(), index)

    local ent = ents.Create("line_anchor")
        ent:SetChip(chip.entity)
        ent:SetIndex(auto_index)

        ent:SetPos(pos)
        ent:SetParent(parent)
        ent:SetCreator(chip.player)

        ent:CallOnRemove("LineCorePointDestruct", function(ent, chip, auto_index, index)
            if not IsValid(chip) then return end
            chip = chip:EntIndex()

            if IndexDictionnary[chip] then IndexDictionnary[chip][index] = nil end
            if AnchorIndex[chip] then AnchorIndex[chip][auto_index] = nil end

            if not LineLink[chip] then return end

            for uuid,_ in pairs(LineLink[chip]) do
                local x, y = unpair(uuid)

                if x == auto_index or y == auto_index then
                    LineLink[chip][uuid] = nil
                end
            end
        end, chip.entity, auto_index, index)

        chip.entity:DeleteOnRemove(ent)
    ent:Spawn()

    AnchorIndex[chip.entity:EntIndex()][auto_index] = ent
end

__e2setcost(10)

e2function void pointCreate(index, vector pos)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    IndexDictionnary[chip] = IndexDictionnary[chip] or {}
    if IndexDictionnary[chip][index] then return end
    if table.Count(IndexDictionnary[chip]) >= MAX_POINTS:GetInt() then return end

    pointSpawn(self, index, Vector(pos[1], pos[2], pos[3]))
end

e2function void pointCreate(index, vector pos, entity parent)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    IndexDictionnary[chip] = IndexDictionnary[chip] or {}
    if IndexDictionnary[chip][index] then return end
    if table.Count(IndexDictionnary[chip]) >= MAX_POINTS:GetInt() then return end

    pointSpawn(self, index, Vector(pos[1], pos[2], pos[3]), parent)
end

-- POINTPARENT

__e2setcost(5)

e2function void pointParent(index, entity parent)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] or not IndexDictionnary[chip][index] then return end
    local auto_index = IndexDictionnary[chip][index]

    if not IsValid(parent) then return end

    local ent = AnchorIndex[chip][auto_index]
        if not IsValid(ent) then return end
        ent:SetParent(parent)
end

__e2setcost(5)

e2function void pointUnparent(index)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] or not IndexDictionnary[chip][index] then return end
    local auto_index = IndexDictionnary[chip][index]

    local ent = AnchorIndex[chip][auto_index]
        if not IsValid(ent) then return end
        ent:SetParent()
end

-- POINTPOS

__e2setcost(1)

e2function vector pointGetPos(index)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] or not IndexDictionnary[chip][index] then return end
    local auto_index = IndexDictionnary[chip][index]

    local ent = AnchorIndex[chip][auto_index]
        if not IsValid(ent) then return end
        return ent:GetPos()
end

__e2setcost(5)

e2function vector pointSetPos(index, vector pos)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] or not IndexDictionnary[chip][index] then return end
    local auto_index = IndexDictionnary[chip][index]

    local ent = AnchorIndex[chip][auto_index]
        if not IsValid(ent) then return end
        ent:SetPos(Vector(pos[1], pos[2], pos[3]))
end

-- POINTDELETE

__e2setcost(5)

e2function void pointDelete(index)
    if not validIndex(index) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] then return end
    if not IndexDictionnary[chip][index] then return end

    local auto_index = IndexDictionnary[chip][index]

    local ent = AnchorIndex[chip][auto_index]
        ent:Remove()
end

-- LINECREATE

local Buffer = {}

util.AddNetworkString("LineCoreCreate")

timer.Create("LineCoreBuffer", 1, 0, function()
    if table.IsEmpty(Buffer) then return end
    local tosend = {}

    for chip,lines in pairs(Buffer) do
        if not IndexDictionnary[chip] then goto skip_chip end

        for id, line in pairs(lines) do
            local index, index2 = unpair(id)
            if not IndexDictionnary[chip][index] or not IndexDictionnary[chip][index2] then goto skip_line end

            LineLink[chip] = LineLink[chip] or {}
            if table.Count(LineLink[chip]) >= MAX_LINES:GetInt() then goto skip_line end
            
            tosend[chip] = tosend[chip] or {}

            local x, y = IndexDictionnary[chip][index], IndexDictionnary[chip][index2]
            local uuid = pair(x, y)

            tosend[chip][uuid] = {
                color = line.color or nil,
                zbuffer = line.zbuffer or nil
            }

            LineLink[chip][uuid] = {
                color = line.color or nil,
                zbuffer = line.zbuffer or nil
            }

            ::skip_line::
        end

        ::skip_chip::
    end

    Buffer = {}
    if table.IsEmpty(tosend) then return end

    local json = util.TableToJSON(tosend)
    local data = util.Compress(json)

    net.Start("LineCoreCreate")
        net.WriteUInt(#data, 16)
        net.WriteData(data)
    net.Broadcast()
end)

__e2setcost(3)

e2function void lineCreate(index, index2)
    if not validIndex(index, index2) then return end

    local chip = self.entity:EntIndex()

    Buffer[chip] = Buffer[chip] or {}

    local id = pair(index, index2)
    Buffer[chip][id] = {}
end

__e2setcost(3)

e2function void lineCreate(index, index2, vector color)
    if not validIndex(index, index2) then return end

    local chip = self.entity:EntIndex()

    Buffer[chip] = Buffer[chip] or {}

    local id = pair(index, index2)
    Buffer[chip][id] = {
        color = Color(color[1], color[2], color[3]),
    }
end

__e2setcost(3)

e2function void lineCreate(index, index2, vector color, zbuffer)
    if not validIndex(index, index2) then return end

    local chip = self.entity:EntIndex()

    Buffer[chip] = Buffer[chip] or {}

    local id = pair(index, index2)
    Buffer[chip][id] = {
        color = Color(color[1], color[2], color[3]),
        zbuffer = zbuffer == 0
    }
end

-- LINEDELETE

util.AddNetworkString("LineCoreDelete")

__e2setcost(2)

e2function void lineDelete(index, index2)
    if not validIndex(index, index2) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] then return end
    if not IndexDictionnary[chip][index] or not IndexDictionnary[chip][index2] then return end

    local auto_index, auto_index2 = IndexDictionnary[chip][index], IndexDictionnary[chip][index2]

    local uuid = pair(auto_index, auto_index2)

    if not LineLink[chip] or not LineLink[chip][uuid] then
        if not Buffer[chip] then return end

        local id = pair(index, index2)
        if not Buffer[chip][id] then return end

        Buffer[chip][id] = nil
        return
    end

    net.Start("LineCoreDelete")
        net.WriteUInt(chip, 14)
        net.WriteUInt(uuid, 32)
    net.Broadcast()

    LineLink[chip][uuid] = nil
end

-- LINESETCOLOR

util.AddNetworkString("LineCoreColor")

__e2setcost(1)

e2function void lineSetColor(index, index2, vector color)
    if not validIndex(index, index2) then return end

    local chip = self.entity:EntIndex()

    if not IndexDictionnary[chip] then return end
    if not IndexDictionnary[chip][index] or not IndexDictionnary[chip][index] then return end

    local auto_index, auto_index2 = IndexDictionnary[chip][index], IndexDictionnary[chip][index2]
    local uuid = pair(auto_index, auto_index2)

    if not LineLink[chip] or not LineLink[chip][uuid] then
        if not Buffer[chip] then return end

        local id = pair(index, index2)
        if not Buffer[chip][id] then return end

        Buffer[chip][id].color = Color(color[1], color[2], color[3])
        return
    end

    net.Start("LineCoreColor", true)
        net.WriteUInt(chip, 14)
        net.WriteUInt(uuid, 32)
        net.WriteColor(Color(color[1], color[2], color[3]), false)
    net.Broadcast()

    LineLink[chip][uuid].color = Color(color[1], color[2], color[3])
end

-- SZUDZIK PAIRING

__e2setcost(0)

e2function number pair(index, index2)
    if index < 0 or index % 1 ~= 0 then return end
    if index2 < 0 or index2 % 1 ~= 0  then return end
    return pair(index, index2)
end

e2function array unpair(uuid)
    if uuid % 1 ~= 0 or uuid < 0 then return end
    return {unpair(uuid)}
end

-- CONCOMMAND

concommand.Add("linecore_debug", function()
    PrintTable(AnchorIndex)
    PrintTable(IndexDictionnary)
    PrintTable(LineLink)
end)