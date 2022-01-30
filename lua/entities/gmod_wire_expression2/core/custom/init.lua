E2Lib.RegisterExtension("LineCore", true, "")

CreateConVar("linecore_maxlines", 400, FCVAR_ARCHIVE, "Limit the maximum number of lines an E2 can create", 1)
CreateConVar("linecore_maxpoints", 80, FCVAR_ARCHIVE, "Limit the maximum of points an E2 can create", 1)

E2Lib.registerConstant("MAX_LINES", GetConVar("linecore_maxlines"):GetInt() )
E2Lib.registerConstant("MAX_POINTS", GetConVar("linecore_maxpoints"):GetInt() )

/* ------------------------------ Functions ------------------------------ */

local LineIndex = {}
local IndexDictionnary = {}
local LineLink = {}

local AutoIndex = 0

local function StoreIndex(self, index)
    AutoIndex = AutoIndex + 1
    IndexDictionnary[self][index] = AutoIndex
    return AutoIndex
end

local function SzudzikPair(x, y)
    x, y = math.min(x, y), math.max(x, y)
    return x >= y and x^2 + x + y or y^2 + x
end

local function SzudzikUnpair(z)
    local sqrtz = math.floor(math.sqrt(z))
    local sqz = sqrtz^2

    local x = z - sqz >= sqrtz and sqrtz or z - sqz
    local y = z - sqz >= sqrtz and z - sqz - sqrtz or sqrtz

    return x, y
end

local function canCreatePoints(self)
    return table.Count(IndexDictionnary[self]) < GetConVar("linecore_maxpoints"):GetInt()
end

local function canCreateLines(self)
    return table.Count(LineLink[self]) < GetConVar("linecore_maxlines"):GetInt()
end

/* ------------------------------ Network ------------------------------ */

util.AddNetworkString("LineCoreSync")

timer.Create("LineCoreSync", 10, 0, function()
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
    local compressed = util.Compress(util.TableToJSON(LineLink))

    net.Start("LineCoreSync")
        net.WriteBool(false)
        net.WriteUInt(#compressed, 16)
        net.WriteData(compressed)
    net.Send(ply)
end)


/* ------------------------------ OnRemove() ------------------------------ */

util.AddNetworkString("LineCoreClean")

registerCallback("destruct", function(self)
    local expression2_index = self.entity:EntIndex()

    if LineIndex[expression2_index] then 
        for _,ent in pairs(LineIndex[expression2_index]) do
            ent:Remove()
        end
    end

    LineIndex[expression2_index] = nil
    LineLink[expression2_index] = nil
    IndexDictionnary[expression2_index] = nil

    net.Start("LineCoreClean")
        net.WriteUInt(expression2_index, 14)
    net.Broadcast()
end)

/* ------------------------------ createPoint() ------------------------------ */

__e2setcost(0)

e2function void createPoint(index, vector pos)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    IndexDictionnary[expression2_index] = IndexDictionnary[expression2_index] or {}
    if not canCreatePoints(expression2_index) then return end
    if IndexDictionnary[expression2_index][index] then return end
    local pos = Vector(pos[1], pos[2], pos[3])
    local auto_index = StoreIndex(expression2_index, index)
    local ent = ents.Create("line_anchor")
        ent:SetExpression2_index(expression2_index)
        ent:SetEntity_index(auto_index)
        ent:SetPos(pos)
        ent:SetCreator(self.player)
        ent:Spawn()
    LineIndex[expression2_index] = LineIndex[expression2_index] or {}
    LineIndex[expression2_index][auto_index] = ent
end

e2function void createPoint(index, vector pos, entity parent)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    IndexDictionnary[expression2_index] = IndexDictionnary[expression2_index] or {}
    if not canCreatePoints(expression2_index) then return end
    if IndexDictionnary[expression2_index][index] then return end
    if not IsValid(parent) then return end
    local pos = Vector(pos[1], pos[2], pos[3])
    local auto_index = StoreIndex(expression2_index, index)
    local ent = ents.Create("line_anchor")
        ent:SetExpression2_index(expression2_index)
        ent:SetEntity_index(auto_index)
        ent:SetPos(pos)
        ent:SetParent(parent)
        ent:SetCreator(self.player)
        ent:Spawn()
    LineIndex[expression2_index] = LineIndex[expression2_index] or {}
    LineIndex[expression2_index][auto_index] = ent
end

/* ------------------------------ parentPoint() ------------------------------ */

__e2setcost(0)

e2function void parentPoint(index, entity parent)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] then return end
    if not IsValid(parent) then return end
    local auto_index = IndexDictionnary[expression2_index][index]
    local ent = LineIndex[expression2_index][auto_index]
        ent:SetParent(parent)
end

e2function void unparentPoint(index)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] then return end
    local auto_index = IndexDictionnary[expression2_index][index]
    local ent = LineIndex[expression2_index][auto_index]
        ent:SetParent(NULL)
end

/* ------------------------------ setPointPos() ------------------------------ */

__e2setcost(0)

e2function void pointSetPos(index, vector pos)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] then return end
    local auto_index = IndexDictionnary[expression2_index][index]
    local pos = Vector(pos[1], pos[2], pos[3])
    local ent = LineIndex[expression2_index][auto_index]  
        ent:SetPos(pos)
end

/* ------------------------------ getPointPos() ------------------------------ */

__e2setcost(0)

