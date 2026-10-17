class SupportedBank {
  final String code;
  final String name;
  final String bin;

  const SupportedBank({
    required this.code,
    required this.name,
    required this.bin,
  });

  String get label => '$name ($code)';
}

// BIN snapshots for payout destinations supported by VietQR/payOS. Keep this
// list explicit so a withdrawal never sends a bank name in place of a BIN.
const supportedPayoutBanks = <SupportedBank>[
  SupportedBank(code: 'VCB', name: 'Vietcombank', bin: '970436'),
  SupportedBank(code: 'BIDV', name: 'BIDV', bin: '970418'),
  SupportedBank(code: 'ICB', name: 'VietinBank', bin: '970415'),
  SupportedBank(code: 'VBA', name: 'Agribank', bin: '970405'),
  SupportedBank(code: 'MB', name: 'MBBank', bin: '970422'),
  SupportedBank(code: 'TCB', name: 'Techcombank', bin: '970407'),
  SupportedBank(code: 'ACB', name: 'ACB', bin: '970416'),
  SupportedBank(code: 'VPB', name: 'VPBank', bin: '970432'),
  SupportedBank(code: 'TPB', name: 'TPBank', bin: '970423'),
  SupportedBank(code: 'STB', name: 'Sacombank', bin: '970403'),
  SupportedBank(code: 'HDB', name: 'HDBank', bin: '970437'),
  SupportedBank(code: 'VIB', name: 'VIB', bin: '970441'),
  SupportedBank(code: 'SHB', name: 'SHB', bin: '970443'),
  SupportedBank(code: 'MSB', name: 'MSB', bin: '970426'),
  SupportedBank(code: 'OCB', name: 'OCB', bin: '970448'),
  SupportedBank(code: 'EIB', name: 'Eximbank', bin: '970431'),
  SupportedBank(code: 'LPB', name: 'LPBank', bin: '970449'),
  SupportedBank(code: 'SEAB', name: 'SeABank', bin: '970440'),
  SupportedBank(code: 'KLB', name: 'KienLongBank', bin: '970452'),
  SupportedBank(code: 'NAB', name: 'Nam A Bank', bin: '970428'),
  SupportedBank(code: 'NCB', name: 'NCB', bin: '970419'),
  SupportedBank(code: 'PVCB', name: 'PVcomBank', bin: '970412'),
  SupportedBank(code: 'ABB', name: 'ABBANK', bin: '970425'),
  SupportedBank(code: 'VAB', name: 'VietABank', bin: '970427'),
  SupportedBank(code: 'PGB', name: 'PGBank', bin: '970430'),
  SupportedBank(code: 'VIETBANK', name: 'VietBank', bin: '970433'),
  SupportedBank(code: 'BVB', name: 'BaoVietBank', bin: '970438'),
  SupportedBank(code: 'SGICB', name: 'SaigonBank', bin: '970400'),
  SupportedBank(code: 'BAB', name: 'Bac A Bank', bin: '970409'),
  SupportedBank(code: 'COOPBANK', name: 'Co-opBank', bin: '970446'),
  SupportedBank(code: 'SHBVN', name: 'Shinhan Bank', bin: '970424'),
  SupportedBank(code: 'WVN', name: 'Woori Bank', bin: '970457'),
  SupportedBank(code: 'CIMB', name: 'CIMB', bin: '422589'),
  SupportedBank(code: 'IVB', name: 'Indovina Bank', bin: '970434'),
  SupportedBank(code: 'KBANK', name: 'KBank', bin: '668888'),
  SupportedBank(code: 'MBV', name: 'MBV', bin: '970414'),
  SupportedBank(code: 'CBB', name: 'Vietcombank Neo', bin: '970444'),
  SupportedBank(code: 'CAKE', name: 'CAKE by VPBank', bin: '546034'),
  SupportedBank(code: 'UBANK', name: 'Ubank by VPBank', bin: '546035'),
];
