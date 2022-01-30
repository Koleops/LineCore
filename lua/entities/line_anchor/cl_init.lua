include("shared.lua")

/* ------------------------------ Functions ------------------------------ */

local LineIndex = {} 
local LineLink = {}

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

/* ------------------------------ Entity ------------------------------ */

function ENT:Initialize()
    local expression2_index = self:GetExpression2_index()
    LineIndex[expression2_index] = LineIndex[expression2_index] or {}
    LineIndex[expression2_index][self:GetEntity_index()] = self
end

function ENT:OnRemove()
    local expression2_index = self:GetExpression2_index()
    local index = self:GetEntity_index()

    if LineLink[expression2_index] then
        for uuid,_ in pairs(LineLink[expression2_index]) do
            local x, y = SzudzikUnpair(uuid)

            if x == index or y == index then
                LineLink[expression2_index][uuid] = nil
            end
        end
    end

    if not LineIndex[expression2_index] then return end
    LineIndex[expression2_index][index] = nil
end

/* ------------------------------ Network ------------------------------ */

net.Receive("LineCoreSync", function()
    if net.ReadBool() then 
        local count = 0
        for _,lines in pairs(LineLink) do
            count = count + table.Count(lines)
        end
        if net.ReadUInt(14) != count then
            print("BAD WOLF")
            net.Start("LineCoreSync")
            net.SendToServer()
        end
        return
    end

    local len = net.ReadUInt(16)
    LineLink = util.JSONToTable(util.Decompress(net.ReadData(len)))
end)

net.Receive("LineCoreClean", function()
    LineLink[net.ReadUInt(14)] = nil
end)

net.Receive("LineCoreCreateLine", function()
    local len = net.ReadUInt(16)
    local data = net.ReadData(len)
    data = util.JSONToTable(util.Decompress(data))
    
    for expression2_index,__ in pairs(data) do
        LineLink[expression2_index] = LineLink[expression2_index] or {}
        for _,w in pairs(__) do
            local index, index2 = SzudzikUnpair(w.uuid) 

            LineLink[expression2_index][w.uuid] = {
                color = w.color or nil,
                zbuffer = w.zbuffer or nil
            }                
        end
    end
end)

net.Receive("LineCoreRemoveLine", function()
    local expression2_index = net.ReadUInt(14)
    if not LineLink[expression2_index] then return end
    local uuid = net.ReadUInt(32)
    LineLink[expression2_index][uuid] = nil
end)

net.Receive("LineCoreSetColor", function()
    local expression2_index = net.ReadUInt(14)
    if not LineLink[expression2_index] then return end
    local uuid = net.ReadUInt(32)   
    if not LineLink[expression2_index][uuid] then return end
    LineLink[expression2_index][uuid].color = net.ReadColor(false)
end)

/* ------------------------------ Render ------------------------------ */

hook.Add("PostDrawOpaqueRenderables", "LineCoreHook", function()
    for _, lines in pairs(LineLink) do
        if not LineIndex[_] then continue end
        for uuid, data in pairs(lines) do
            local index, index2 = SzudzikUnpair(uuid)
            local ent, ent2 = LineIndex[_][index], LineIndex[_][index2]
            if not ent or not ent2 then continue end
            render.DrawLine(ent:GetPos(), ent2:GetPos(), data.color or Color(255, 255, 255), not tobool(data.zbuffer))
        end
    end
end)