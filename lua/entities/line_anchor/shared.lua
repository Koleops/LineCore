ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Line Base"
ENT.Author = "Koleops"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Expression2_index")
    self:NetworkVar("Int", 1, "Entity_index")
end