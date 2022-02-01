ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Line Base"
ENT.Author = "Koleops"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Chip")
    self:NetworkVar("Int", 0, "Index")
end