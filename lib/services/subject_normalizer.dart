// =============================================================================
// Canonical subject model
// =============================================================================

/// Canonical subject names used as the single source of truth throughout the
/// application.
///
/// After [SubjectCorrector] resolves OCR character-level noise (e.g.
/// `"BIOLLOGY"` → `"Biologi"`), [SubjectNormalizer.normalize] maps Malay-
/// labelled names — as printed on Malaysian SPM certificates — to their
/// English canonical equivalents.  These English names are what is stored in
/// Firestore [AcademicResultEntry] records and what course-condition entries in
/// [Course.admissionPathways] must use.
///
/// Two-stage OCR pipeline:
///   1. **[SubjectCorrector]**  — fixes OCR typos and garbled characters
///      (character-level noise), e.g. `"BIOLLOGY"` → `"Biologi"`.
///   2. **[SubjectNormalizer]** — resolves language / alias differences,
///      mapping Malay certificate labels to English canonical names,
///      e.g. `"Biologi"` → `"Biology"`.
enum CanonicalSubject {
  bahasaMelayu,
  english,
  mathematics,
  additionalMathematics,
  science,
  physics,
  chemistry,
  biology,
  history,
  economics,
  chinese,
  moralEducation,
  islamicStudies,
  computerScience,
  informationAndCommunicationTechnology,
  geography,
  accounts,
  businessStudies,
  visualArt,
  music,
  bahasaTamil,
  bahasaArab,
  arabic,
  french,
  german,
  japanese,
  physicalEducation,
  literatureInEnglish;

  /// The canonical display name stored in Firestore and matched by
  /// [RecommendationEngine] during subject lookup.
  String get displayName {
    switch (this) {
      case CanonicalSubject.bahasaMelayu:
        return 'Bahasa Melayu';
      case CanonicalSubject.english:
        return 'English';
      case CanonicalSubject.mathematics:
        return 'Mathematics';
      case CanonicalSubject.additionalMathematics:
        return 'Additional Mathematics';
      case CanonicalSubject.science:
        return 'Science';
      case CanonicalSubject.physics:
        return 'Physics';
      case CanonicalSubject.chemistry:
        return 'Chemistry';
      case CanonicalSubject.biology:
        return 'Biology';
      case CanonicalSubject.history:
        return 'History';
      case CanonicalSubject.economics:
        return 'Economics';
      case CanonicalSubject.chinese:
        return 'Chinese';
      case CanonicalSubject.moralEducation:
        return 'Moral Education';
      case CanonicalSubject.islamicStudies:
        return 'Islamic Studies';
      case CanonicalSubject.computerScience:
        return 'Computer Science';
      case CanonicalSubject.informationAndCommunicationTechnology:
        return 'Information and Communication Technology';
      case CanonicalSubject.geography:
        return 'Geography';
      case CanonicalSubject.accounts:
        return 'Accounts';
      case CanonicalSubject.businessStudies:
        return 'Business Studies';
      case CanonicalSubject.visualArt:
        return 'Visual Art';
      case CanonicalSubject.music:
        return 'Music';
      case CanonicalSubject.bahasaTamil:
        return 'Bahasa Tamil';
      case CanonicalSubject.bahasaArab:
        return 'Bahasa Arab';
      case CanonicalSubject.arabic:
        return 'Arabic';
      case CanonicalSubject.french:
        return 'French';
      case CanonicalSubject.german:
        return 'German';
      case CanonicalSubject.japanese:
        return 'Japanese';
      case CanonicalSubject.physicalEducation:
        return 'Physical Education';
      case CanonicalSubject.literatureInEnglish:
        return 'Literature in English';
    }
  }
}

// =============================================================================
// SubjectNormalizer
// =============================================================================

/// Stateless utility that maps subject name aliases to their canonical English
/// forms defined by [CanonicalSubject].
///
/// **Responsibility boundary**
///
/// [SubjectCorrector] handles OCR character-level noise — it corrects
/// garbled or misspelt fragments produced by the ML Kit text recogniser
/// (e.g. `"BIOLLOGY"` → `"Biologi"`, `"Additionall Math"` → `"Matematik
/// Tambahan"`).
///
/// [SubjectNormalizer] handles language and alias standardisation — it maps
/// whatever name [SubjectCorrector] resolved (which may be the Malay
/// certificate label) to the single canonical English name used in course
/// conditions stored in Firestore and evaluated by [RecommendationEngine]
/// (e.g. `"Biologi"` → `"Biology"`, `"Bahasa Inggeris"` → `"English"`).
///
/// Lookup is case-insensitive and whitespace-tolerant. Subjects that are not
/// in the alias table are returned unchanged, preserving pass-through
/// behaviour for any subject outside the known catalog.
class SubjectNormalizer {
  SubjectNormalizer._();

