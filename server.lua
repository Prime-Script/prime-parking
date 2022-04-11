-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}
local housesLoaded = false
local AllGarages = {}

-- Callbacks

QBCore.Functions.CreateCallback('Prime-Parking:server:checkVehicleOwner', function(source, cb, plate) -- Check Vehicle Owner:
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',
		{
			plate,
			Player.PlayerData.citizenid
		}, function(result)
		if result[1] ~= nil then
			 cb(true, result[1].balance)
		else
			cb(false)
		end
	end)
end)

QBCore.Functions.CreateCallback('Prime-Parking:server:GetUserVehicles', function(source, cb) -- Get a list of vehicles in the garage
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE citizenid = ?',
		{
			Player.PlayerData.citizenid
		}, function(result)
		if result[1] ~= nil then
			cb(result)
		else
			cb(nil)
		end
	end)
end)

QBCore.Functions.CreateCallback('Prime-Parking:server:GetVehicleProperties', function(source, cb, plate) -- Get vehicle information
    local src = source
    local properties = {}
    local result = MySQL.Sync.fetchAll('SELECT mods FROM player_vehicles WHERE plate = ?',
		{
			plate
		}
	)
    if result[1] ~= nil then
        properties = json.decode(result[1].mods)
    end
    cb(properties)
end)

-- Events

RegisterNetEvent('Prime-Parking:server:UpdateGaragesZone', function() -- Update Garages
    local result = MySQL.Sync.fetchAll('SELECT * FROM houselocations', {})
    if result[1] then        
		AllGarages = Garages
		for k, v in pairs(result) do
            local garage = json.decode(v.garage) or {} 
			if v.garage ~= nil then
            
				AllGarages[v.name] = {
					label = v.label,
					spawnPoint = {
						vector4(garage.x, garage.y, garage.z, garage.h),
					},
					blippoint = vector3(garage.x, garage.y, garage.z),
					showBlip = true,
					blipsprite = 357,
					blipscale = 0.65,
					blipcolour = 3,
					job = nil, -- [nil: public garage] ['police: police garage'] ...
					fullfix = false, -- [true: full fix when take out vehicle]
					garastate = 1, -- [0: Depot] [1: Garage] [2: Impound]
					isHouseGarage = true,
					canStoreVehicle = true,
					zones = {
						vector2(garage.x1, garage.y1),
						vector2(garage.x2, garage.y2),
						vector2(garage.x3, garage.y3),
						vector2(garage.x4, garage.y4),					
					},
					minz = garage.z - 1,
					maxz = garage.z + 3,
				}
			end
			
        end
		TriggerClientEvent('Prime-Parking:client:UpdateGaragesZone', -1, AllGarages)
	else
		TriggerClientEvent('Prime-Parking:client:UpdateGaragesZone', -1, Garages)
    end
end)

RegisterNetEvent('Prime-Parking:server:updateHouseKeys', function() --Update House Keys
    local HouseKeys = {}
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		local identifier = Player.PlayerData.license
        local cid = Player.PlayerData.citizenid
		if AllGarages then
			for k, v in pairs(AllGarages) do
				if v.isHouseGarage then
					if Player.PlayerData.job.name == 'realestate' then
						HouseKeys[k] = true
					else
						HouseKeys[k] = exports['qb-houses']:hasKey(identifier, cid, k)
					end
				else
					HouseKeys[k] = false
				end
			end
			TriggerClientEvent('Prime-Parking:client:updateHouseKeys', source, HouseKeys)
		end
	end
end)

RegisterNetEvent('Prime-Parking:server:UpdateOutsideVehicles', function(Vehicles) -- Update car is outside
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid
    OutsideVehicles[CitizenId] = Vehicles
end)

RegisterNetEvent('Prime-Parking:server:updateVehicleState', function(state, plate, garage) -- Vehicle status update
    MySQL.Async.execute('UPDATE player_vehicles SET state = ?, garage = ?, depotprice = ? WHERE plate = ?',
        {
			state,
			garage,
			0,
			plate
		}
	)
end)

RegisterNetEvent('Prime-Parking:server:updateVehicleStatus', function(fuel, engine, body, plate, garage) -- Vehicle status update
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if engine > 1000 then
        engine = engine / 1000
    end

    if body > 1000 then
        body = body / 1000
    end

    MySQL.Async.execute('UPDATE player_vehicles SET fuel = ?, engine = ?, body = ? WHERE plate = ? AND citizenid = ? AND garage = ?',
        {
			fuel,
			engine,
			body,
			plate,
			Player.PlayerData.citizenid,
			garage
		}
	)
end)

RegisterNetEvent('Prime-Parking:server:PayDepotPrice', function(vehicle) -- Payment of vehicle fines
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bankBalance = Player.PlayerData.money['bank']
    local cashBalance = Player.PlayerData.money['cash']
    MySQL.Async.fetchAll('SELECT * FROM player_vehicles WHERE plate = ?',
		{
			vehicle.plate
		}, function(result)
        if result[1] ~= nil then
            if bankBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney('bank', result[1].depotprice, 'Paying fines for vehicle in the depot')
                TriggerClientEvent('Prime-Parking:client:doTakeOutVehicle', src, vehicle)
            elseif cashBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney('cash', result[1].depotprice, 'Paying fines for vehicle in the depot')
                TriggerClientEvent('Prime-Parking:client:doTakeOutVehicle', src, vehicle)
            else
                TriggerClientEvent('QBCore:Notify', src, GetText('you_dont_have_enough_money'), 'error')
            end
        end
    end)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if AutoRespawn then
            MySQL.Async.execute('UPDATE player_vehicles SET state = 1 WHERE state = 0 AND depotprice = 0', {})
        end
    end
end)

CreateThread(function() -- Update houses
    while true do
        if not housesLoaded then
            housesLoaded = true
			TriggerEvent('Prime-Parking:server:updateHouseKeys')
			TriggerEvent('Prime-Parking:server:UpdateGaragesZone')			
        end
        Wait(7)
    end
end)
