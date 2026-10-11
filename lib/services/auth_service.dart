import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ข้อผิดพลาดสำหรับแสดงข้อความที่ผู้ใช้เข้าใจได้
class AuthServiceException implements Exception {
  final String message;

  AuthServiceException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// สมัครสมาชิกด้วย Email และ Password
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getThaiMessage(e.code));
    } catch (_) {
      throw AuthServiceException('สมัครสมาชิกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  /// เข้าสู่ระบบด้วย Email และ Password
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getThaiMessage(e.code));
    } catch (_) {
      throw AuthServiceException('เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  /// ออกจากระบบ
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getThaiMessage(e.code));
    } catch (_) {
      throw AuthServiceException('ออกจากระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleReady = false;

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;

    await _googleSignIn.initialize(
      serverClientId:
          '130730642123-6g48e25o6ar04o7fttu8r2dlv6ak8get.apps.googleusercontent.com',
    );
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleReady();

      // เปิดหน้าต่างเลือกบัญชี Google
      final googleUser = await _googleSignIn.authenticate();

      // รับ ID Token จากบัญชี Google
      final idToken = googleUser.authentication.idToken;

      // ขอ Access Token สำหรับ scope email
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);

      // สร้าง Firebase Credential
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );

      // เข้าสู่ระบบ Firebase ด้วยบัญชี Google
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getThaiMessage(e.code));
    }
  }

  /// แปลง FirebaseAuthException code เป็นข้อความภาษาไทย
  String _getThaiMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'อีเมลนี้มีบัญชีผู้ใช้อยู่แล้ว';

      case 'weak-password':
        return 'รหัสผ่านไม่ปลอดภัย กรุณาตั้งรหัสผ่านให้รัดกุมขึ้น';

      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';

      case 'user-not-found':
        return 'ไม่พบบัญชีผู้ใช้นี้ กรุณาตรวจสอบอีเมล';

      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง กรุณาลองอีกครั้ง';

      case 'invalid-credential':
        return 'ข้อมูลยืนยันตัวตนไม่ถูกต้องหรือหมดอายุ กรุณาลองเข้าสู่ระบบใหม่';

      case 'user-disabled':
        return 'บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ';

      case 'too-many-requests':
        return 'คุณลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';

      case 'network-request-failed':
        return 'เชื่อมต่อเครือข่ายไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต';

      case 'operation-not-allowed':
        return 'วิธีเข้าสู่ระบบนี้ยังไม่ได้เปิดใช้งาน';

      case 'email-change-needs-verification':
        return 'กรุณายืนยันอีเมลก่อนดำเนินการต่อ';

      default:
        return 'เกิดข้อผิดพลาดในการยืนยันตัวตน กรุณาลองใหม่อีกครั้ง';
    }
  }
}
