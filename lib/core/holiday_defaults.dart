/// Default Indian holiday calendar.
///
/// Fixed-date national holidays are generated for any year. Festivals that follow
/// lunar / regional calendars (and Eid, which depends on moon sighting) only have
/// built-in dates for the years listed below — these are *indicative* and are
/// flagged in the description so the admin verifies/edits them for their region.
const _fixed = [
  ('Republic Day', '01-26', 'National'),
  ('Independence Day', '08-15', 'National'),
  ('Gandhi Jayanti', '10-02', 'National'),
  ('Christmas', '12-25', 'Festival'),
];

const _lunar = <int, List<(String, String, String)>>{
  2026: [
    ('Maha Shivratri', '02-15', 'Festival'),
    ('Holi', '03-04', 'Festival'),
    ('Eid-ul-Fitr', '03-21', 'Festival'),
    ('Ram Navami', '03-26', 'Festival'),
    ('Mahavir Jayanti', '03-31', 'Festival'),
    ('Good Friday', '04-03', 'Festival'),
    ('Buddha Purnima', '05-01', 'Festival'),
    ('Eid-ul-Adha (Bakrid)', '05-27', 'Festival'),
    ('Muharram', '06-26', 'Festival'),
    ('Raksha Bandhan', '08-28', 'Festival'),
    ('Janmashtami', '09-04', 'Festival'),
    ('Ganesh Chaturthi', '09-14', 'Festival'),
    ('Dussehra (Vijayadashami)', '10-20', 'Festival'),
    ('Diwali', '11-08', 'Festival'),
    ('Govardhan Puja', '11-10', 'Festival'),
    ('Bhai Dooj', '11-11', 'Festival'),
    ('Guru Nanak Jayanti', '11-24', 'Festival'),
  ],
};

bool hasLunarDefaults(int year) => _lunar.containsKey(year);

List<Map<String, dynamic>> defaultHolidays(int year) {
  Map<String, dynamic> m(String n, String md, String cat, String desc) => {
        'name': n,
        'date': '$year-$md',
        'category': cat,
        'description': desc,
        'region': 'All India',
        'paid': true,
        'assignedTo': <String>[],
      };
  return [
    for (final f in _fixed) m(f.$1, f.$2, f.$3, 'Fixed-date holiday'),
    for (final f in _lunar[year] ?? const []) m(f.$1, f.$2, f.$3, 'Indicative date (lunar/regional calendar) – verify and edit if needed'),
  ];
}

const indianRegions = [
  'All India', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat',
  'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra',
  'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu & Kashmir',
  'Ladakh', 'Chandigarh', 'Puducherry',
];
