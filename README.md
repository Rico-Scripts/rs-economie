# RS Economie

Complete economische beheerresource voor ESX Legacy, ontwikkeld door Rico Scripts.

## Functies

- Moderne, responsieve NUI voor spelers en beheerders
- Banksaldo, contant geld, spaarrekening en kredietscore
- Online en offline bankoverschrijvingen
- Spaarstortingen, opnames en automatische rente
- Leningen met configureerbare rente en looptijden
- Transactiehistorie en server-side auditlog
- Economisch beheerpaneel met belastingen, uitkering en rentetarieven
- Beveiligde saldo-correcties voor administrators
- Automatische integratie met `rs_discordlogs` en webhook-fallback
- Volledige server-side validatie en rate limiting

## Vereisten

- ESX Legacy
- ox_lib
- oxmysql
- Optioneel: rs_discordlogs

## Installatie

1. Plaats de map als `rs-economie` in je resources.
2. Importeer `sql/rs-economie.sql` of laat `rs_sql_manager` dit uitvoeren.
3. Voeg `ensure rs-economie` toe na ESX, ox_lib en oxmysql.
4. Pas `config.lua` aan.

Spelers openen het paneel met `/economie` of `F7`. Beheerders gebruiken `/economiebeheer`.

## Licentie

Copyright © 2026 Rico Scripts. Herdistributie, doorverkoop of publicatie onder een andere naam is niet toegestaan zonder schriftelijke toestemming.
