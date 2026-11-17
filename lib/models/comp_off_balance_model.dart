/// The comp off credit of one employee (users/{uid}/leaves/comp_off): days
/// earned, days used and what is left. Not tied to a year.
class CompOffBalanceModel {
  final num earned;
  final num used;
  final num balance;

  const CompOffBalanceModel({
    this.earned = 0,
    this.used = 0,
    this.balance = 0,
  });

  static num _num(dynamic v) => v is num ? v : 0;

  factory CompOffBalanceModel.fromFirestore(Map<String, dynamic> data) {
    return CompOffBalanceModel(
      earned: _num(data['earned']),
      used: _num(data['used']),
      balance: _num(data['balance']),
    );
  }
}
