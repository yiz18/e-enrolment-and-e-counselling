/// Subject name dictionaries for each qualification level.
///
/// Each list is a flat collection of canonical subject name strings.
/// Pass the appropriate list to [SubjectCorrector] — the matching algorithm
/// is entirely independent of the content of these lists, so adding new
/// qualification levels here requires no changes to the corrector.
///
/// Naming convention for constants: k<Level>Subjects.

// ── SPM ──────────────────────────────────────────────────────────────────────

/// Sijil Pelajaran Malaysia (SPM) — Malaysian O-Level equivalent.
///
/// Covers core, elective, and optional subjects offered under the
/// Kementerian Pendidikan Malaysia (KPM) SPM examination.
/// Both the official Malay names (as printed on certificates) and common
/// English names are included so that [SubjectCorrector] recognises OCR
/// output from either language context without requiring a translation layer.
const List<String> kSpmSubjects = [
  // ── Core (Malay names as printed on SPM certificates) ────────────────────
  'Bahasa Melayu',
  'Bahasa Inggeris',        // English language — Malay label on certificate
  'Sejarah',                // History
  'Pendidikan Islam',       // Islamic Studies
  'Pendidikan Moral',       // Moral Education

  // ── Science stream (Malay certificate labels) ─────────────────────────────
  'Matematik',              // Mathematics
  'Matematik Tambahan',     // Additional Mathematics
  'Fizik',                  // Physics
  'Kimia',                  // Chemistry
  'Biologi',                // Biology
  'Sains',                  // Science

  // ── Science stream (English labels — also appear on some certificates) ────
  'Mathematics',
  'Additional Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'Science',

  // ── Technical / vocational ────────────────────────────────────────────────
  'Sains Komputer',         // Computer Science
  'Teknologi Maklumat dan Komunikasi',
  'Computer Science',
  'Information and Communication Technology',
  'Design and Technology',
  'Reka Bentuk dan Teknologi',

  // ── Commerce stream ───────────────────────────────────────────────────────
  'Ekonomi',                // Economics
  'Perakaunan',             // Accounts
  'Perdagangan',            // Business Studies / Commerce
  'Prinsip Perakaunan',
  'Economics',
  'Accounts',
  'Business Studies',

  // ── Humanities ────────────────────────────────────────────────────────────
  'Geografi',               // Geography
  'Geography',
  'Sastera Melayu',
  'Kesusasteraan Melayu',
  'Literature in English',

  // ── English / Malay equivalents kept for cross-context matching ───────────
  'English',
  'History',
  'Islamic Studies',
  'Moral Education',

  // ── Arts ──────────────────────────────────────────────────────────────────
  'Pendidikan Seni Visual', // Visual Art
  'Visual Art',
  'Muzik',                  // Music
  'Music',

  // ── Languages ─────────────────────────────────────────────────────────────
  'Bahasa Cina',
  'Bahasa Tamil',
  'Bahasa Arab',
  'Arabic',
  'French',
  'German',
  'Japanese',

  // ── Physical ──────────────────────────────────────────────────────────────
  'Pendidikan Jasmani',
  'Physical Education',
];

// ── STPM ─────────────────────────────────────────────────────────────────────

/// Sijil Tinggi Pelajaran Malaysia (STPM) — Malaysian A-Level equivalent.
///
/// Reserved for Phase 3+ when multi-level qualification support is added.
const List<String> kStpmSubjects = [
  'General Studies',
  'Mathematics T',
  'Mathematics S',
  'Further Mathematics T',
  'Physics',
  'Chemistry',
  'Biology',
  'Computer Science',
  'Economics',
  'Accounting',
  'Business Studies',
  'Geography',
  'History',
  'English',
  'Bahasa Melayu',
  'Pengajian Am',
];

// ── Foundation ───────────────────────────────────────────────────────────────

/// Foundation programme subjects.
///
/// Placeholder — populate when Foundation result parsing is required.
const List<String> kFoundationSubjects = [
  'English for Academic Purposes',
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'Computer Fundamentals',
  'Introduction to Economics',
  'Calculus',
  'Statistics',
  'Critical Thinking',
];

// ── Diploma ───────────────────────────────────────────────────────────────────

/// Diploma programme subjects.
///
/// Placeholder — populate with institution-specific subjects when required.
const List<String> kDiplomaSubjects = [
  'English Communication',
  'Mathematics',
  'Engineering Mathematics',
  'Computer Programming',
  'Data Structures',
  'Database Management',
  'Networking Fundamentals',
  'Accounting Principles',
  'Business Communication',
  'Project Management',
];
