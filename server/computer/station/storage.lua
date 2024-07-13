-- Storage interface.
local json = require("json")
local pretty = require("cc.pretty")

local trainStorageTypes = {
    "create:portable_storage_interface",
    "create:portable_fluid_interface"
}

StorageManager = {
    stationStoragePeripherals = {},
    trainStoragePeripherals = {},
    itemLevels = nil,
    fluidLevels = nil,
    levelsAge = nil,
    itemLimits = nil,
    fluidLimits = nil,
    limitsAge = nil,
    lastLearn = nil,
}


settings.define("station.learn", {
    description = "If the station should learn the items in its storage",
    default = true,
    type="boolean"
})


function StorageManager:enumerate() 
    local periphs = peripheral.getNames()
    for index, pName in ipairs(periphs) do
        if not peripheral.hasType(pName, "inventory") and not peripheral.hasType(pName, "fluid_storage") or peripheral.hasType(pName, "create:belt") then
            goto continue_enumerate
        elseif peripheral.hasType(pName, trainStorageTypes[1]) or peripheral.hasType(pName, trainStorageTypes[2]) then
            table.insert(StorageManager.trainStoragePeripherals, pName)
        else
            table.insert(StorageManager.stationStoragePeripherals, pName)
        end
        ::continue_enumerate::
    end
end

function StorageManager:getLevels()
    if StorageManager.itemLevels and StorageManager.fluidLevels and os.clock() - StorageManager.levelsAge < 5 then return StorageManager.itemLevels, StorageManager.fluidLevels end

    local totalItems = {}
    local totalFluids = {}
    for index, pName in ipairs(StorageManager.stationStoragePeripherals) do
        if peripheral.hasType(pName, "inventory") then
            local itemList = peripheral.call(pName, "list")
            for key, value in pairs(itemList) do
                local count = totalItems[value["name"]] or 0
                count = count + value["count"]
                totalItems[value["name"]] = count
            end
        elseif peripheral.hasType(pName, "fluid_storage") then
            local tanks = peripheral.call(pName, "tanks")
            for key, value in pairs(tanks) do
                local amount = totalFluids[value["name"]] or 0
                amount = amount + value["amount"]
                totalFluids[value["name"]] = amount
            end
        end
        
    end
    StorageManager.itemLevels = totalItems
    StorageManager.fluidLevels = totalFluids
    StorageManager.levelsAge = os.clock()
    return totalItems, totalFluids
end

function StorageManager:getLimits()
    if StorageManager.lastLearn == nil or os.clock() - StorageManager.lastLearn > 30 then
        StorageManager.learnLimits()
    end
    if StorageManager.itemLimits and StorageManager.fluidLimits and os.clock() - StorageManager.limitsAge < 60 then return StorageManager.itemLimits, StorageManager.fluidLimits end
    if not fs.exists("itemLimits.json") then
        local f = fs.open("itemLimits.json", "w")
        f.write(json.encode({}))
        f.close()
        return {}
    end
    if not fs.exists("fluidLimits.json") then
        local f = fs.open("fluidLimits.json", "w")
        f.write(json.encode({}))
        f.close()
        return {}
    end

    local f = fs.open("itemLimits.json", "r")
    local itemLimits = json.decode(f.readAll())
    f.close()
    StorageManager.itemLimits = itemLimits
    local f = fs.open("fluidLimits.json", "r")
    local fluidLimits = json.decode(f.readAll())
    f.close()
    StorageManager.fluidLimits = fluidLimits
    StorageManager.limitsAge = os.clock()
    return itemLimits, fluidLimits
end

function StorageManager:learnLimits()
    if not (settings.get("station.type") == "requester" and settings.get("station.learn")) then
        StorageManager.lastLearn = os.clock() + 600
        return
    end

    local itemLevels, fluidLevels = StorageManager.getLevels()
    local itemLimits, fluidLimits = StorageManager.getLimits()

    for key, value in pairs(itemLevels) do
        if itemLimits[key] == nil then
            itemLimits[key] = {
                upper = 0,
                lower = -1
            }
        end
    end
    for key, value in pairs(fluidLevels) do
        if fluidLimits[key] == nil then
            fluidLimits[key] = {
                upper = 0,
                lower = -1
            }
        end
    end
    local f = fs.open("itemLimits.json","w+")
    f.write(json.encode(itemLimits))
    f.close()
    local f = fs.open("fluidLimits.json","w+")
    f.write(json.encode(fluidLimits))
    f.close()
    StorageManager.itemLimits = itemLimits
    StorageManager.fluidLimits = fluidLimits
    StorageManager.limitsAge = os.clock()
    StorageManager.lastLearn = os.clock()
