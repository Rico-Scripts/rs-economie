local ESX = exports.es_extended:getSharedObject()
local isOpen = false

local function notify(description, kind)
    lib.notify({
        title = 'RS Economie',
        description = description,
        type = kind or 'inform'
    })
end

local function setOpen(state, admin)
    isOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = state and 'open' or 'close', admin = admin == true })

    if state then
        lib.callback('rs-economie:server:getDashboard', false, function(response)
            if not response or not response.success then
                setOpen(false)
                return notify(response and response.message or 'Gegevens konden niet worden geladen.', 'error')
            end
            SendNUIMessage({ action = 'hydrate', payload = response.data })
        end, admin == true)
    end
end

exports('OpenDashboard', function(admin)
    if isOpen then return false end
    setOpen(true, admin == true)
    return true
end)

exports('IsDashboardOpen', function()
    return isOpen
end)

RegisterCommand(Config.Command, function()
    setOpen(true, false)
end, false)

RegisterCommand(Config.AdminCommand, function()
    setOpen(true, true)
end, false)

RegisterKeyMapping(Config.Command, 'Open RS Economie', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ success = true })
end)

local actions = {
    transfer = 'rs-economie:server:transfer',
    savings = 'rs-economie:server:savings',
    loan = 'rs-economie:server:createLoan',
    payLoan = 'rs-economie:server:payLoan',
    updatePolicy = 'rs-economie:server:updatePolicy',
    adminMutation = 'rs-economie:server:adminMutation'
}

for name, callbackName in pairs(actions) do
    RegisterNUICallback(name, function(data, cb)
        lib.callback(callbackName, false, function(response)
            cb(response or { success = false, message = 'Geen antwoord van de server.' })
            if response and response.message then
                notify(response.message, response.success and 'success' or 'error')
            end
            if response and response.success then
                lib.callback('rs-economie:server:getDashboard', false, function(refresh)
                    if refresh and refresh.success then
                        SendNUIMessage({ action = 'hydrate', payload = refresh.data })
                    end
                end, data and data.admin == true)
            end
        end, data or {})
    end)
end

RegisterNetEvent('rs-economie:client:refresh', function()
    if not isOpen then return end
    lib.callback('rs-economie:server:getDashboard', false, function(response)
        if response and response.success then
            SendNUIMessage({ action = 'hydrate', payload = response.data })
        end
    end, false)
end)

RegisterNetEvent('rs-economie:client:notify', notify)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
