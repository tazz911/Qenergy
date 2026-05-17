// lib/core/utils/validators.dart

class FormValidators {

  // ── Full Name ──────────────────────────────────────
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Full name cannot be just numbers';
    }
    return null;
  }

  // ── Email ──────────────────────────────────────────
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  // ── Password ───────────────────────────────────────
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  // ── Contact Number ─────────────────────────────────
  static String? validateContactNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your contact number';
    }
    if (!RegExp(r'^[0-9]{8,9}$').hasMatch(value)) {
      return 'Contact number must be 8 or 9 digits';
    }
    return null;
  }

  // ── Service Request ────────────────────────────────
  static String? validateServiceRequest(
    bool normalService,
    bool majorService,
    bool repair,
    bool others,
  ) {
    if (!normalService && !majorService && !repair && !others) {
      return 'Please select at least one service';
    }
    return null;
  }
}