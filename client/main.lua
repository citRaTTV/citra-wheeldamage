-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local hasWheel, brokenWheels = 0, {}

-- Functions
local function breakWheel(veh)
    local wheelType = GetVehicleWheelType(veh)
    local model = joaat(Config.WheelProps[wheelType] and Config.WheelProps[wheelType] or 'prop_wheel_01')
    local wheelCoords = GetEntityCoords(veh)
    brokenWheels[veh] = brokenWheels[veh] and brokenWheels[veh] + 1 or 1
    if brokenWheels[veh] > GetVehicleNumberOfWheels(veh) then brokenWheels[veh] = GetVehicleNumberOfWheels(veh) return end
    BreakOffVehicleWheel(veh, brokenWheels[veh] - 1, false, true, true, false)
    while not HasModelLoaded(model) do RequestModel(model) Wait(10) end
    local wheel = CreateObject(model, wheelCoords, true, true, false)
    while not DoesEntityExist(wheel) do Wait(10) end
    SetEntityVelocity(wheel, GetEntityVelocity(veh))

    exports['qb-target']:AddTargetModel(model, {
        options = {
            {
                label = 'Pickup wheel',
                action = function(entity)
                    local plyPed = PlayerPedId()
                    FreezeEntityPosition(entity, false)
                    AttachEntityToEntity(entity, plyPed, GetPedBoneIndex(plyPed, 28422), 0.0, 0.0, 0.0, 135.0, 0.0, 0.0,
                        true, true, false, false, 2, true)
                    hasWheel = entity
                end,
            },
        },
    })
end

local function hardLanding(veh, wheelNum)
    SetVehicleEngineOn(veh, false, false, false)
    for i = 1, 8 do SmashVehicleWindow(veh, i - 1) end
    for i = 1, 5 do SetVehicleDoorBroken(veh, i - 1, false) end
    wheelNum = math.floor(math.min(wheelNum, 4))
    for i = 1, wheelNum do Wait(100) breakWheel(veh) end

    exports['qb-target']:AddTargetEntity(veh, {
        options = {
            {
                label = 'Reattach wheel',
                action = function(entity)
                    QBCore.Functions.Progressbar('citra-wheeldamage_reattach', 'Reattaching wheel', Config.ReattachTime * 1000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {
                        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                        anim = 'machinic_loop_mechandplayer',
                        flags = 1
                    }, {}, {}, function()
                        local health = {
                            body = GetVehicleBodyHealth(entity),
                            engine = GetVehicleEngineHealth(entity),
                            tank = GetVehiclePetrolTankHealth(entity),
                        }
                        DetachEntity(hasWheel, false, false)
                        DeleteObject(hasWheel)
                        brokenWheels[entity] -= 1
                        while not NetworkHasControlOfEntity(entity) do NetworkRequestControlOfEntity(entity) end
                        SetVehicleFixed(entity)
                        for i = 1, brokenWheels[entity] do BreakOffVehicleWheel(entity, i - 1, false, true, true, false) end
                        QBCore.Debug(health)
                        SetVehicleBodyHealth(entity, health.body)
                        SetVehicleEngineHealth(entity, health.engine)
                        SetVehiclePetrolTankHealth(entity, health.tank)
                        SetVehicleDamage(entity, 0, 0, 0.33, 200.0, 100.0, true)
                        for i = 1, 8 do SmashVehicleWindow(entity, i - 1) end
                        for i = 1, 5 do SetVehicleDoorBroken(entity, i - 1, true) end
                        if brokenWheels[entity] <= 0 then exports['qb-target']:RemoveTargetEntity(entity, 'Reattach wheel') end
                        hasWheel = 0
                    end)
                end,
                canInteract = function()
                    return hasWheel ~= 0
                end,
            },
        }
    })
end

local function inAir(vehEnt, heightDiv)
    local height = 0
    while IsEntityInAir(vehEnt) do
        local vehCoords = GetEntityCoords(vehEnt)
        local _, groundZ = GetGroundZFor_3dCoord(vehCoords.x, vehCoords.y, vehCoords.z, false)
        local _height = vehCoords.z - groundZ
        if _height >= Config.HeightDivider and _height > height then height = _height end
        Wait(10)
    end

    if height >= heightDiv then
        hardLanding(vehEnt, height / heightDiv)
    end

    return height
end

-- Commands
RegisterCommand('fixwheels', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if IsPedInAnyVehicle(PlayerPedId(), false) and PlayerData.job.type == 'mechanic' then
        QBCore.Functions.Progressbar('citra-wheeldamage_reattach', 'Reattaching wheel', Config.ReattachTime * 1000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            anim = 'machinic_loop_mechandplayer',
            flags = 1
        }, {}, {}, function()
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            SetVehicleFixed(veh)
        end)
    end
end)

-- Events
RegisterNetEvent('citra-wheeldamage:client:inVehicle', function(vehEnt)
    local plyPed, vehClass = PlayerPedId(), GetVehicleClass(vehEnt)
    if (vehClass > 12 and vehClass ~= 18) or vehClass == 8 then return end
    --Allow offroad vehs some additional height
    local heightDiv = (vehClass == 9) and Config.HeightDivider * 1.5 or Config.HeightDivider

    while IsPedInVehicle(plyPed, vehEnt, true) do
        if GetPedInVehicleSeat(vehEnt, -1) == plyPed then
            if IsEntityInAir(vehEnt) then
                inAir(vehEnt, heightDiv)
                Wait(10)
            else
                Wait(100)
            end
        else
            Wait(2000)
        end
    end
end)