  /// Alias → canonical name table.
  ///
  /// Keys are lowercase trimmed aliases (both Malay and English forms).
  /// Values are [CanonicalSubject.displayName] strings.
  static const Map<String, String> _aliases = {
    // ── English Language ──────────────────────────────────────────────────────
    'bahasa inggeris': 'English',   // Malay label on SPM certificate
    'english': 'English',
    'english language': 'English',  // O-Level / UEC label used in conditionGroups

    // ── Mathematics ───────────────────────────────────────────────────────────
    'matematik': 'Mathematics', // Malay certificate label
    'mathematics': 'Mathematics',

    // ── Additional Mathematics ────────────────────────────────────────────────
    'matematik tambahan': 'Additional Mathematics', // Malay certificate label
    'additional mathematics': 'Additional Mathematics',

    // ── Science ───────────────────────────────────────────────────────────────
    'sains': 'Science', // Malay certificate label
    'science': 'Science',

    // ── Physics ───────────────────────────────────────────────────────────────
    'fizik': 'Physics', // Malay certificate label
    'physics': 'Physics',

    // ── Chemistry ─────────────────────────────────────────────────────────────
    'kimia': 'Chemistry', // Malay certificate label
    'chemistry': 'Chemistry',

    // ── Biology ───────────────────────────────────────────────────────────────
    'biologi': 'Biology', // Malay certificate label
    'biology': 'Biology',

    // ── History ───────────────────────────────────────────────────────────────
    'sejarah': 'History', // Malay certificate label
    'history': 'History',

    // ── Economics ─────────────────────────────────────────────────────────────
    'ekonomi': 'Economics', // Malay certificate label
    'economics': 'Economics',

    // ── Chinese ───────────────────────────────────────────────────────────────
    'bahasa cina': 'Chinese', // Malay certificate label
    'chinese': 'Chinese',

    // ── Bahasa Melayu (retains Malay name — official examination subject) ─────
    'bahasa melayu': 'Bahasa Melayu',

    // ── Moral Education ───────────────────────────────────────────────────────
    'pendidikan moral': 'Moral Education', // Malay certificate label
    'moral education': 'Moral Education',

    // ── Islamic Studies ───────────────────────────────────────────────────────
    'pendidikan islam': 'Islamic Studies', // Malay certificate label
    'islamic studies': 'Islamic Studies',

    // ── Computer Science ──────────────────────────────────────────────────────
    'sains komputer': 'Computer Science', // Malay certificate label
    'computer science': 'Computer Science',

    // ── ICT ───────────────────────────────────────────────────────────────────
    'teknologi maklumat dan komunikasi':
        'Information and Communication Technology',
    'information and communication technology':
        'Information and Communication Technology',

    // ── Geography ─────────────────────────────────────────────────────────────
    'geografi': 'Geography', // Malay certificate label
    'geography': 'Geography',

    // ── Accounts ──────────────────────────────────────────────────────────────
    'perakaunan': 'Accounts', // Malay certificate label
    'prinsip perakaunan': 'Accounts', // alternative Malay label
    'accounts': 'Accounts',

    // ── Business Studies ──────────────────────────────────────────────────────
    'perdagangan': 'Business Studies', // Malay certificate label
    'business studies': 'Business Studies',

    // ── Visual Art ────────────────────────────────────────────────────────────
    'pendidikan seni visual': 'Visual Art', // Malay certificate label
    'visual art': 'Visual Art',

    // ── Music ─────────────────────────────────────────────────────────────────
    'muzik': 'Music', // Malay certificate label
    'music': 'Music',

    // ── Physical Education ────────────────────────────────────────────────────
    'pendidikan jasmani': 'Physical Education', // Malay certificate label
    'physical education': 'Physical Education',

    // ── Literature in English ─────────────────────────────────────────────────
    'literature in english': 'Literature in English',

    // ── Other languages (pass-through — no Malay/English alias conflict) ──────
    'bahasa tamil': 'Bahasa Tamil',
    'bahasa arab': 'Bahasa Arab',
    'arabic': 'Arabic',
    'french': 'French',
    'german': 'German',
    'japanese': 'Japanese',
  };

  /// Returns the canonical English subject name for [subject].
  ///
  /// Lookup is case-insensitive and whitespace-trimmed so that `"Bahasa
  /// Inggeris"`, `"BAHASA INGGERIS"`, and `"  bahasa inggeris  "` all resolve
  /// to `"English"`.
  ///
  /// When [subject] is not found in the alias table it is returned unchanged,
  /// preserving pass-through behaviour for subjects outside the known catalog.
  static String normalize(String subject) {
    final key = subject.trim().toLowerCase();
    return _aliases[key] ?? subject;
  }
}
