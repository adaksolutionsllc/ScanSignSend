import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/prefill_matcher.dart';
import 'package:scan_sign_send/core/services/import_service.dart';

void main() {
  PrefillSlot? m(String label) => PrefillMatcher.matchLabel(label);

  const priya = MyDetails(
    firstName: 'Priya',
    middleName: 'kumari',
    lastName: 'Raman',
    email: 'priya@example.com',
    phone: '+1 512 555 0100',
    addressLine1: '12 Elm Street',
    addressLine2: 'Apt 4',
    city: 'Austin',
    state: 'TX',
    zip: '78701',
    country: 'USA',
    company: 'Acme Corp',
    jobTitle: 'Engineer',
    dateOfBirth: null,
  );

  group('labels on the 2026 IRS W-4 (as the app labels them)', () {
    test('step 1 boxes', () {
      expect(
        m('First name and middle initial'),
        PrefillSlot.firstAndMiddleInitial,
      );
      expect(m('Last name'), PrefillSlot.lastName);
      expect(m('Address'), PrefillSlot.address);
      expect(m('City or town, state, and ZIP code'), PrefillSlot.cityStateZip);
    });

    test('nothing the user should type themselves', () {
      expect(m('Social security number'), isNull);
      expect(m('3(a) Multiply the number of qualifying children'), isNull);
      expect(m("Employer's name and address"), isNull);
      expect(m('Employer identification number (EIN)'), isNull);
      expect(m('First date of employment'), isNull);
    });

    test('worksheet lines on pages 3–4 are not personal details', () {
      expect(m(r'3a Enter $6,000 if you are age 65 or older'), isNull);
      expect(m('6b State and local taxes'), isNull);
      expect(m('1 Enter an estimate of your 2026 itemized deductions'), isNull);
      expect(m('Enter the amount from line 3 of the worksheet'), isNull);
    });
  });

  test('the real 2026 W-4: only the four Step 1 boxes match', () {
    // Every label the app gives the IRS form (test/fixtures, public domain),
    // as text fields — the worst case.
    final labels = [
      for (final (_, label) in ImportService.formFieldLabels(
        'test/fixtures/irs_fw4_2026.pdf',
      ))
        label,
    ];
    expect(labels.length, greaterThan(40));
    final fields = [
      for (var i = 0; i < labels.length; i++)
        PrefillField(id: i, label: labels[i], type: FieldType.text),
    ];
    final matched = {
      for (final e in PrefillMatcher.matchForm(fields).entries)
        labels[e.key]: e.value,
    };
    expect(matched, {
      'First name and middle initial': PrefillSlot.firstAndMiddleInitial,
      'Last name': PrefillSlot.lastName,
      'Address': PrefillSlot.address,
      'City or town, state, and ZIP code': PrefillSlot.cityStateZip,
    });
  });

  group('English', () {
    test('names', () {
      expect(m('Full Name'), PrefillSlot.fullName);
      expect(m('Name:'), PrefillSlot.fullName);
      expect(m('Print name'), PrefillSlot.fullName);
      expect(m('Given name(s)'), PrefillSlot.firstName);
      expect(m('Surname'), PrefillSlot.lastName);
      expect(m('Middle name'), PrefillSlot.middleName);
      expect(m('M.I.'), PrefillSlot.middleInitial);
    });

    test('contact and address', () {
      expect(m('E-mail address'), PrefillSlot.email);
      expect(m('Mobile No.'), PrefillSlot.phone);
      expect(m('Home address'), PrefillSlot.address);
      expect(m('Apt / Suite'), PrefillSlot.addressLine2);
      expect(m('City'), PrefillSlot.city);
      expect(m('State/Province'), PrefillSlot.state);
      expect(m('ZIP Code'), PrefillSlot.zip);
      expect(m('PIN code'), PrefillSlot.zip);
      expect(m('Country'), PrefillSlot.country);
    });

    test('work and personal', () {
      expect(m('Company name'), PrefillSlot.company);
      expect(m('Employer'), PrefillSlot.company);
      expect(m('PAN'), isNull);
      expect(m('Passport No.'), isNull);
      expect(m('Aadhaar number'), isNull);
      expect(m('Account number'), isNull);
      expect(m('Current employer'), PrefillSlot.company);
      expect(m('Designation'), PrefillSlot.jobTitle);
      expect(m('Date of Birth'), PrefillSlot.dateOfBirth);
      expect(m('DOB'), PrefillSlot.dateOfBirth);
      expect(m('Age'), PrefillSlot.age);
    });

    test('item numbers and long sentences', () {
      expect(m('1. Name'), PrefillSlot.fullName);
      expect(m('2(a) Date of birth'), PrefillSlot.dateOfBirth);
      expect(m('State of residence'), PrefillSlot.state);
      expect(m('Please write your email address here'), PrefillSlot.email);
      expect(m('I confirm that the information I gave is true'), isNull);
      expect(m('The city where the property is located'), isNull);
    });

    test('whole words only', () {
      expect(m('Page'), isNull); // not "age"
      expect(m('Statement'), isNull); // not "state"
      expect(m('Signature'), isNull);
      expect(m('Date'), isNull);
      expect(m('Amount'), isNull);
    });

    test('someone else is never the user', () {
      for (final label in [
        "Father's name",
        "Mother's maiden name",
        'Spouse name',
        'Emergency contact phone',
        'Name of nominee',
        'Witness name',
        'Bank name',
        "Landlord's address",
        'Previous address',
        "Guardian's mobile",
      ]) {
        expect(m(label), isNull, reason: label);
      }
    });
  });

  group('the other six languages', () {
    test('French', () {
      expect(m('Nom'), PrefillSlot.lastName);
      expect(m('Prénom'), PrefillSlot.firstName);
      expect(m('Nom et prénom'), PrefillSlot.fullName);
      expect(m('Adresse'), PrefillSlot.address);
      expect(m('Code postal'), PrefillSlot.zip);
      expect(m('Ville'), PrefillSlot.city);
      expect(m('Date de naissance'), PrefillSlot.dateOfBirth);
      expect(m('Téléphone'), PrefillSlot.phone);
      expect(m('Nom du père'), isNull);
      expect(m('Employeur'), PrefillSlot.company);
    });

    test('Spanish', () {
      expect(m('Nombre(s)'), PrefillSlot.firstName);
      expect(m('Apellidos'), PrefillSlot.lastName);
      expect(m('Nombre y apellidos'), PrefillSlot.fullName);
      expect(m('Dirección'), PrefillSlot.address);
      expect(m('Fecha de nacimiento'), PrefillSlot.dateOfBirth);
      expect(m('Correo electrónico'), PrefillSlot.email);
      expect(m('Nombre del padre'), isNull);
    });

    test('Portuguese', () {
      expect(m('Nome completo'), PrefillSlot.fullName);
      expect(m('Sobrenome'), PrefillSlot.lastName);
      expect(m('Endereço'), PrefillSlot.address);
      expect(m('Data de nascimento'), PrefillSlot.dateOfBirth);
      expect(m('Nome da mãe'), isNull);
    });

    test('Hindi', () {
      expect(m('नाम'), PrefillSlot.fullName);
      expect(m('पूरा नाम'), PrefillSlot.fullName);
      expect(m('पता'), PrefillSlot.address);
      expect(m('मोबाइल नंबर'), PrefillSlot.phone);
      expect(m('जन्म तिथि'), PrefillSlot.dateOfBirth);
      expect(m('पिता का नाम'), isNull);
    });

    test('Tamil', () {
      expect(m('பெயர்'), PrefillSlot.fullName);
      expect(m('முகவரி'), PrefillSlot.address);
      expect(m('பிறந்த தேதி'), PrefillSlot.dateOfBirth);
      expect(m('தந்தை பெயர்'), isNull);
    });

    test('Telugu', () {
      expect(m('పేరు'), PrefillSlot.fullName);
      expect(m('చిరునామా'), PrefillSlot.address);
      expect(m('పుట్టిన తేదీ'), PrefillSlot.dateOfBirth);
      expect(m('తండ్రి పేరు'), isNull);
    });
  });

  group('the form as context', () {
    List<PrefillField> form(List<(String, FieldType)> labels) => [
      for (var i = 0; i < labels.length; i++)
        PrefillField(id: i, label: labels[i].$1, type: labels[i].$2),
    ];

    test('"Name" beside "Last name" is the first name', () {
      final f = form([
        ('Name', FieldType.text),
        ('Last name', FieldType.text),
      ]);
      expect(PrefillMatcher.matchForm(f), {
        0: PrefillSlot.firstName,
        1: PrefillSlot.lastName,
      });
    });

    test('"Full name" stays the full name beside "Last name"', () {
      final f = form([
        ('Full name', FieldType.text),
        ('Last name', FieldType.text),
      ]);
      expect(PrefillMatcher.matchForm(f)[0], PrefillSlot.fullName);
    });

    test('only text fields, and date fields asking for the birth date', () {
      final f = form([
        ('Name', FieldType.signature),
        ('Date of birth', FieldType.date),
        ('Name', FieldType.checkbox),
        ('Age', FieldType.date),
      ]);
      expect(PrefillMatcher.matchForm(f), {1: PrefillSlot.dateOfBirth});
    });

    test('Address: whole address unless the form has city / ZIP boxes', () {
      final alone = form([('Address', FieldType.text)]);
      final slots = PrefillMatcher.matchForm(alone);
      expect(
        PrefillMatcher.valueForField(alone, slots, 0, priya),
        '12 Elm Street, Apt 4, Austin, TX 78701, USA',
      );

      final w4 = form([
        ('Address', FieldType.text),
        ('City or town, state, and ZIP code', FieldType.text),
      ]);
      final s2 = PrefillMatcher.matchForm(w4);
      expect(
        PrefillMatcher.valueForField(w4, s2, 0, priya),
        '12 Elm Street, Apt 4',
      );
      expect(PrefillMatcher.valueForField(w4, s2, 1, priya), 'Austin, TX 78701');

      final withApt = form([
        ('Street address', FieldType.text),
        ('Apt', FieldType.text),
        ('City', FieldType.text),
      ]);
      final s3 = PrefillMatcher.matchForm(withApt);
      expect(
        PrefillMatcher.valueForField(withApt, s3, 0, priya),
        '12 Elm Street',
      );
      expect(PrefillMatcher.valueForField(withApt, s3, 1, priya), 'Apt 4');
    });
  });

  group('values', () {
    test('names are built from the parts', () {
      expect(priya.valueFor(PrefillSlot.fullName), 'Priya kumari Raman');
      expect(priya.valueFor(PrefillSlot.firstAndMiddleInitial), 'Priya K');
      expect(priya.valueFor(PrefillSlot.middleInitial), 'K');
    });

    test('missing details give no value', () {
      const empty = MyDetails();
      expect(empty.isEmpty, isTrue);
      expect(priya.isEmpty, isFalse);
      expect(empty.valueFor(PrefillSlot.fullName), isNull);
      expect(empty.valueFor(PrefillSlot.cityStateZip), isNull);
      expect(priya.valueFor(PrefillSlot.dateOfBirth), isNull);
      expect(
        const MyDetails(city: 'Austin').valueFor(PrefillSlot.cityStateZip),
        'Austin',
      );
    });

    test('date of birth in the form\'s style, and age from it', () {
      final d = MyDetails(dateOfBirth: DateTime(1990, 6, 15));
      expect(
        d.valueFor(PrefillSlot.dateOfBirth, dateFormat: DateFormat('dd/MM/yyyy')),
        '15/06/1990',
      );
      expect(
        d.valueFor(PrefillSlot.age, today: DateTime(2026, 6, 14)),
        '35',
      );
      expect(
        d.valueFor(PrefillSlot.age, today: DateTime(2026, 6, 15)),
        '36',
      );
    });
  });
}
