/// Default yearly leave allocation stored in organization_details/leave_config.
///
/// [carryForwardPL] and [carryForwardCompOff] decide what happens to unused
/// days when the next year's leave is assigned: carried over when true, reset
/// to 0 when false. Sick and casual leave always reset.
class LeaveConfigModel {
  final int privilegeLeaves;
  final int sickLeaves;
  final int casualLeaves;
  final bool carryForwardPL;
  final bool carryForwardCompOff;

  const LeaveConfigModel({
    required this.privilegeLeaves,
    required this.sickLeaves,
    required this.casualLeaves,
    this.carryForwardPL = false,
    this.carryForwardCompOff = false,
  });

  /// Returns null when the document is missing or incomplete.
  static LeaveConfigModel? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final pl = json['privilegeLeaves'];
    final sl = json['sickLeaves'];
    final cl = json['casualLeaves'];
    if (pl is! num || sl is! num || cl is! num) return null;
    return LeaveConfigModel(
      privilegeLeaves: pl.toInt(),
      sickLeaves: sl.toInt(),
      casualLeaves: cl.toInt(),
      carryForwardPL: json['carryForwardPL'] == true,
      carryForwardCompOff: json['carryForwardCompOff'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'privilegeLeaves': privilegeLeaves,
    'sickLeaves': sickLeaves,
    'casualLeaves': casualLeaves,
    'carryForwardPL': carryForwardPL,
    'carryForwardCompOff': carryForwardCompOff,
  };
}
