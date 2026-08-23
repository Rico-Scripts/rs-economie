CREATE TABLE IF NOT EXISTS `rs_economy_accounts` (
  `identifier` varchar(80) NOT NULL,
  `savings` bigint NOT NULL DEFAULT 0,
  `credit_score` int NOT NULL DEFAULT 500,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_economy_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(80) NOT NULL,
  `type` varchar(40) NOT NULL,
  `amount` bigint NOT NULL,
  `description` varchar(180) NOT NULL,
  `counterparty` varchar(80) DEFAULT NULL,
  `balance_after` bigint NOT NULL DEFAULT 0,
  `metadata` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rs_economy_transactions_identifier` (`identifier`, `created_at`),
  KEY `idx_rs_economy_transactions_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_economy_loans` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(80) NOT NULL,
  `principal` bigint NOT NULL,
  `outstanding` bigint NOT NULL,
  `interest_rate` decimal(8,3) NOT NULL,
  `term_days` int NOT NULL,
  `payment_amount` bigint NOT NULL,
  `next_payment_at` datetime NOT NULL,
  `status` enum('active','overdue','paid','cancelled') NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rs_economy_loans_identifier` (`identifier`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_economy_policies` (
  `policy_key` varchar(50) NOT NULL,
  `policy_value` decimal(15,3) NOT NULL,
  `updated_by` varchar(80) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`policy_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_economy_audit` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `actor_identifier` varchar(80) NOT NULL,
  `actor_name` varchar(100) NOT NULL,
  `action` varchar(80) NOT NULL,
  `target_identifier` varchar(80) DEFAULT NULL,
  `amount` bigint DEFAULT NULL,
  `details` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rs_economy_audit_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `rs_economy_policies` (`policy_key`, `policy_value`) VALUES
('income_tax', 10.0), ('sales_tax', 5.0), ('wealth_tax', 0.0),
('benefit_amount', 500), ('loan_interest', 4.5), ('savings_interest', 0.5);