end


function StorageManager:stuffNeeded()
    local itemLimits, fluidLimits = StorageManager.getLimits()
    local itemLevels, fluidLevels = StorageManager.getLevels()

    local itemsNeeded = {}
    local fluidsNeeded = {}

    for name, limitObj in pairs(itemLimits) do
        if not itemLevels[name] or itemLevels[name] < limitObj["lower"] then
            -- Lower than the lower limit so we NEED the item
            itemsNeeded[name] = limitObj["upper"] - (itemLevels[name] or 0)
        end
    end
    for name, limitObj in pairs(fluidLimits) do
        if not fluidLevels[name] or fluidLevels[name] < limitObj["lower"] then
            -- Lower than the lower limit so we NEED the item
            fluidsNeeded[name] = limitObj["upper"] - (fluidLevels[name] or 0)
        end
    end
    return itemsNeeded, fluidsNeeded
end

function StorageManager:stuffWanted()
    local itemLimits, fluidLimits = StorageManager.getLimits()
    local itemLevels, fluidLevels = StorageManager.getLevels()

    local itemsWanted = {}
    local fluidsWanted = {}

    for name, limitObj in pairs(itemLimits) do
        if not itemLevels[name] or itemLevels[name] < limitObj["upper"] then
            -- Lower than the lower limit so we NEED the item
            itemsWanted[name] = limitObj["upper"] - (itemLevels[name] or 0)
        end
    end
    for name, limitObj in pairs(fluidLimits) do
        if not fluidLevels[name] or fluidLevels[name] < limitObj["upper"] then
            -- Lower than the lower limit so we NEED the item
            fluidsWanted[name] = limitObj["upper"] - (fluidLevels[name] or 0)
        end
    end
    
    return itemsWanted, fluidsWanted
end

function StorageManager:loadTrain(itemsToLoad, fluidsToLoad)
    for index, pName in ipairs(StorageManager.stationStoragePeripherals) do
        local storage = peripheral.wrap(pName)
        if not peripheral.hasType(pName, "inventory") then break end
        local storageItems = storage.list()
        for slot, item in pairs(storageItems) do
            local toMove = itemsToLoad[item["name"]]
            if not toMove then
                -- Nothing...
            elseif toMove < item["count"] then
                local moved = 0
                for index, sName in ipairs(StorageManager.trainStoragePeripherals) do
                    moved = moved + storage.pushItems(sName, slot, toMove - moved)
                end
                itemsToLoad[item["name"]] = itemsToLoad[item["name"]] - moved
            else
                local temp = item["count"]
                local moved = 0
                for index, sName in ipairs(StorageManager.trainStoragePeripherals) do
                    moved = moved + storage.pushItems(sName, slot, temp - moved)
                end
                itemsToLoad[item["name"]] = itemsToLoad[item["name"]] - moved
            end
        end
    end

    for index, pName in ipairs(StorageManager.stationStoragePeripherals) do
        local storage = peripheral.wrap(pName)
        if not peripheral.hasType(pName, "fluid_storage") then break end
        local storageFluids = storage.tanks()
        for idx, tank in pairs(storageFluids) do
            local toMove = fluidsToLoad[tank["name"]]
            if not toMove then
                -- Nothing...
            elseif toMove < tank["amount"] then
                local moved = 0
                for index, sName in ipairs(StorageManager.trainStoragePeripherals) do
                    moved = moved + storage.pushFluid(sName, toMove - moved, tank["name"])
                end
                fluidsToLoad[tank["name"]] = fluidsToLoad[tank["name"]] - moved
            else
                local temp = tank["amount"]
                local moved = 0
                for index, sName in ipairs(StorageManager.trainStoragePeripherals) do
                    moved = moved + storage.pushFluid(sName, temp - moved, tank["name"])
                end
                fluidsToLoad[tank["name"]] = fluidsToLoad[tank["name"]] - moved
            end
        end
    end
end

return StorageManager