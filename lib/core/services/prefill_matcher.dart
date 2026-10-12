import 'package:intl/intl.dart';

import '../models/field_model.dart';

/// What a form field asks for, in terms of the user's saved My Details.
///
/// Some slots are composites built from several details ([fullName],
/// [cityStateZip], [address] on a form with no separate city box, ...).
enum PrefillSlot {
  fullName,
  firstName,
  firstAndMiddleInitial,
  middleName,
  middleInitial,
  lastName,
  email,
  phone,
  address,
  addressLine2,
  city,
  state,
  zip,
  cityStateZip,
  country,
  company,
  jobTitle,
  dateOfBirth,
  age,
}

/// The user's own details, as saved in Settings → My Details. All optional.
class MyDetails {
  const MyDetails({
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = '',
    this.company = '',
    this.jobTitle = '',
    this.dateOfBirth,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String company;
  final String jobTitle;
  final DateTime? dateOfBirth;

  bool get isEmpty => PrefillSlot.values.every((s) => valueFor(s) == null);

  /// The text to put in a field asking for [slot], or null when the details
  /// needed for it aren't saved. [dateFormat] writes the date of birth in
  /// the form's date style; [today] is for computing an age.
  String? valueFor(
    PrefillSlot slot, {
    DateFormat? dateFormat,
    DateTime? today,
  }) {
    String? orNull(String s) {
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    String joined(Iterable<String> parts, String sep) =>
        parts.map((p) => p.trim()).where((p) => p.isNotEmpty).join(sep);

    final middle = middleName.trim();
    final initial = middle.isEmpty
        ? ''
        : String.fromCharCode(middle.runes.first).toUpperCase();

    switch (slot) {
      case PrefillSlot.fullName:
        return orNull(joined([firstName, middleName, lastName], ' '));
      case PrefillSlot.firstName:
        return orNull(firstName);
      case PrefillSlot.firstAndMiddleInitial:
        return orNull(joined([firstName, initial], ' '));
      case PrefillSlot.middleName:
        return orNull(middleName);
      case PrefillSlot.middleInitial:
        return orNull(initial);
      case PrefillSlot.lastName:
        return orNull(lastName);
      case PrefillSlot.email:
        return orNull(email);
      case PrefillSlot.phone:
        return orNull(phone);
      case PrefillSlot.address:
        return orNull(joined([addressLine1, addressLine2], ', '));
      case PrefillSlot.addressLine2:
        return orNull(addressLine2);
      case PrefillSlot.city:
        return orNull(city);
      case PrefillSlot.state:
        return orNull(state);
      case PrefillSlot.zip:
        return orNull(zip);
      case PrefillSlot.cityStateZip:
        // "Austin, TX 78701"
        return orNull(
          joined([
            city,
            joined([state, zip], ' '),
          ], ', '),
        );
      case PrefillSlot.country:
        return orNull(country);
      case PrefillSlot.company:
        return orNull(company);
      case PrefillSlot.jobTitle:
        return orNull(jobTitle);
      case PrefillSlot.dateOfBirth:
        final dob = dateOfBirth;
        if (dob == null) return null;
        return (dateFormat ?? DateFormat('yyyy-MM-dd')).format(dob);
      case PrefillSlot.age:
        final dob = dateOfBirth;
        if (dob == null) return null;
        final now = today ?? DateTime.now();
        var years = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          years--;
        }
        return years < 0 ? null : '$years';
    }
  }

  /// [address] on a form that has no separate city / state / ZIP boxes: the
  /// whole address on one line.
  String? fullAddress() {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      [state, zip].map((p) => p.trim()).where((p) => p.isNotEmpty).join(' '),
      country,
    ].map((p) => p.trim()).where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// A form field, as far as PreFill is concerned.
class PrefillField {
  const PrefillField({
    required this.id,
    required this.label,
    required this.type,
  });
  final int id;
  final String label;
  final FieldType type;
}

/// Maps form-field labels to [PrefillSlot]s, in the app's 7 languages.
///
/// Pure Dart. Matching is on whole words of the normalised label (lowercase,
/// no punctuation), most specific phrase first. A label about someone else
/// ("Father's name", "Employer's address", "Emergency contact phone") never
/// matches: PreFill only ever writes the user's own details.
class PrefillMatcher {
  const PrefillMatcher._();

  /// Lowercase, punctuation to spaces, apostrophes dropped ("employer's" →
  /// "employers"), whitespace collapsed. Letters and combining marks of any
  /// script are kept, so Indic labels survive.
  static String normalise(String label) => label
      .toLowerCase()
      .replaceAll(RegExp("['’`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
      .trim();

  /// The label's words, without leading item numbers ("3a", "6b", "12").
  static List<String> _words(String label) {
    final words = normalise(
      label,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    while (words.isNotEmpty && RegExp(r'\d').hasMatch(words.first)) {
      words.removeAt(0);
    }
    return words;
  }

  /// Where [phrase] counts in a label of [words]. A one-word phrase in a
  /// long label ("3a Enter $6,000 if you are age") is part of a sentence,
  /// not the thing asked for — unless the label starts with it.
  static bool _asks(List<String> words, String phrase) {
    if (!_has(words, phrase)) return false;
    if (phrase.contains(' ') || words.length <= 4) return true;
    return words.first == phrase;
  }

  /// Whether [phrase] (space-separated words) occurs as consecutive whole
  /// words in [words].
  static bool _has(List<String> words, String phrase) {
    final p = phrase.split(' ');
    for (var i = 0; i + p.length <= words.length; i++) {
      var ok = true;
      for (var j = 0; j < p.length; j++) {
        if (words[i + j] != p[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  static bool _any(List<String> words, List<String> phrases) =>
      phrases.any((p) => _has(words, p));

  /// Labels about another person or organisation, never filled with the
  /// user's details.
  static const _someoneElse = [
    // en
    'father', 'fathers', 'mother', 'mothers', 'spouse', 'spouses',
    'husband', 'husbands', 'wife', 'wifes', 'guardian', 'guardians',
    'parent', 'parents', 'nominee', 'witness', 'child', 'childs',
    'children', 'son', 'daughter', 'emergency', 'reference', 'landlord',
    'landlords', 'bank', 'employers', 'beneficiary', 'agent', 'doctor',
    'physician', 'previous', 'former', 'contact person',
    // Money lines on tax and finance forms ("6b State and local taxes")
    // never ask for a personal detail.
    'tax', 'taxes', 'income', 'amount', 'amounts', 'total', 'wages',
    'deduction', 'deductions', 'credit', 'credits', 'withholding', 'refund',
    'fee', 'fees', 'price', 'impôt', 'impôts', 'montant', 'impuesto',
    'impuestos', 'importe', 'imposto', 'valor', 'कर', 'राशि',
    // fr
    'père', 'mère', 'conjoint', 'époux', 'épouse', 'tuteur', 'enfant',
    'témoin', 'banque', 'urgence', 'employeur',
    // es
    'padre', 'madre', 'cónyuge', 'esposo', 'esposa', 'tutor', 'hijo',
    'hija', 'testigo', 'banco', 'emergencia', 'empleador',
    // pt
    'pai', 'mãe', 'cônjuge', 'marido', 'filho', 'filha', 'testemunha',
    'emergência', 'empregador',
    // hi
    'पिता', 'माता', 'पति', 'पत्नी', 'अभिभावक', 'नामांकित', 'गवाह',
    'बैंक',
    // ta
    'தந்தை', 'தாய்', 'கணவர்', 'மனைவி', 'பாதுகாவலர்', 'சாட்சி',
    // te
    'తండ్రి', 'తల్లి', 'భర్త', 'భార్య', 'సంరక్షకుడు', 'సాక్షి',
  ];

  static const _explicitFullNames = [
    'full name',
    'name in full',
    'first and last name',
    'first name and last name',
    'name and surname',
    'nom et prénom',
    'nom prénom',
    'prénom et nom',
    'prénom nom',
    'nom complet',
    'nombre completo',
    'nombre y apellidos',
    'nombre y apellido',
    'nome completo',
    'पूरा नाम',
    'முழுப் பெயர்',
    'పూర్తి పేరు',
  ];

  // Most specific first: the first rule whose phrase occurs wins.
  static const _rules = <(PrefillSlot, List<String>)>[
    (
      PrefillSlot.email,
      [
        'email',
        'e mail',
        'mail id',
        'courriel',
        'correo',
        'correo electrónico',
        'ईमेल',
        'ई मेल',
        'மின்னஞ்சல்',
        'ఈమెయిల్',
        'ఇమెయిల్',
      ],
    ),
    (
      PrefillSlot.dateOfBirth,
      [
        'date of birth',
        'birth date',
        'birthdate',
        'dob',
        'd o b',
        'born on',
        'date de naissance',
        'né le',
        'née le',
        'fecha de nacimiento',
        'data de nascimento',
        'जन्म तिथि',
        'जन्म की तारीख',
        'जन्म दिनांक',
        'பிறந்த தேதி',
        'பிறந்த நாள்',
        'పుట్టిన తేదీ',
        'జన్మ తేదీ',
      ],
    ),
    (
      PrefillSlot.age,
      ['age', 'âge', 'edad', 'idade', 'आयु', 'उम्र', 'வயது', 'వయస్సు'],
    ),
    // Explicit whole names before the first-name rule: "Nom et prénom" and
    // "Nombre y apellidos" contain "prénom" / "apellidos" but ask for both.
    (PrefillSlot.fullName, _explicitFullNames),
    (
      PrefillSlot.firstAndMiddleInitial,
      [
        'first name and middle initial',
        'first name and initial',
        'first name mi',
        'first name m i',
      ],
    ),
    (PrefillSlot.middleInitial, ['middle initial', 'mi', 'm i']),
    (
      PrefillSlot.middleName,
      [
        'middle name',
        'second name',
        'deuxième prénom',
        'segundo nombre',
        'nome do meio',
        'मध्य नाम',
      ],
    ),
    (
      PrefillSlot.firstName,
      [
        'first name',
        'given name',
        'given names',
        'forename',
        'forenames',
        'prénom',
        'prénoms',
        'primer nombre',
        'nombres',
        'nombre s',
        'primeiro nome',
        'nome próprio',
        'पहला नाम',
        'प्रथम नाम',
        'முதல் பெயர்',
        'మొదటి పేరు',
      ],
    ),
    (
      PrefillSlot.lastName,
      [
        'last name',
        'surname',
        'family name',
        'nom de famille',
        'apellido',
        'apellidos',
        'apelido',
        'apelidos',
        'sobrenome',
        'último nome',
        'उपनाम',
        'कुलनाम',
        'குடும்பப் பெயர்',
        'இறுதிப் பெயர்',
        'ఇంటి పేరు',
      ],
    ),
    (
      PrefillSlot.cityStateZip,
      [
        // Whole-label composites; also caught below by co-occurrence.
        'city state zip', 'city state and zip', 'city state zip code',
        'city or town state and zip code',
      ],
    ),
    (
      PrefillSlot.addressLine2,
      [
        'address line 2',
        'address 2',
        'apt',
        'apartment',
        'suite',
        'unit',
        'apt no',
        'flat',
        'flat no',
        'appartement',
        'apartamento',
        'piso',
        'complemento',
      ],
    ),
    (
      PrefillSlot.zip,
      [
        'zip',
        'zip code',
        'zipcode',
        'postal code',
        'postcode',
        'post code',
        'pin',
        'pin code',
        'pincode',
        'code postal',
        'código postal',
        'cep',
        'पिन',
        'पिन कोड',
        'पिनकोड',
        'அஞ்சல் குறியீடு',
        'பின்கோடு',
        'పిన్',
        'పిన్ కోడ్',
        'పిన్‌కోడ్',
      ],
    ),
    (
      PrefillSlot.city,
      [
        'city',
        'town',
        'city or town',
        'ville',
        'ciudad',
        'localidad',
        'cidade',
        'localidade',
        'शहर',
        'नगर',
        'நகரம்',
        'ஊர்',
        'నగరం',
        'పట్టణం',
      ],
    ),
    (
      PrefillSlot.state,
      [
        'state',
        'province',
        'state province',
        'état',
        'région',
        'estado',
        'provincia',
        'província',
        'राज्य',
        'மாநிலம்',
        'రాష్ట్రం',
      ],
    ),
    (PrefillSlot.country, ['country', 'pays', 'país', 'देश', 'நாடு', 'దేశం']),
    (
      PrefillSlot.address,
      [
        'address',
        'home address',
        'street address',
        'residential address',
        'mailing address',
        'street',
        'address line 1',
        'address 1',
        'adresse',
        'dirección',
        'domicilio',
        'endereço',
        'morada',
        'पता',
        'निवास',
        'முகவரி',
        'చిరునామా',
      ],
    ),
    (
      PrefillSlot.phone,
      [
        'phone',
        'telephone',
        'tel',
        'mobile',
        'cell',
        'contact number',
        'phone number',
        'mobile number',
        'téléphone',
        'portable',
        'teléfono',
        'celular',
        'móvil',
        'telefone',
        'telemóvel',
        'फ़ोन',
        'फोन',
        'मोबाइल',
        'दूरभाष',
        'தொலைபேசி',
        'கைபேசி',
        'அலைபேசி',
        'ఫోన్',
        'మొబైల్',
      ],
    ),
    (
      PrefillSlot.jobTitle,
      [
        'job title',
        'designation',
        'occupation',
        'position',
        'profession',
        'poste',
        'fonction',
        'cargo',
        'puesto',
        'ocupación',
        'profesión',
        'profissão',
        'ocupação',
        'पद',
        'पदनाम',
        'व्यवसाय',
        'பதவி',
        'தொழில்',
        'హోదా',
        'వృత్తి',
      ],
    ),
    (
      PrefillSlot.company,
      [
        'company',
        'company name',
        'organisation',
        'organization',
        'current employer',
        'employer name',
        'société',
        'entreprise',
        'empresa',
        'compañía',
        'कंपनी',
        'संस्था',
        'நிறுவனம்',
        'కంపెనీ',
        'సంస్థ',
      ],
    ),
    (
      PrefillSlot.fullName,
      [
        'name',
        'your name',
        'applicant name',
        'name of applicant',
        'print name',
        'printed name',
        'nom',
        'nombre',
        'nome',
        'नाम',
        'பெயர்',
        'పేరు',
      ],
    ),
  ];

  /// The slot a single [label] asks for, ignoring the rest of the form.
  static PrefillSlot? matchLabel(String label) {
    final words = _words(label);
    if (words.isEmpty || _any(words, _someoneElse)) return null;
    // "City, state, and ZIP code" in one box, however it's worded.
    final mentions = [
      _has(words, 'city') || _has(words, 'town'),
      _has(words, 'state') || _has(words, 'province'),
      _has(words, 'zip') || _has(words, 'postal') || _has(words, 'pin'),
    ].where((b) => b).length;
    if (mentions >= 2) return PrefillSlot.cityStateZip;
    for (final (slot, phrases) in _rules) {
      // Email and date of birth are unmistakable wherever they appear.
      final loose =
          slot == PrefillSlot.email || slot == PrefillSlot.dateOfBirth;
      if (phrases.any((p) => loose ? _has(words, p) : _asks(words, p))) {
        // French "Nom" alone is the family name; "Nom complet" isn't.
        if (slot == PrefillSlot.fullName &&
            words.length == 1 &&
            words.first == 'nom') {
          return PrefillSlot.lastName;
        }
        return slot;
      }
    }
    return null;
  }

  /// Slots for every field of a form, using the form as context:
  /// - a plain "Name" on a form that also asks for the last name is the
  ///   first name ("Nombre" + "Apellidos");
  /// - "Address" on a form with no city / ZIP boxes gets the whole address.
  ///
  /// Only text fields are matched, plus date fields asking for the date of
  /// birth. Signatures, checkboxes and the like never are.
  static Map<int, PrefillSlot> matchForm(List<PrefillField> fields) {
    final slots = <int, PrefillSlot>{};
    for (final f in fields) {
      final slot = matchLabel(f.label);
      if (slot == null) continue;
      final ok = switch (f.type) {
        FieldType.text => true,
        FieldType.date => slot == PrefillSlot.dateOfBirth,
        _ => false,
      };
      if (ok) slots[f.id] = slot;
    }
    if (slots.values.contains(PrefillSlot.lastName)) {
      for (final f in fields) {
        if (slots[f.id] == PrefillSlot.fullName &&
            !_isExplicitFullName(f.label)) {
          slots[f.id] = PrefillSlot.firstName;
        }
      }
    }
    return slots;
  }

  /// "Full name", "Nom et prénom" ... — a whole name even beside a
  /// last-name box.
  static bool _isExplicitFullName(String label) =>
      _any(_words(label), _explicitFullNames);

  /// The value for field [id] on a form whose fields were matched by
  /// [matchForm], or null if the user hasn't saved what it needs.
  static String? valueForField(
    List<PrefillField> fields,
    Map<int, PrefillSlot> slots,
    int id,
    MyDetails details, {
    DateFormat? dateFormat,
    DateTime? today,
  }) {
    final slot = slots[id];
    if (slot == null) return null;
    if (slot == PrefillSlot.address) {
      final asksCity = slots.values.any(
        (s) =>
            s == PrefillSlot.city ||
            s == PrefillSlot.cityStateZip ||
            s == PrefillSlot.zip,
      );
      final asksLine2 = slots.values.contains(PrefillSlot.addressLine2);
      if (!asksCity) return details.fullAddress();
      if (asksLine2) {
        final l1 = details.addressLine1.trim();
        return l1.isEmpty ? null : l1;
      }
    }
    return details.valueFor(slot, dateFormat: dateFormat, today: today);
  }
}
