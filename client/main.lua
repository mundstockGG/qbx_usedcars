local spawnedVehicles = {}

-- SELL VEHICLE ANYWHERE
CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name  = 'qbx_sell_vehicle',
            icon  = 'fa-solid fa-tags',
            label = 'List vehicle for sale',
            canInteract = function(entity)
                local ped = PlayerPedId()
                if GetPedInVehicleSeat(entity, -1) ~= ped then return false end
                if Config.RequireParked and GetEntitySpeed(entity) > 1.0 then return false end
                return true
            end,
            onSelect = function(data)
                local input = lib.inputDialog('Sell your vehicle', {
                    { type = 'number', label = 'Price', min = Config.MinPrice, max = Config.MaxPrice, required = true }
                })
                if not input or not input[1] then return end

                local price = input[1]
                local veh = data.entity
                local props = lib.getVehicleProperties(veh)
                local coords = GetEntityCoords(veh)
                local heading = GetEntityHeading(veh)

                TriggerServerEvent('qbx_usedcars:listVehicle', price, props, coords, heading)
            end
        }
    })
end)

-- F6: OPEN NEARBY MARKET
RegisterCommand('qbx_market', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    lib.callback('qbx_usedcars:getNearby', false, function(rows)
        local listings = {}
        for _, r in ipairs(rows) do
            local pos = vector3(r.pos_x, r.pos_y, r.pos_z)
            if #(coords - pos) <= Config.MarketRadius then
                r.props = json.decode(r.vehicle_props or '{}')
                listings[#listings + 1] = r
            end
        end

        if #listings == 0 then
            return lib.notify({ type = 'info', description = 'No vehicles for sale nearby.' })
        end

        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openMarket', listings = listings })
    end, coords)
end, false)

RegisterKeyMapping('qbx_market', 'Open nearby used car market', 'keyboard', Config.MarketKey)

-- SPAWN PREVIEW VEHICLES AROUND PLAYER
local function spawnListingVehicle(row)
    local props = json.decode(row.vehicle_props or '{}')
    local model = props.model or joaat('sultan')

    lib.requestModel(model)
    local veh = CreateVehicle(model, row.pos_x, row.pos_y, row.pos_z, row.heading or 0.0, false, false)
    if not DoesEntityExist(veh) then return nil end

    SetVehicleOnGroundProperly(veh)
    lib.setVehicleProperties(veh, props)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleDoorsLocked(veh, 2)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleNumberPlateText(veh, row.plate or 'USED')
    SetEntityAsMissionEntity(veh, true, false)

    -- Target to open single listing NUI
    exports.ox_target:addLocalEntity(veh, {
        {
            name = 'qbx_usedcars_view_' .. row.id,
            icon = 'fa-solid fa-car',
            label = ('%s - $%s'):format(row.plate, row.price),
            onSelect = function()
                SetNuiFocus(true, true)
                SendNUIMessage({ action = 'openListing', listing = row })
            end
        }
    })

    return veh
end

CreateThread(function()
    while true do
        Wait(Config.SpawnCheckInterval)
        if not Config.SpawnVehiclesInWorld then goto continue end

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        lib.callback('qbx_usedcars:getNearby', false, function(rows)
            local keep = {}

            for _, row in ipairs(rows) do
                local pos = vector3(row.pos_x, row.pos_y, row.pos_z)
                if #(coords - pos) <= Config.DespawnDistance then
                    keep[row.id] = true
                    if not spawnedVehicles[row.id] or not DoesEntityExist(spawnedVehicles[row.id]) then
                        spawnedVehicles[row.id] = spawnListingVehicle(row)
                    end
                end
            end

            for id, veh in pairs(spawnedVehicles) do
                if not keep[id] or not DoesEntityExist(veh) or #(coords - GetEntityCoords(veh)) > Config.DespawnDistance then
                    if DoesEntityExist(veh) then DeleteVehicle(veh) end
                    spawnedVehicles[id] = nil
                end
            end
        end, coords)

        ::continue::
    end
end)

-- Remove preview when sold/cancelled
RegisterNetEvent('qbx_usedcars:listingSold', function(listingId)
    local veh = spawnedVehicles[listingId]
    if veh and DoesEntityExist(veh) then
        DeleteVehicle(veh)
    end
    spawnedVehicles[listingId] = nil
end)

