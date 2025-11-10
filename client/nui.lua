-- Close NUI (from buttons)
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

-- Buy vehicle from NUI
RegisterNUICallback('buyVehicle', function(data, cb)
    local id = data and data.id
    if id then
        TriggerServerEvent('qbx_usedcars:buyVehicle', id)
    end
    SetNuiFocus(false, false)
    cb({})
end)

-- Optional: ESC closes UI
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then -- ESC / BACKSPACE
            SendNUIMessage({ action = 'forceClose' })
            SetNuiFocus(false, false)
        end
    end
end)

