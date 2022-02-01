include("shared.lua")

local AnchorIndex = {}
local LineLink = {}

local function pair(x, y)
    x, y = math.min(x, y), math.max(x, y)
    return x >= y and x^2 + x + y or y^2 + x
end

local function unpair(uuid)
    local sqrtz = math.floor(math.sqrt(uuid))
    local sqz = sqrtz^2
    return (uuid - sqz >= sqrtz and sqrtz or uuid - sqz), (uuid - sqz >= sqrtz and uuid - sqz - sqrtz or sqrtz)
end

-- ENTITY

function ENT:Initialize()
    local chip = self:GetChip()

    if not IsValid(chip) then self:Remove() return end

    AnchorIndex[chip:EntIndex()] = AnchorIndex[chip:EntIndex()] or {}
    AnchorIndex[chip:EntIndex()][self:GetIndex()] = self

    chip:CallOnRemove("LineCoreChipDestruct", function(ent, index)
        AnchorIndex[index] = nil
        LineLink[index] = nil
    end, chip:EntIndex())
end

function ENT:OnRemove()
    local chip = self:GetChip()
    if not IsValid(chip) then return end

    local chip_index = chip:EntIndex()
    local index = self:GetIndex()

    if AnchorIndex[chip_index] then
        AnchorIndex[chip_index][index] = nil
    end

    if LineLink[chip_index] then
        for uuid,_ in pairs(LineLink[chip_index]) do
            local x, y = unpair(uuid)

            if x == index or y == index then
                LineLink[chip_index][uuid] = nil
            end
        end
    end
end

-- NETWORK

net.Receive("LineCoreSync", function()
    if net.ReadBool() then
        local count = 0
        for _,lines in pairs(LineLink) do
            count = count + table.Count(lines)
        end

        if net.ReadUInt(14) == count then return end

        net.Start("LineCoreSync")
        net.SendToServer()

        MsgC(Color(177, 12, 0), "BAD WOLF\n")
        return
    end

    local len = net.ReadUInt(16)

    local json = util.Decompress(net.ReadData(len))
    local data = util.JSONToTable(json)

    for chip,lines in pairs(data) do
        if not AnchorIndex[chip] then goto skip_chip end
        LineLink[chip] = {}

        for uuid,line in pairs(lines) do
            local x, y = unpair(uuid)

            if not AnchorIndex[chip][x] or not AnchorIndex[chip][y] then goto skip_line end
            if not IsValid(AnchorIndex[chip][x]) or not IsValid(AnchorIndex[chip][y]) then goto skip_line end

            LineLink[chip][uuid] = {
                color = line.color or nil,
                zbuffer = line.zbuffer or nil
            }
            ::skip_line::
        end
        ::skip_chip::
    end
end)

net.Receive("LineCoreCreate", function()
    local len = net.ReadUInt(16)
    local json = util.Decompress(net.ReadData(len))
    local data = util.JSONToTable(json)

    for chip,lines in pairs(data) do
        if not AnchorIndex[chip] then goto skip_chip end
        LineLink[chip] = LineLink[chip] or {}

        for uuid,line in pairs(lines) do
            local x, y = unpair(uuid)

            if not AnchorIndex[chip][x] or not AnchorIndex[chip][y] then goto skip_line end
            if not IsValid(AnchorIndex[chip][x]) or not IsValid(AnchorIndex[chip][y]) then goto skip_line end

            LineLink[chip][uuid] = {
                color = line.color or nil,
                zbuffer = line.zbuffer or nil
            }
            ::skip_line::
        end
        ::skip_chip::
    end
end)

net.Receive("LineCoreDelete", function()
    local chip = net.ReadUInt(14)

    if not LineLink[chip] then return end
    local uuid = net.ReadUInt(32)

    LineLink[chip][uuid] = nil
end)

net.Receive("LineCoreColor", function()
    local chip = net.ReadUInt(14)

    if not LineLink[chip] then return end
    local uuid = net.ReadUInt(32)

    if not LineLink[chip][uuid] then return end
    LineLink[chip][uuid].color = net.ReadColor(false)
end)

-- RENDER

hook.Add("PostDrawOpaqueRenderables", "LineCoreRender", function()
    for chip,lines in pairs(LineLink) do
        if not AnchorIndex[chip] then goto skip_chip end

        for uuid,data in pairs(lines) do
            local x, y = unpair(uuid)
            local ent, _ent = AnchorIndex[chip][x], AnchorIndex[chip][y]

            if not ent or not IsValid(ent) then goto skip_uuid end
            if not _ent or not IsValid(_ent) then goto skip_uuid end

            render.DrawLine(ent:GetPos(), _ent:GetPos(), data.color or Color(255, 255, 255), not tobool(data.zbuffer))

            ::skip_uuid::
        end
        ::skip_chip::
    end
end)

-- CONCOMMAND

concommand.Add("cl_linecore_clear_lines", function()
    LineLink = {}
end)

concommand.Add("cl_linecore_debug", function()
    PrintTable(AnchorIndex)
    PrintTable(LineLink)
end)