import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/auth/presentation/bloc/authentication_bloc.dart';
import 'package:newwone/features/auth/presentation/bloc/login_form_cubit.dart';

/// Enterprise login screen for both Employee and Admin roles.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginFormCubit(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    context.read<AuthenticationBloc>().add(
          AuthLoginRequested(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  void _fillCredentials(String identifier, String password) {
    _identifierController.text = identifier;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildLoginCard(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDemoCredentialsCard(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.navyHeaderGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: AppSpacing.cardShadow,
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            size: 30,
            color: AppColors.accentEmerald,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Welcome to ${AppConstants.appName}',
          style: AppTypography.displayLarge.copyWith(fontSize: 25),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Sign in with your Employee ID or corporate email to record QR attendance or manage sessions.',
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, authState) {
          final isLoading =
              authState is AuthUnauthenticated && authState.isLoading;
          final errorMessage = authState is AuthUnauthenticated
              ? authState.errorMessage
              : null;

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.errorDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  controller: _identifierController,
                  label: 'Employee ID or Email',
                  hintText: 'e.g. EMP001 or rahul@gmail.com',
                  prefixIcon: Icons.badge_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your Employee ID or Email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                BlocBuilder<LoginFormCubit, LoginFormState>(
                  builder: (context, formState) {
                    return AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: formState.obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onFieldSubmitted: (_) => _submitLogin(),
                      suffixIcon: IconButton(
                        tooltip: formState.obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          formState.obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => context
                            .read<LoginFormCubit>()
                            .togglePasswordVisibility(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Sign In',
                  icon: Icons.login_rounded,
                  isLoading: isLoading,
                  onPressed: _submitLogin,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDemoCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryBlueSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.secondaryBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 18,
                color: AppColors.secondaryBlue,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  ApiConfig.isMockServerConfigured
                      ? 'Demo Accounts (Mock Server Connected)'
                      : 'Demo Testing Accounts (Local Mode)',
                  style: AppTypography.labelLarge.copyWith(
                    fontSize: 13,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap an account below to autofill credentials for testing:',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _DemoAccountChip(
                label: 'Rahul (EMP001)',
                role: 'Employee',
                onTap: () => _fillCredentials('rahul@gmail.com', '123456'),
              ),
              _DemoAccountChip(
                label: 'Anjali (EMP002)',
                role: 'Employee',
                onTap: () => _fillCredentials('anjali@gmail.com', '123456'),
              ),
              _DemoAccountChip(
                label: 'Admin (ADM001)',
                role: 'Admin',
                onTap: () => _fillCredentials('admin@gmail.com', 'admin123'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoAccountChip extends StatelessWidget {
  const _DemoAccountChip({
    required this.label,
    required this.role,
    required this.onTap,
  });

  final String label;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: role == 'Admin'
                      ? AppColors.primaryNavy
                      : AppColors.accentEmeraldSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 9.5,
                    color: role == 'Admin'
                        ? AppColors.textOnDark
                        : AppColors.accentEmeraldDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
