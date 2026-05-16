class TurkeyLocations {
  const TurkeyLocations._();

  static const cities = [
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkari',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];

  static const districtsByCity = {
    'Ankara': [
      'Altındağ',
      'Çankaya',
      'Etimesgut',
      'Gölbaşı',
      'Keçiören',
      'Mamak',
      'Pursaklar',
      'Sincan',
      'Yenimahalle',
    ],
    'İstanbul': [
      'Ataşehir',
      'Bakırköy',
      'Beşiktaş',
      'Beyoğlu',
      'Kadıköy',
      'Kartal',
      'Maltepe',
      'Sarıyer',
      'Şişli',
      'Üsküdar',
    ],
    'İzmir': [
      'Balçova',
      'Bornova',
      'Buca',
      'Çeşme',
      'Karşıyaka',
      'Konak',
      'Narlıdere',
      'Urla',
    ],
    'Bursa': [
      'Gemlik',
      'İnegöl',
      'Mudanya',
      'Nilüfer',
      'Osmangazi',
      'Yıldırım',
    ],
    'Antalya': [
      'Alanya',
      'Kepez',
      'Konyaaltı',
      'Manavgat',
      'Muratpaşa',
      'Serik',
    ],
    'Konya': [
      'Karatay',
      'Meram',
      'Selçuklu',
      'Akşehir',
      'Ereğli',
    ],
    'Adana': [
      'Çukurova',
      'Sarıçam',
      'Seyhan',
      'Yüreğir',
    ],
    'Kocaeli': [
      'Başiskele',
      'Darıca',
      'Derince',
      'Gebze',
      'İzmit',
      'Kartepe',
    ],
    'Eskişehir': [
      'Odunpazarı',
      'Tepebaşı',
    ],
    'Muğla': [
      'Bodrum',
      'Dalaman',
      'Fethiye',
      'Marmaris',
      'Menteşe',
      'Milas',
    ],
  };

  static List<String> searchCities(String query) {
    return _search(cities, query);
  }

  static List<String> getDistrictsForCity(String city) {
    return districtsByCity[city] ?? const [];
  }

  static List<String> searchDistricts(String city, String query) {
    return _search(getDistrictsForCity(city), query);
  }

  static bool hasDistrictData(String city) {
    return getDistrictsForCity(city).isNotEmpty;
  }

  static List<String> _search(List<String> values, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return values;

    final startsWith = <String>[];
    final contains = <String>[];
    for (final value in values) {
      final normalizedValue = _normalize(value);
      if (normalizedValue.startsWith(normalizedQuery)) {
        startsWith.add(value);
      } else if (normalizedValue.contains(normalizedQuery)) {
        contains.add(value);
      }
    }
    return [...startsWith, ...contains];
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }
}