e2function vector pointGetPos(index)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] then return end
    local auto_index = IndexDictionnary[expression2_index][index]
    local ent = LineIndex[expression2_index][auto_index]  
    return ent:GetPos()
end

/* ------------------------------ removePoint() ------------------------------ */

__e2setcost(0)

e2function void removePoint(index)
    if index != math.floor(index) then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] then return end
    local auto_index = IndexDictionnary[expression2_index][index]
    if LineIndex[expression2_index][auto_index] then
        local ent = LineIndex[expression2_index][auto_index]
            ent:Remove()
    end
    IndexDictionnary[expression2_index][index] = nil
    LineIndex[expression2_index][auto_index] = nil

    if not LineLink[expression2_index] then return end

    for uuid,_ in pairs(LineLink[expression2_index]) do
        local x, y = SzudzikUnpair(uuid)

        if x == auto_index or y == auto_index then
            LineLink[expression2_index][uuid] = nil
        end
    end
end

/* ------------------------------ createLine() ------------------------------ */

local Buffer = {}

util.AddNetworkString("LineCoreCreateLine")

timer.Create("LineCoreBuffer", 1, 0, function() 
    if table.IsEmpty(Buffer) then return end
    local data = {}
    for expression2_index,__ in pairs(Buffer) do
        if not IndexDictionnary[expression2_index] then continue end
        for _,w in pairs(__) do 
            if not canCreateLines(expression2_index) then return end
            local auto_index, auto_index2 = IndexDictionnary[expression2_index][w.index], IndexDictionnary[expression2_index][w.index2]  
            if not auto_index or not auto_index2 then return end     
            local uuid = SzudzikPair(auto_index, auto_index2)
            data[expression2_index] = data[expression2_index] or {}
            table.insert(data[expression2_index], {
                uuid = uuid,
                color = w.color or nil,
                zbuffer = w.zbuffer or nil
            })

            LineLink[expression2_index] = LineLink[expression2_index] or {}
            LineLink[expression2_index][uuid] = {
                color = w.color or nil,
                zbuffer = w.zbuffer or nil
            }
        end
    end
    Buffer = {}
    if table.IsEmpty(data) then return end
    local compressed = util.Compress(util.TableToJSON(data))
    net.Start("LineCoreCreateLine")
        net.WriteUInt(#compressed, 16)
        net.WriteData(compressed)
    net.Broadcast()
end)

__e2setcost(0)

e2function void createLine(index, index2)
    if index != math.floor(index) or index2 != math.floor(index2) or index == index2 then return end
    local expression2_index = self.entity:EntIndex()
    Buffer[expression2_index] = Buffer[expression2_index] or {}
    table.insert(Buffer[expression2_index], {
        index = index,
        index2 = index2,
    })
end

e2function void createLine(index, index2, vector color, zbuffer)
    if index != math.floor(index) or index2 != math.floor(index2) or index == index2 then return end
    local expression2_index = self.entity:EntIndex()
    Buffer[expression2_index] = Buffer[expression2_index] or {}
    color = Color(color[1], color[2], color[3])
    zbuffer = zbuffer == 0
    table.insert(Buffer[expression2_index], {
        index = index,
        index2 = index2,
        color = color,
        zbuffer = zbuffer
    })
end

/* ------------------------------ removeLine() ------------------------------ */

util.AddNetworkString("LineCoreRemoveLine")
__e2setcost(0)

e2function void removeLine(index, index2)
    if index != math.floor(index) or index2 != math.floor(index2) or index == index2 then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] or not LineLink[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] or not IndexDictionnary[expression2_index][index2] then return end
    local auto_index, auto_index2 = IndexDictionnary[expression2_index][index], IndexDictionnary[expression2_index][index2]
    local uuid = SzudzikPair(auto_index, auto_index2)
    net.Start("LineCoreRemoveLine")
        net.WriteUInt(expression2_index, 14)
        net.WriteUInt(uuid, 32)
    net.Broadcast()
    LineLink[expression2_index][uuid] = nil
end

/* ------------------------------ setLineColor() ------------------------------ */

util.AddNetworkString("LineCoreSetColor")
__e2setcost(0)

e2function void lineSetColor(index, index2, vector color)
    if index != math.floor(index) or index2 != math.floor(index2) or index == index2 then return end
    local expression2_index = self.entity:EntIndex()
    if not IndexDictionnary[expression2_index] or not LineLink[expression2_index] then return end
    if not IndexDictionnary[expression2_index][index] or not IndexDictionnary[expression2_index][index2] then return end
    local auto_index, auto_index2 = IndexDictionnary[expression2_index][index], IndexDictionnary[expression2_index][index2]
    local uuid = SzudzikPair(auto_index, auto_index2)
    if not LineLink[expression2_index][uuid] then return end
    color = Color(color[1], color[2], color[3])
    if color == (LineLink[expression2_index][uuid].color or Color(255, 255, 255)) then return end

    net.Start("LineCoreSetColor", true)
        net.WriteUInt(expression2_index, 14)
        net.WriteUInt(uuid, 32)
        net.WriteColor(color, false)
        print(net.BytesWritten())
    net.Broadcast()

    LineLink[expression2_index][uuid].color = color
end

/* ------------------------------ setLineColor() ------------------------------ */

__e2setcost(0)

e2function void lineClear()
    local expression2_index = self.entity:EntIndex()
    LineLink[expression2_index] = nil
 
    net.Start("LineCoreClean")
        net.WriteUInt(expression2_index, 14)
    net.Broadcast()
end
