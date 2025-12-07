import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'statistics_screen.dart';
import '../utils/app_theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  bool _isSettingPin = false;
  String _errorMessage = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
    _checkPinExists();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _checkPinExists() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = prefs.getString('statistics_pin') != null;

      setState(() {
        _isSettingPin = !hasPin;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء التحقق من كلمة المرور';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final enteredPin = _controllers.map((c) => c.text).join();

    if (enteredPin.length != 4) {
      setState(() => _errorMessage = 'يرجى إدخال 4 أرقام');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isSettingPin) {
        // حفظ كلمة المرور الجديدة
        await prefs.setString('statistics_pin', enteredPin);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StatisticsScreen()),
          );
        }
      } else {
        // التحقق من كلمة المرور
        final savedPin = prefs.getString('statistics_pin');

        if (enteredPin == savedPin) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const StatisticsScreen()),
            );
          }
        } else {
          setState(() => _errorMessage = 'كلمة المرور غير صحيحة');
          _clearPin();
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
              AppColors.background,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Animated Icon
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isSettingPin ? Icons.lock_open_rounded : Icons.lock_rounded,
                                size: 60,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Title
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            _isSettingPin ? 'إنشاء كلمة المرور' : 'أدخل كلمة المرور',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicDisplayMedium.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Subtitle
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            _isSettingPin
                                ? 'أنشئ كلمة مرور مكونة من 4 أرقام\nللوصول إلى الإحصائيات'
                                : 'أدخل كلمة المرور للوصول إلى الإحصائيات',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicBody.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 50),
                        
                        // PIN Input Card
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // PIN Input Fields
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      4,
                                      (index) => Container(
                                        width: 60,
                                        height: 70,
                                        margin: const EdgeInsets.symmetric(horizontal: 6),
                                        child: TextField(
                                          controller: _controllers[index],
                                          focusNode: _focusNodes[index],
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          maxLength: 1,
                                          obscureText: true,
                                          obscuringCharacter: '●',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            counterText: '',
                                            filled: true,
                                            fillColor: AppColors.surfaceVariant,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: _errorMessage.isNotEmpty
                                                    ? AppColors.error
                                                    : AppColors.border,
                                                width: 2,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: AppColors.primary,
                                                width: 3,
                                              ),
                                            ),
                                            errorBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(
                                                color: AppColors.error,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          onChanged: (value) {
                                            if (value.isNotEmpty) {
                                              if (index < 3) {
                                                _focusNodes[index + 1].requestFocus();
                                              } else {
                                                _focusNodes[index].unfocus();
                                                _verifyPin();
                                              }
                                            } else if (index > 0) {
                                              _focusNodes[index - 1].requestFocus();
                                            }

                                            if (_errorMessage.isNotEmpty) {
                                              setState(() => _errorMessage = '');
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Error Message
                                  if (_errorMessage.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.error.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: AppTextStyles.arabicBody.copyWith(
                                                color: AppColors.error,
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Confirm Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _verifyPin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: AppColors.primary.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isSettingPin
                                                ? Icons.check_circle_rounded
                                                : Icons.arrow_forward_rounded,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isSettingPin ? 'إنشاء كلمة المرور' : 'تأكيد',
                                            style: AppTextStyles.arabicBody.copyWith(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Forgot Password
                                  if (!_isSettingPin) ...[
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            title: Row(
                                              children: [
                                                Icon(Icons.warning_rounded, color: AppColors.warning),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'إعادة تعيين كلمة المرور',
                                                    textAlign: TextAlign.right,
                                                    style: AppTextStyles.arabicTitle,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              'هل أنت متأكد من إعادة تعيين كلمة المرور؟',
                                              textAlign: TextAlign.right,
                                              style: AppTextStyles.arabicBody,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(
                                                  'إلغاء',
                                                  style: AppTextStyles.arabicBody,
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.remove('statistics_pin');
                                                  if (mounted) {
                                                    Navigator.pop(context);
                                                    setState(() => _isSettingPin = true);
                                                    _clearPin();
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.error,
                                                ),
                                                child: Text(
                                                  'تأكيد',
                                                  style: AppTextStyles.arabicBody.copyWith(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'نسيت كلمة المرور؟',
                                        style: AppTextStyles.arabicBody.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Security Note
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'كلمة المرور محمية ومشفرة لحماية بياناتك',
                                    style: AppTextStyles.arabicBodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}