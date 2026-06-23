import 'package:e_enrolment_and_e_counselling_appication/admin_screens/report_view_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

// Import all customer_screens
import 'customer_screens/login_screen.dart';
import 'customer_screens/register_screen.dart';
import 'customer_screens/dashboard_screen.dart';
import 'customer_screens/appointment_screen.dart';
import 'customer_screens/chatbot_screen.dart';
import 'customer_screens/payment_screen.dart';
import 'customer_screens/scholarship_screen.dart';
import 'customer_screens/upload_document_screen.dart';
import 'customer_screens/interest_profile_screen.dart';
import 'customer_screens/recommendation_screen.dart';
import 'customer_screens/riasec_questionnaire_screen.dart';
import 'student_screens/offer_letter_screen.dart';
import 'customer_screens/user_profile_screen.dart';
import 'customer_screens/role_selection_screen.dart';
import 'admin_screens/admin_dashboard.dart';
import 'admin_screens/admin_web_layout.dart';
import 'admin_screens/application_management_screen.dart';
import 'admin_screens/manage_payments_screen.dart';
import 'admin_screens/manage_offer_letters_screen.dart';
import 'admin_screens/manage_scholarships_screen.dart';
import 'admin_screens/reports_screen.dart';
import 'admin_screens/course_management_screen.dart';
import 'admin_screens/admin_profile_screen.dart';
import 'admin_screens/add_staff_screen.dart';
import 'admin_screens/staff_management_screen.dart';
import 'models/user_role.dart';
import 'counsellor_screens/counsellor_dashboard.dart';
import 'counsellor_screens/counsellor_web_layout.dart';
import 'counsellor_screens/appointment_detail_screen.dart';
import 'counsellor_screens/counsellor_profile_screen.dart';
import 'counsellor_screens/manage_appointments_screen.dart';
import 'counsellor_screens/counselling_history_detail_screen.dart';
import 'counsellor_screens/counsellor_student_detail_screen.dart';
import 'counsellor_screens/student_records_screen.dart';
import 'student_screens/course_detail_screen.dart';
import 'student_screens/document_upload_screen.dart';
import 'student_screens/my_applications_screen.dart';
import 'student_screens/student_web_layout.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-Enrolment System',

      // 🔥 Global Theme
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEAF3FF), // 🔥 浅skyblue（你要的）

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      // Initial screen
      initialRoute: '/role',

      routes: {
        // Auth
        '/role': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const UserProfileScreen(),

        // Main
        '/dashboard': (context) => const StudentWebLayout(
              selectedIndex: 0,
              child: DashboardScreen(),
            ),
        '/myApplications': (context) => const StudentWebLayout(
              selectedIndex: 1,
              child: MyApplicationsScreen(),
            ),
        '/courseDetail': (context) => const CourseDetailScreen(),

        // Core Features
        '/recommendation': (context) => const RecommendationScreen(),
        '/interest-profile': (context) => const InterestProfileScreen(),
        '/riasec-questionnaire': (context) => const RiasecQuestionnaireScreen(),
        '/upload': (context) => const UploadDocumentScreen(),
        '/documents': (context) => const DocumentUploadScreen(),
        '/applicationStatus': (context) => const StudentWebLayout(
              selectedIndex: 1,
              child: MyApplicationsScreen(),
            ),
        '/offerLetter': (context) => const OfferLetterScreen(),

        // Others
        '/appointment': (context) => const AppointmentScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/payment': (context) => const PaymentScreen(),
        '/scholarship': (context) => const ScholarshipScreen(),

        //admin
        '/adminDashboard': (context) => const AdminWebLayout(
              selectedIndex: 0,
              child: AdminDashboardScreen(),
            ),
        '/applicationManagement': (context) => const AdminWebLayout(
              selectedIndex: 1,
              child: ApplicationManagementScreen(),
            ),
        '/managePayments': (context) => const AdminWebLayout(
              selectedIndex: 2,
              child: ManagePaymentsScreen(),
            ),
        '/manageOfferLetters': (context) => const AdminWebLayout(
              selectedIndex: 3,
              child: ManageOfferLettersScreen(),
            ),
        '/manageScholarships': (context) => const AdminWebLayout(
              selectedIndex: 4,
              child: ManageScholarshipsScreen(),
            ),
        '/reports': (context) => const AdminWebLayout(
              selectedIndex: 5,
              child: ReportsScreen(),
            ),
        '/reportView': (context) => const ReportViewScreen(),
        '/courseManagement': (context) => const AdminWebLayout(
              selectedIndex: 6,
              child: CourseManagementScreen(),
            ),
        '/staffManagement': (context) => const AdminWebLayout(
              selectedIndex: 7,
              child: StaffManagementScreen(),
            ),
        '/adminProfile': (context) => const AdminWebLayout(
              selectedIndex: 8,
              child: AdminProfileScreen(),
            ),
        '/addAdmin': (context) => const AddStaffScreen(role: UserRole.admin),
        '/addCounsellor': (context) =>
            const AddStaffScreen(role: UserRole.counsellor),



        //counsellor
        '/counsellorDashboard': (context) => const CounsellorWebLayout(
              selectedIndex: 0,
              child: CounsellorDashboardScreen(),
            ),
        '/manageAppointments': (context) => const CounsellorWebLayout(
              selectedIndex: 1,
              child: ManageAppointmentsScreen(),
            ),
        '/studentRecords': (context) => const CounsellorWebLayout(
              selectedIndex: 2,
              child: StudentRecordsScreen(),
            ),
        '/counsellorProfile': (context) => const CounsellorWebLayout(
              selectedIndex: 3,
              child: CounsellorProfileScreen(),
            ),
        '/appointmentDetail': (context) => const AppointmentDetailScreen(),
        '/counsellorStudentDetail': (context) =>
            const CounsellorStudentDetailScreen(),
        '/counsellingHistoryDetail': (context) =>
            const CounsellingHistoryDetailScreen(),
      },
    );
  }
}