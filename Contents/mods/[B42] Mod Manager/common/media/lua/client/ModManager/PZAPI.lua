require "PZAPI/ModOptions"

function PZAPI.ModOptions.Options:addImage(imagePath, secondParam)
    local option = { type = "image", path = imagePath, width = nil }
    if type(secondParam) == "number" then
        if secondParam > 1 then
            option.width = 1.0
        elseif secondParam < 0 then
            option.width = 0.0
        else
            option.width = secondParam
        end
    end
    table.insert(self.data, option)
    return option
end