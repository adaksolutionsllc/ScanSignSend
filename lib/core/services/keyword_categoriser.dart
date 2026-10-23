import '../models/document_category.dart';

/// Sorts a document into a built-in category from the words in its title and
/// text. Used on every phone without an on-device language model, and as the
/// fallback when the model can't answer.
///
/// It only answers when one category clearly wins; otherwise null
/// (Uncategorised). A wrong category is worse than none.
class KeywordCategoriser {
  const KeywordCategoriser._();

  /// Phrases that on their own nearly decide the category.
  static const _strong = 3;

  /// Phrases that hint but also appear elsewhere ("bank", "location").
  static const _weak = 1;

  /// The winner needs at least this score…
  static const minScore = 4;

  /// …and this much more than the runner-up.
  static const minLead = 1.5;

  /// Title words count this many times more than body text.
  static const _titleBoost = 2;

  /// Per category: (phrase, weight). Phrases cover the Latin-script locales
  /// the app ships (en, fr, es, pt) plus Indian English terms. They are
  /// normalised like the text (lowercase, no accents, punctuation → space),
  /// so "W-9" matches "w 9" and "impôt" matches "impot".
  static const Map<BuiltInCategory, List<(String, int)>> _phrases = {
    BuiltInCategory.tax: [
      ('w-9', _strong),
      ('w-4', _strong),
      ('w-2', _strong),
      ('1099', _strong),
      ('1040', _strong),
      ('form 16', _strong),
      ('26as', _strong),
      ('income tax', _strong),
      ('tax return', _strong),
      ('taxpayer', _strong),
      ('internal revenue', _strong),
      ('withholding', _strong),
      ('self assessment', _strong),
      ('hmrc', _strong),
      ('gstin', _weak),
      ('tax', _weak),
      ('taxes', _weak),
      ('irs', _weak),
      ('deduction', _weak),
      ('refund', _weak),
      ('impot', _strong),
      ('impots', _strong),
      ('declaration de revenus', _strong),
      ('avis d imposition', _strong),
      ('impuesto', _strong),
      ('impuestos', _strong),
      ('declaracion de la renta', _strong),
      ('agencia tributaria', _strong),
      ('hacienda', _weak),
      ('imposto de renda', _strong),
      ('receita federal', _strong),
      ('fiscal', _weak),
      ('tributaria', _weak),
    ],
    BuiltInCategory.money: [
      ('bank statement', _strong),
      ('account statement', _strong),
      ('ifsc', _strong),
      ('iban', _strong),
      ('swift code', _strong),
      ('direct deposit', _strong),
      ('loan application', _strong),
      ('credit card', _strong),
      ('kyc', _strong),
      ('wire transfer', _strong),
      ('mutual fund', _strong),
      ('demat', _strong),
      ('standing order', _strong),
      ('bank', _weak),
      ('account number', _weak),
      ('balance', _weak),
      ('deposit', _weak),
      ('withdrawal', _weak),
      ('loan', _weak),
      ('savings', _weak),
      ('interest rate', _weak),
      ('cheque', _weak),
      ('releve bancaire', _strong),
      ('releve d identite bancaire', _strong),
      ('virement', _strong),
      ('banque', _weak),
      ('pret', _weak),
      ('extracto bancario', _strong),
      ('cuenta bancaria', _strong),
      ('transferencia bancaria', _strong),
      ('banco', _weak),
      ('prestamo', _weak),
      ('extrato bancario', _strong),
      ('conta bancaria', _strong),
      ('emprestimo', _weak),
    ],
    BuiltInCategory.insurance: [
      ('insurance', _strong),
      ('insured', _strong),
      ('policyholder', _strong),
      ('policy number', _strong),
      ('claim form', _strong),
      ('sum assured', _strong),
      ('deductible', _weak),
      ('premium', _weak),
      ('beneficiary', _weak),
      ('coverage', _weak),
      ('nominee', _weak),
      ('assurance', _strong),
      ('assure', _weak),
      ('sinistre', _strong),
      ('mutuelle', _strong),
      ('poliza', _strong),
      ('asegurado', _strong),
      ('aseguradora', _strong),
      ('siniestro', _strong),
      ('seguro', _weak),
      ('apolice', _strong),
      ('segurado', _strong),
      ('seguradora', _strong),
      ('sinistro', _strong),
    ],
    BuiltInCategory.medical: [
      ('patient', _strong),
      ('medical history', _strong),
      ('diagnosis', _strong),
      ('prescription', _strong),
      ('physician', _strong),
      ('allergies', _strong),
      ('medications', _strong),
      ('immunization', _strong),
      ('vaccination', _strong),
      ('hipaa', _strong),
      ('consent to treatment', _strong),
      ('blood group', _strong),
      ('hospital', _weak),
      ('clinic', _weak),
      ('doctor', _weak),
      ('health', _weak),
      ('symptoms', _weak),
      ('medecin', _strong),
      ('ordonnance', _strong),
      ('antecedents medicaux', _strong),
      ('hopital', _weak),
      ('paciente', _strong),
      ('historial medico', _strong),
      ('receta medica', _strong),
      ('alergias', _strong),
      ('medico', _weak),
      ('historico medico', _strong),
      ('receita medica', _strong),
    ],
    BuiltInCategory.home: [
      ('rental application', _strong),
      ('lease', _strong),
      ('tenant', _strong),
      ('landlord', _strong),
      ('lessee', _strong),
      ('lessor', _strong),
      ('security deposit', _strong),
      ('monthly rent', _strong),
      ('move in', _weak),
      ('rent', _weak),
      ('rental', _weak),
      ('property', _weak),
      ('mortgage', _weak),
      ('locataire', _strong),
      ('bailleur', _strong),
      ('loyer', _strong),
      ('demande de location', _strong),
      ('bail', _weak),
      ('logement', _weak),
      ('location', _weak),
      ('alquiler', _strong),
      ('arrendamiento', _strong),
      ('inquilino', _strong),
      ('arrendador', _strong),
      ('arrendatario', _strong),
      ('fianza', _weak),
      ('vivienda', _weak),
      ('locacao', _strong),
      ('aluguel', _strong),
      ('aluguer', _strong),
      ('locatario', _strong),
      ('locador', _strong),
      ('senhorio', _strong),
      ('fiador', _weak),
      ('imovel', _weak),
    ],
    BuiltInCategory.work: [
      ('employment application', _strong),
      ('job application', _strong),
      ('offer letter', _strong),
      ('appointment letter', _strong),
      ('payslip', _strong),
      ('pay slip', _strong),
      ('salary slip', _strong),
      ('timesheet', _strong),
      ('employment eligibility', _strong),
      ('i-9', _strong),
      ('curriculum vitae', _strong),
      ('employer', _weak),
      ('employee', _weak),
      ('salary', _weak),
      ('position applied', _strong),
      ('resume', _weak),
      ('employeur', _strong),
      ('contrat de travail', _strong),
      ('fiche de paie', _strong),
      ('bulletin de salaire', _strong),
      ('salarie', _weak),
      ('empleador', _strong),
      ('contrato de trabajo', _strong),
      ('solicitud de empleo', _strong),
      ('nomina', _strong),
      ('empleado', _weak),
      ('empregador', _strong),
      ('contrato de trabalho', _strong),
      ('holerite', _strong),
      ('recibo de vencimento', _strong),
      ('empregado', _weak),
    ],
    BuiltInCategory.school: [
      ('student', _strong),
      ('enrollment', _strong),
      ('enrolment', _strong),
      ('admission form', _strong),
      ('permission slip', _strong),
      ('field trip', _strong),
      ('transcript', _strong),
      ('tuition', _strong),
      ('parent guardian', _strong),
      ('school', _weak),
      ('university', _weak),
      ('college', _weak),
      ('grade', _weak),
      ('teacher', _weak),
      ('eleve', _strong),
      ('etudiant', _strong),
      ('inscription scolaire', _strong),
      ('ecole', _weak),
      ('universite', _weak),
      ('estudiante', _strong),
      ('alumno', _strong),
      ('escuela', _weak),
      ('universidad', _weak),
      ('aluno', _strong),
      ('estudante', _strong),
      ('escola', _weak),
      ('universidade', _weak),
    ],
    BuiltInCategory.idTravel: [
      ('passport', _strong),
      ('visa application', _strong),
      ('driver s license', _strong),
      ('driving licence', _strong),
      ('aadhaar', _strong),
      ('voter id', _strong),
      ('identity card', _strong),
      ('national id', _strong),
      ('boarding pass', _strong),
      ('immigration', _strong),
      ('ds-160', _strong),
      ('itinerary', _weak),
      ('visa', _weak),
      ('nationality', _weak),
      ('passeport', _strong),
      ('carte d identite', _strong),
      ('permis de conduire', _strong),
      ('titre de sejour', _strong),
      ('pasaporte', _strong),
      ('licencia de conducir', _strong),
      ('permiso de conducir', _strong),
      ('visado', _strong),
      ('passaporte', _strong),
      ('carteira de identidade', _strong),
      ('carta de conducao', _strong),
      ('visto', _weak),
    ],
    BuiltInCategory.legal: [
      ('power of attorney', _strong),
      ('affidavit', _strong),
      ('notary', _strong),
      ('notarized', _strong),
      ('non disclosure', _strong),
      ('plaintiff', _strong),
      ('defendant', _strong),
      ('last will', _strong),
      ('indemnify', _strong),
      ('agreement', _weak),
      ('contract', _weak),
      ('hereby', _weak),
      ('witness', _weak),
      ('court', _weak),
      ('parties', _weak),
      ('procuration', _strong),
      ('attestation sur l honneur', _strong),
      ('notaire', _strong),
      ('contrat', _weak),
      ('tribunal', _weak),
      ('poder notarial', _strong),
      ('declaracion jurada', _strong),
      ('notario', _strong),
      ('contrato', _weak),
      ('procuracao', _strong),
      ('cartorio', _strong),
      ('acordo', _weak),
    ],
    BuiltInCategory.bills: [
      ('invoice', _strong),
      ('receipt', _strong),
      ('amount due', _strong),
      ('total due', _strong),
      ('payment due', _strong),
      ('electricity bill', _strong),
      ('utility bill', _strong),
      ('subtotal', _strong),
      ('bill', _weak),
      ('due date', _weak),
      ('total', _weak),
      ('facture', _strong),
      ('recu', _weak),
      ('montant du', _strong),
      ('factura', _strong),
      ('recibo', _weak),
      ('importe total', _strong),
      ('fatura', _strong),
      ('nota fiscal', _strong),
      ('boleto', _strong),
    ],
  };

