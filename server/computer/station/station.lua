Station = {
    stationPeripheralName = nil
}


function Station:enumerate()
    local periphs = peripheral.getNames()
    for index, pName in ipairs(periphs) do
        if not peripheral.hasType(pName, "Create_Station") then
            goto continue_enumerate
        else
            Station.stationPeripheralName = pName
            return true
        end
        ::continue_enumerate::
    end
    return false
end

function Station:getName()
    local actualName = peripheral.call(Station.stationPeripheralName, "getStationName")
    local expectedName = "Logistics " ..settings.get("station.type") .. " " .. os.getComputerID()
    if actualName ~= expectedName then
        peripheral.call(Station.stationPeripheralName, "setStationName", expectedName)
    end
    return expectedName
end

function Station:trainInbound()
    return peripheral.call(Station.stationPeripheralName, "isTrainEnroute")
end

function Station:trainPresent()
    return peripheral.call(Station.stationPeripheralName, "isTrainPresent")
end

function Station:unloadAt(destStation, items, fluids)
    if not Station.trainPresent() then
        return false
    end
    local schedule = {
        cyclic = false,
        entries = {
            {
                instruction = {
                    id = "create:destination",
                    data = {
                        text = destStation
                    }
                },
                conditions = {
                    {
                        -- {
                        --     id = "create:idle",
                        --     data = {
                        --         value = 5,
                        --         time_unit = 1
                        --     }
                        -- }
                    }
                }
            },
            {
                instruction = {
                    id = "create:destination",
                    data = {
                        text = Station.getName()
                    }
                },
                conditions = {
                    {
                        {
                            id = "create:idle",
                            data = {
                                value = 5,
                                time_unit = 1
                            }
                        }
                    }
                }
            }
        }
    }

    for name, count in pairs(items) do
        table.insert(schedule["entries"][1]["conditions"][1], {
            id = "create:item_threshold",
            data = {
                item = {
                    name = name,
                    count = 1
                },
                threshold = 0,
                operator = 2,
                measure = 0
            }
        })
    end

    for name, count in pairs(fluids) do
        table.insert(schedule["entries"][1]["conditions"][1], {
            id = "create:fluid_threshold",
            data = {
                bucket = {
                    name = name .. "_bucket",
                    count = 1
                },
                threshold = 0,
                operator = 2,
                measure = 0
            }
        })
    end
    peripheral.call(Station.stationPeripheralName, "setSchedule", schedule)
    return true
end

return Station