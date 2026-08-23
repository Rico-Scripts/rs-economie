local ESX = exports.es_extended:getSharedObject()
local cooldowns = {}
local policies = {}
local getAccount

local function round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function reply(success, message, data)
    return { success = success, message = message, data = data }
end

local function identifierOf(xPlayer)
    return xPlayer and xPlayer.getIdentifier()
end

local function displayName(xPlayer)
    return xPlayer and xPlayer.getName() or 'Onbekend'
end

local function isAdmin(xPlayer)
    return xPlayer and Config.AdminGroups[xPlayer.getGroup()] == true
end

local function safeAmount(value, maximum)
    local amount = round(value)
    if amount < 1 or amount > maximum then return nil end
    return amount
end

local function bankBalance(xPlayer)
    local account = xPlayer.getAccount('bank')
    return account and round(account.money) or 0
end

local function addTransaction(identifier, kind, amount, description, counterparty, balanceAfter, metadata)
    MySQL.insert.await([[
        INSERT INTO rs_economy_transactions
            (identifier, type, amount, description, counterparty, balance_after, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { identifier, kind, amount, description, counterparty, balanceAfter, json.encode(metadata or {}) })
end

exports('RecordTransaction', function(identifier, kind, amount, description, counterparty, balanceAfter, metadata)
    if type(identifier) ~= 'string' or identifier == '' then return false end
    addTransaction(
        identifier,
        tostring(kind or 'external'):sub(1, 40),
        round(amount),
        tostring(description or 'Externe transactie'):sub(1, 180),
        counterparty and tostring(counterparty):sub(1, 80) or nil,
        round(balanceAfter),
        metadata
    )
    return true
end)

exports('GetPolicy', function(key)
    return policies[tostring(key or '')]
end)

exports('GetFinancialSnapshot', function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    local account = getAccount(identifier)
    return {
        savings = round(account.savings),
        creditScore = round(account.credit_score),
        activeDebt = round(MySQL.scalar.await("SELECT COALESCE(SUM(outstanding), 0) FROM rs_economy_loans WHERE identifier = ? AND status IN ('active','overdue')", { identifier }))
    }
end)

getAccount = function(identifier)
    MySQL.insert.await('INSERT IGNORE INTO rs_economy_accounts (identifier) VALUES (?)', { identifier })
    return MySQL.single.await('SELECT savings, credit_score FROM rs_economy_accounts WHERE identifier = ?', { identifier })
end

local function loadPolicies()
    policies = {}
    for key, value in pairs(Config.DefaultPolicies) do policies[key] = value end
    local rows = MySQL.query.await('SELECT policy_key, policy_value FROM rs_economy_policies') or {}
    for _, row in ipairs(rows) do policies[row.policy_key] = tonumber(row.policy_value) or policies[row.policy_key] end
end

local function getDashboard(xPlayer, adminRequested)
    local identifier = identifierOf(xPlayer)
    local account = getAccount(identifier)
    local transactions = MySQL.query.await([[
        SELECT id, type, amount, description, counterparty, balance_after, created_at
        FROM rs_economy_transactions WHERE identifier = ? ORDER BY id DESC LIMIT ?
    ]], { identifier, Config.MaxTransactionHistory }) or {}
    local loans = MySQL.query.await([[
        SELECT id, principal, outstanding, interest_rate, term_days, payment_amount,
               next_payment_at, status, created_at
        FROM rs_economy_loans WHERE identifier = ? AND status IN ('active', 'overdue') ORDER BY id DESC
    ]], { identifier }) or {}

    local data = {
        player = {
            name = displayName(xPlayer),
            identifier = identifier,
            cash = round(xPlayer.getMoney()),
            bank = bankBalance(xPlayer),
            savings = round(account.savings),
            creditScore = round(account.credit_score)
        },
        transactions = transactions,
        loans = loans,
        policies = policies,
        config = {
            currency = Config.Currency,
            maxTransfer = Config.MaxTransfer,
            maxLoan = Config.MaxLoan,
            minLoan = Config.MinLoan,
            loanTerms = Config.LoanTermDays
        },
        admin = false
    }

    if adminRequested and isAdmin(xPlayer) then
        data.admin = true
        data.statistics = {
            savings = MySQL.scalar.await('SELECT COALESCE(SUM(savings), 0) FROM rs_economy_accounts') or 0,
            debt = MySQL.scalar.await("SELECT COALESCE(SUM(outstanding), 0) FROM rs_economy_loans WHERE status IN ('active','overdue')") or 0,
            transactions = MySQL.scalar.await('SELECT COUNT(*) FROM rs_economy_transactions WHERE created_at >= NOW() - INTERVAL 24 HOUR') or 0,
            volume = MySQL.scalar.await('SELECT COALESCE(SUM(ABS(amount)), 0) FROM rs_economy_transactions WHERE created_at >= NOW() - INTERVAL 24 HOUR') or 0
        }
        data.audit = MySQL.query.await('SELECT actor_name, action, target_identifier, amount, details, created_at FROM rs_economy_audit ORDER BY id DESC LIMIT 50') or {}
    end

    return data
end

lib.callback.register('rs-economie:server:getDashboard', function(source, adminRequested)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return reply(false, 'Speler niet gevonden.') end
    return reply(true, nil, getDashboard(xPlayer, adminRequested == true))
end)

lib.callback.register('rs-economie:server:transfer', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return reply(false, 'Speler niet gevonden.') end
    local amount = safeAmount(data.amount, Config.MaxTransfer)
    if not amount then return reply(false, Config.Text.invalid_amount) end
    if cooldowns[source] and os.time() - cooldowns[source] < Config.TransferCooldown then
        return reply(false, Config.Text.cooldown)
    end

    local senderIdentifier = identifierOf(xPlayer)
    local targetIdentifier = tostring(data.recipient or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local targetPlayer = tonumber(targetIdentifier) and ESX.GetPlayerFromId(tonumber(targetIdentifier)) or nil
    if targetPlayer then targetIdentifier = identifierOf(targetPlayer) end
    if targetIdentifier == '' then return reply(false, Config.Text.player_missing) end
    if targetIdentifier == senderIdentifier then return reply(false, Config.Text.same_player) end
    if bankBalance(xPlayer) < amount then return reply(false, Config.Text.insufficient) end

    local targetExists = targetPlayer ~= nil or MySQL.scalar.await('SELECT 1 FROM users WHERE identifier = ? LIMIT 1', { targetIdentifier })
    if not targetExists then return reply(false, Config.Text.player_missing) end

    xPlayer.removeAccountMoney('bank', amount, 'RS Economie overschrijving')
    if targetPlayer then
        targetPlayer.addAccountMoney('bank', amount, 'RS Economie overschrijving')
    elseif Config.AllowOfflineTransfers then
        local accounts = MySQL.scalar.await('SELECT accounts FROM users WHERE identifier = ?', { targetIdentifier })
        local decoded = json.decode(accounts or '{}') or {}
        decoded.bank = round(decoded.bank) + amount
        MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { json.encode(decoded), targetIdentifier })
    else
        xPlayer.addAccountMoney('bank', amount, 'RS Economie terugbetaling')
        return reply(false, 'De ontvanger moet online zijn.')
    end

    cooldowns[source] = os.time()
    addTransaction(senderIdentifier, 'transfer_out', -amount, data.description or 'Overschrijving', targetIdentifier, bankBalance(xPlayer))
    addTransaction(targetIdentifier, 'transfer_in', amount, data.description or 'Overschrijving', senderIdentifier, targetPlayer and bankBalance(targetPlayer) or 0)
    RSEconomyLog('transfer', 'Bankoverschrijving', ('%s heeft %s%d overgemaakt.'):format(displayName(xPlayer), Config.Currency, amount), {
        { name = 'Van', value = senderIdentifier, inline = true },
        { name = 'Naar', value = targetIdentifier, inline = true }
    }, 'info')
    if targetPlayer then TriggerClientEvent('rs-economie:client:notify', targetPlayer.source, ('Je ontving %s%d van %s.'):format(Config.Currency, amount, displayName(xPlayer)), 'success') end
    return reply(true, Config.Text.transferred)
end)

lib.callback.register('rs-economie:server:savings', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return reply(false, 'Speler niet gevonden.') end
    local amount = safeAmount(data.amount, Config.MaxSavingsMutation)
    if not amount then return reply(false, Config.Text.invalid_amount) end
    local identifier = identifierOf(xPlayer)
    local account = getAccount(identifier)

    if data.direction == 'deposit' then
        if bankBalance(xPlayer) < amount then return reply(false, Config.Text.insufficient) end
        xPlayer.removeAccountMoney('bank', amount, 'RS Economie sparen')
        MySQL.update.await('UPDATE rs_economy_accounts SET savings = savings + ? WHERE identifier = ?', { amount, identifier })
        addTransaction(identifier, 'savings_deposit', -amount, 'Naar spaarrekening', nil, bankBalance(xPlayer))
        return reply(true, Config.Text.saved)
    elseif data.direction == 'withdraw' then
        if round(account.savings) < amount then return reply(false, Config.Text.insufficient) end
        local changed = MySQL.update.await('UPDATE rs_economy_accounts SET savings = savings - ? WHERE identifier = ? AND savings >= ?', { amount, identifier, amount })
        if changed < 1 then return reply(false, Config.Text.insufficient) end
        xPlayer.addAccountMoney('bank', amount, 'RS Economie spaargeld')
        addTransaction(identifier, 'savings_withdraw', amount, 'Van spaarrekening', nil, bankBalance(xPlayer))
        return reply(true, Config.Text.withdrawn)
    end
    return reply(false, 'Ongeldige actie.')
end)

lib.callback.register('rs-economie:server:createLoan', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return reply(false, 'Speler niet gevonden.') end
    local amount = safeAmount(data.amount, Config.MaxLoan)
    if not amount or amount < Config.MinLoan then return reply(false, Config.Text.invalid_amount) end
    local term = round(data.term)
    local validTerm = false
    for _, value in ipairs(Config.LoanTermDays) do if term == value then validTerm = true break end end
    if not validTerm then return reply(false, 'Ongeldige looptijd.') end

    local identifier = identifierOf(xPlayer)
    local active = MySQL.scalar.await("SELECT COUNT(*) FROM rs_economy_loans WHERE identifier = ? AND status IN ('active','overdue')", { identifier }) or 0
    if active >= Config.MaxActiveLoans then return reply(false, Config.Text.too_many_loans) end
    local rate = tonumber(policies.loan_interest) or Config.DefaultInterest
    local total = round(amount * (1 + rate / 100))
    local payment = math.max(1, math.ceil(total / term))
    MySQL.insert.await([[
        INSERT INTO rs_economy_loans
            (identifier, principal, outstanding, interest_rate, term_days, payment_amount, next_payment_at)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], { identifier, amount, total, rate, term, payment, Config.LoanPaymentIntervalHours })
    xPlayer.addAccountMoney('bank', amount, 'RS Economie lening')
    addTransaction(identifier, 'loan', amount, ('Lening (%d dagen)'):format(term), nil, bankBalance(xPlayer), { rate = rate })
    RSEconomyLog('loan_created', 'Nieuwe lening', ('%s leende %s%d.'):format(displayName(xPlayer), Config.Currency, amount), {
        { name = 'Looptijd', value = term .. ' dagen', inline = true },
        { name = 'Rente', value = rate .. '%', inline = true }
    }, 'warning')
    return reply(true, Config.Text.loan_created)
end)

lib.callback.register('rs-economie:server:payLoan', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return reply(false, 'Speler niet gevonden.') end
    local identifier = identifierOf(xPlayer)
    local loan = MySQL.single.await("SELECT * FROM rs_economy_loans WHERE id = ? AND identifier = ? AND status IN ('active','overdue')", { round(data.id), identifier })
    if not loan then return reply(false, 'Lening niet gevonden.') end
    local requested = data.amount == 'all' and round(loan.outstanding) or safeAmount(data.amount, Config.MaxLoan)
    local amount = math.min(requested or 0, round(loan.outstanding))
    if amount < 1 then return reply(false, Config.Text.invalid_amount) end
    if bankBalance(xPlayer) < amount then return reply(false, Config.Text.insufficient) end
    xPlayer.removeAccountMoney('bank', amount, 'RS Economie leningbetaling')
    local remaining = round(loan.outstanding) - amount
    MySQL.update.await("UPDATE rs_economy_loans SET outstanding = ?, status = ?, next_payment_at = DATE_ADD(NOW(), INTERVAL ? HOUR) WHERE id = ?", {
        remaining, remaining <= 0 and 'paid' or 'active', Config.LoanPaymentIntervalHours, loan.id
    })
    addTransaction(identifier, 'loan_payment', -amount, 'Aflossing lening #' .. loan.id, nil, bankBalance(xPlayer))
    return reply(true, remaining <= 0 and 'Lening volledig afbetaald.' or 'Aflossing verwerkt.')
end)

lib.callback.register('rs-economie:server:updatePolicy', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then return reply(false, Config.Text.no_access) end
    local key = tostring(data.key or '')
    if Config.DefaultPolicies[key] == nil then return reply(false, 'Onbekende beleidsinstelling.') end
    local value = tonumber(data.value)
    if not value or value < 0 or value > 1000000 then return reply(false, 'Ongeldige waarde.') end
    MySQL.prepare.await([[
        INSERT INTO rs_economy_policies (policy_key, policy_value, updated_by)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE policy_value = VALUES(policy_value), updated_by = VALUES(updated_by)
    ]], { key, value, identifierOf(xPlayer) })
    policies[key] = value
    MySQL.insert.await('INSERT INTO rs_economy_audit (actor_identifier, actor_name, action, details) VALUES (?, ?, ?, ?)', {
        identifierOf(xPlayer), displayName(xPlayer), 'policy:' .. key, json.encode({ value = value })
    })
    RSEconomyLog('policy_updated', 'Economisch beleid gewijzigd', ('%s zette %s op %s.'):format(displayName(xPlayer), key, value), {}, 'warning')
    return reply(true, 'Beleidsinstelling opgeslagen.')
end)

lib.callback.register('rs-economie:server:adminMutation', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAdmin(xPlayer) then return reply(false, Config.Text.no_access) end
    local amount = safeAmount(data.amount, Config.MaxTransfer)
    local targetId = tonumber(data.playerId)
    local target = targetId and ESX.GetPlayerFromId(targetId) or nil
    if not target or not amount then return reply(false, 'Speler of bedrag ongeldig.') end
    local action = data.action
    if action == 'add' then target.addAccountMoney('bank', amount, 'RS Economie beheer')
    elseif action == 'remove' then
        if bankBalance(target) < amount then return reply(false, Config.Text.insufficient) end
        target.removeAccountMoney('bank', amount, 'RS Economie beheer')
        amount = -amount
    else return reply(false, 'Ongeldige actie.') end
    addTransaction(identifierOf(target), 'admin', amount, 'Correctie door beheer', identifierOf(xPlayer), bankBalance(target))
    MySQL.insert.await('INSERT INTO rs_economy_audit (actor_identifier, actor_name, action, target_identifier, amount, details) VALUES (?, ?, ?, ?, ?, ?)', {
        identifierOf(xPlayer), displayName(xPlayer), 'balance_' .. action, identifierOf(target), amount, json.encode({ reason = data.reason or '' })
    })
    RSEconomyLog('admin_mutation', 'Saldo gecorrigeerd', ('%s corrigeerde het saldo van %s met %s%d.'):format(displayName(xPlayer), displayName(target), Config.Currency, amount), {}, 'danger')
    TriggerClientEvent('rs-economie:client:notify', target.source, 'Je banksaldo is door beheer aangepast.', 'inform')
    return reply(true, 'Saldo aangepast.')
end)

CreateThread(function()
    Wait(500)
    loadPolicies()
    while true do
        Wait(Config.InterestIntervalMinutes * 60000)
        local rate = tonumber(policies.savings_interest) or Config.DefaultSavingsInterest
        if rate > 0 then
            MySQL.update.await('UPDATE rs_economy_accounts SET savings = savings + ROUND(savings * ? / 100) WHERE savings > 0', { rate })
            RSEconomyLog('interest', 'Spaarrente uitgekeerd', ('Er is %s%% spaarrente uitgekeerd.'):format(rate), {}, 'success')
        end
        MySQL.update.await("UPDATE rs_economy_loans SET status = 'overdue' WHERE status = 'active' AND next_payment_at < NOW()")
    end
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