  static final Map<BuiltInCategory, List<(String, int)>> _normalised = {
    for (final e in _phrases.entries)
      e.key: [for (final (p, w) in e.value) (normalise(p), w)],
  };

  /// The category [title] and [text] clearly belong to, or null.
  static BuiltInCategory? classify(String title, String text) {
    final all = scores(title, text);
    if (all.isEmpty) return null;
    final ranked = all.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0;
    if (best.value < minScore) return null;
    if (second > 0 && best.value < second * minLead) return null;
    return best.key;
  }

  /// Every category's score; exposed for tests and tuning.
  static Map<BuiltInCategory, int> scores(String title, String text) {
    final t = ' ${normalise(title)} ';
    final b = ' ${normalise(text)} ';
    final out = <BuiltInCategory, int>{};
    for (final e in _normalised.entries) {
      var score = 0;
      for (final (phrase, weight) in e.value) {
        final needle = ' $phrase ';
        if (t.contains(needle)) score += weight * _titleBoost;
        // Presence, capped: a long document repeating "patient" forty times
        // isn't forty times more medical.
        final n = _count(b, needle);
        if (n > 0) score += weight * (n > 2 ? 2 : n);
      }
      if (score > 0) out[e.key] = score;
    }
    return out;
  }

  static int _count(String haystack, String needle) {
    var n = 0;
    var i = haystack.indexOf(needle);
    while (i >= 0) {
      n++;
      if (n > 2) break;
      i = haystack.indexOf(needle, i + needle.length - 1);
    }
    return n;
  }

  /// Lowercase, accents removed, anything but letters and digits → space.
  static String normalise(String s) {
    final lower = s.toLowerCase();
    final out = StringBuffer();
    for (final r in lower.runes) {
      final c = String.fromCharCode(r);
      final plain = _accents[c] ?? c;
      final u = plain.codeUnitAt(0);
      final keep = (u >= 0x61 && u <= 0x7a) || (u >= 0x30 && u <= 0x39);
      out.write(keep ? plain : ' ');
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _accents = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
  };
}
