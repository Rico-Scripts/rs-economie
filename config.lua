Config = {}

Config.Locale = 'nl'
Config.Command = 'economie'
Config.AdminCommand = 'economiebeheer'
Config.OpenKey = 'F7'
Config.Currency = '€'
Config.MaxTransactionHistory = 75
Config.TransferCooldown = 2
Config.MaxTransfer = 500000
Config.MaxSavingsMutation = 500000
Config.MaxLoan = 250000
Config.MinLoan = 1000
Config.MaxActiveLoans = 2
Config.LoanTermDays = { 7, 14, 30, 60 }
Config.LoanPaymentIntervalHours = 24
Config.DefaultInterest = 4.5
Config.DefaultSavingsInterest = 0.5
Config.InterestIntervalMinutes = 1440
Config.AllowOfflineTransfers = true

Config.AdminGroups = {
    admin = true,
    superadmin = true
}

Config.DefaultPolicies = {
    income_tax = 10.0,
    sales_tax = 5.0,
    wealth_tax = 0.0,
    benefit_amount = 500,
    loan_interest = 4.5,
    savings_interest = 0.5
}

Config.Webhook = '' -- Alleen fallback; rs_discordlogs wordt automatisch gebruikt indien actief.
Config.WebhookName = 'RS Economie'
Config.WebhookAvatar = ''
Config.LogColors = {
    success = 5763719,
    info = 3447003,
    warning = 16776960,
    danger = 15548997
}

Config.Text = {
    no_access = 'Je hebt hier geen toegang toe.',
    invalid_amount = 'Vul een geldig bedrag in.',
    insufficient = 'Onvoldoende saldo.',
    transferred = 'Overschrijving voltooid.',
    saved = 'Bedrag naar je spaarrekening verplaatst.',
    withdrawn = 'Bedrag van je spaarrekening opgenomen.',
    loan_created = 'Lening is goedgekeurd en uitbetaald.',
    too_many_loans = 'Je hebt het maximale aantal actieve leningen.',
    player_missing = 'Ontvanger niet gevonden.',
    same_player = 'Je kunt niet naar jezelf overboeken.',
    cooldown = 'Wacht even voordat je opnieuw geld overmaakt.'
}
