/// A short list of major Moroccan cities for manual prayer-time location
/// selection — replaces GPS entirely (see prayer_times_service.dart), since
/// the app has no other real need for the user's precise location.
class MoroccanCity {
  final String nameAr;
  final String aladhanName; // the Latin spelling Aladhan's API expects

  const MoroccanCity({required this.nameAr, required this.aladhanName});
}

const List<MoroccanCity> moroccanCities = [
  MoroccanCity(nameAr: 'الدار البيضاء', aladhanName: 'Casablanca'),
  MoroccanCity(nameAr: 'الرباط', aladhanName: 'Rabat'),
  MoroccanCity(nameAr: 'فاس', aladhanName: 'Fes'),
  MoroccanCity(nameAr: 'مراكش', aladhanName: 'Marrakesh'),
  MoroccanCity(nameAr: 'طنجة', aladhanName: 'Tangier'),
  MoroccanCity(nameAr: 'أكادير', aladhanName: 'Agadir'),
  MoroccanCity(nameAr: 'مكناس', aladhanName: 'Meknes'),
  MoroccanCity(nameAr: 'وجدة', aladhanName: 'Oujda'),
  MoroccanCity(nameAr: 'تطوان', aladhanName: 'Tetouan'),
  MoroccanCity(nameAr: 'القنيطرة', aladhanName: 'Kenitra'),
];
