-- Events
RegisterNetEvent('baseevents:enteredVehicle', function(veh, seat, name)
    TriggerClientEvent('citra-wheeldamage:client:inVehicle', source, veh)
end)