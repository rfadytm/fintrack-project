-- ============================================================
-- FinTrack — 05_seed_transfer_fees.sql
-- transfer_fee_rules (10 rules). Fee dikreditkan ke beban 5820.
-- 1110=Tunai, 1120=BNI, 1130=SeaBank, 1140=Tabungan
-- ============================================================

INSERT INTO transfer_fee_rules (from_account, to_account, fee_amount, fee_account, method_label) VALUES
('1120', '1120',    0, NULL,   'Sesama BNI (gratis)'),
('1130', '1130',    0, NULL,   'Sesama SeaBank (gratis)'),
('1120', '1130', 2500, '5820', 'BI-Fast BNI->SeaBank'),
('1130', '1120',    0, NULL,   'Gratis SeaBank (kuota 100x/bln)'),
('1120', '1140', 2500, '5820', 'BI-Fast BNI->Tabungan'),
('1140', '1120',    0, NULL,   'Transfer balik (asumsi gratis)'),
('1110', '1120',    0, NULL,   'Setor Tunai'),
('1110', '1130',    0, NULL,   'Setor Tunai'),
('1120', '1110',    0, NULL,   'Tarik Tunai BNI'),
('1130', '1110',    0, NULL,   'Tarik Tunai SeaBank');
