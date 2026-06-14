import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nutrition_repository.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const NutritionApp());
}

class NutritionApp extends StatefulWidget {
  const NutritionApp({super.key});

  @override
  State<NutritionApp> createState() => _NutritionAppState();
}

class _NutritionAppState extends State<NutritionApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nutrition',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101214),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.dark,
          surface: const Color(0xFF101214),
        ),
      ),
      home: AuthGate(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class AppColors {
  static const green = Color(0xFF67C957);
  static const deepGreen = Color(0xFF12B66B);
  static const lime = Color(0xFF84D918);
  static const yellow = Color(0xFFFFC31D);
  static const orange = Color(0xFFFF922E);
  static const violet = Color(0xFF8C79D9);
  static const text = Color(0xFF151517);
  static const muted = Color(0xFF73757C);
  static const line = Color(0xFFE8E9EB);
  static const panel = Color(0xFFF7F8F8);
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _surfaceColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF17191C) : Colors.white;

Color _panelColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF22252A) : AppColors.panel;

Color _lineColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF333840) : AppColors.line;

Color _textColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFFF4F6F8) : AppColors.text;

Color _mutedColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFFA6ABB3) : AppColors.muted;

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _client.auth.currentSession;
    if (session == null) return AuthScreen(repo: NutritionRepository(_client));
    return NutritionShell(
      repo: NutritionRepository(_client),
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.repo, super.key});

  final NutritionRepository repo;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController(text: 'Emma');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignup = true;
  bool _loading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
          children: [
            const Text(
              'Nutrition',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log food in seconds with photo, text, or restaurant lookup.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_isSignup) AppTextField(controller: _name, label: 'Name'),
            if (_isSignup) const SizedBox(height: 12),
            AppTextField(controller: _email, label: 'Email'),
            const SizedBox(height: 12),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _isSignup ? 'Create account' : 'Log in',
              loading: _loading,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: () => setState(() => _isSignup = !_isSignup),
              child: Text(
                _isSignup
                    ? 'I already have an account'
                    : 'Create a new account',
              ),
            ),
            if (_message != null) MessageBox(message: _message!),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = _isSignup
          ? await widget.repo.signUp(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.repo.signIn(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (response.session == null) {
        setState(
          () => _message =
              'Check your email to confirm your account, then log in.',
        );
      }
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class NutritionShell extends StatefulWidget {
  const NutritionShell({
    required this.repo,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final NutritionRepository repo;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<NutritionShell> createState() => _NutritionShellState();
}

class _NutritionShellState extends State<NutritionShell> {
  int _index = 0;
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _history;
  Map<String, dynamic>? _goals;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final goals = await widget.repo.goals();
      final dashboard = await widget.repo.dashboard();
      final history = await widget.repo.history(days: 365);
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _dashboard = dashboard;
        _history = history;
        if (goals['setup_completed'] != true) _index = 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        dashboard: _dashboard,
        loading: _loading,
        error: _error,
        repo: widget.repo,
        onAdd: () => setState(() => _index = 2),
        onAssistant: _openAssistant,
        onRefresh: _load,
      ),
      GoalsScreen(
        goals: _goals,
        dashboard: _dashboard,
        history: _history,
        repo: widget.repo,
        onSaved: _load,
        onRefresh: _load,
      ),
      AddHubScreen(repo: widget.repo, onFoodLogged: _afterLog),
      const FitnessScreen(),
      ProfileScreen(
        repo: widget.repo,
        goals: _goals,
        dashboard: _dashboard,
        history: _history,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onReset: _load,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: AppBottomBar(
        index: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }

  Future<void> _afterLog() async {
    await _load();
    if (mounted) setState(() => _index = 0);
  }

  Future<void> _openAssistant() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiAssistantScreen(
          repo: widget.repo,
          dashboard: _dashboard,
          goals: _goals,
          onRefresh: _load,
        ),
      ),
    );
    await _load();
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.dashboard,
    required this.loading,
    required this.error,
    required this.repo,
    required this.onAdd,
    required this.onAssistant,
    required this.onRefresh,
    super.key,
  });

  final Map<String, dynamic>? dashboard;
  final bool loading;
  final String? error;
  final NutritionRepository repo;
  final VoidCallback onAdd;
  final VoidCallback onAssistant;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && dashboard == null) {
      return ErrorState(error: error!, onRetry: onRefresh);
    }

    final totals = _map(dashboard?['totals']);
    final goals = _map(dashboard?['goals']);
    final calories = _num(totals['calories']);
    final calorieGoal = _num(goals['calories'], fallback: 2200);
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = _userDisplayName(user);
    final greeting = _timeOfDayGreeting(DateTime.now());

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        children: [
          const Text(
            'Home',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Text(
            '$greeting, $displayName 👋',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's your progress for today.",
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Daily Nutrition',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _lineColor(context)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: CalorieRing(
                          value: calories,
                          goal: calorieGoal,
                          goals: goals,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            MacroRow.fromValues(
                              'Protein',
                              totals,
                              goals,
                              'protein',
                              AppColors.green,
                              'g',
                            ),
                            const SizedBox(height: 20),
                            MacroRow.fromValues(
                              'Carbs',
                              totals,
                              goals,
                              'carbs',
                              Colors.blueAccent,
                              'g',
                            ),
                            const SizedBox(height: 20),
                            MacroRow.fromValues(
                              'Fat',
                              totals,
                              goals,
                              'fat',
                              AppColors.orange,
                              'g',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const HomeActivitySummaryCard(),
          const SizedBox(height: 14),
          AiAssistantPromoCard(
            title: 'Coach Chat',
            subtitle:
                'Ask about meals, macros, workouts, recovery, food swaps, and daily coaching.',
            onTap: onAssistant,
          ),
        ],
      ),
    );
  }
}

class TodayAiReviewCard extends StatelessWidget {
  const TodayAiReviewCard({
    required this.mealCount,
    required this.onTap,
    this.title = 'AI meal review',
    this.enabledSubtitle,
    this.disabledSubtitle = 'Log a meal to unlock today’s AI review.',
    super.key,
  });

  final int mealCount;
  final VoidCallback? onTap;
  final String title;
  final String? enabledSubtitle;
  final String disabledSubtitle;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.green.withValues(alpha: _isDark(context) ? .16 : .09)
              : _panelColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? AppColors.green.withValues(alpha: .28)
                : _lineColor(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.green.withValues(alpha: .18)
                    : _surfaceColor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_graph_rounded,
                color: enabled ? AppColors.deepGreen : _mutedColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enabled
                        ? enabledSubtitle ??
                              'Analyze $mealCount logged meals and get practical suggestions.'
                        : disabledSubtitle,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: enabled ? AppColors.deepGreen : _mutedColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeActivitySummaryCard extends StatelessWidget {
  const HomeActivitySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s activity',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'No workout logged yet. Activity-aware nutrition insights are coming soon.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({required this.onAddFood, super.key});

  final VoidCallback onAddFood;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeActionButton(
                icon: Icons.restaurant_rounded,
                label: 'Add Food',
                color: AppColors.orange,
                onTap: onAddFood,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: HomeActionButton(
                icon: Icons.directions_run_rounded,
                label: 'Workout',
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: HomeActionButton(
                icon: Icons.water_drop_rounded,
                label: 'Water',
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: HomeActionButton(
                icon: Icons.monitor_weight_rounded,
                label: 'Weight',
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HomeActionButton extends StatelessWidget {
  const HomeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMealAnalysisScreen extends StatefulWidget {
  const DailyMealAnalysisScreen({
    required this.repo,
    required this.dashboard,
    required this.goals,
    this.reviewDate,
    this.isTodayReview = true,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic> goals;
  final DateTime? reviewDate;
  final bool isTodayReview;

  @override
  State<DailyMealAnalysisScreen> createState() =>
      _DailyMealAnalysisScreenState();
}

class _DailyMealAnalysisScreenState extends State<DailyMealAnalysisScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _analysis;
  Map<String, dynamic>? _swaps;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  Widget build(BuildContext context) {
    final meals = _sortMealsNewestFirst(
      _list(widget.dashboard?['meals']).map(_map),
    );
    final title = widget.isTodayReview ? 'Today’s AI Review' : 'Day AI Review';
    final subtitle = widget.isTodayReview
        ? 'Suggestions based on your logged meals.'
        : 'What could have gone better and what to try next time.';
    final mealContext = widget.isTodayReview
        ? '${meals.length} meals logged today.'
        : '${meals.length} meals logged on ${_formatHistoryDate(widget.reviewDate ?? DateTime.now())}.';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$mealContext AI compares calories, macros, fiber, sugar, sodium, and available micronutrients against your goals.',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const AnalyzingMealIndicator(
                icon: Icons.auto_graph_rounded,
                title: 'Reviewing meals',
                subtitle: 'Finding gaps, wins, and simple swaps',
              ),
            ],
            if (_error != null) MessageBox(message: _error!),
            if (_analysis != null) ...[
              const SizedBox(height: 14),
              AiResultCard(
                title: _stringValue(_analysis!['summary'], 'Daily analysis'),
                children: [
                  for (final item in _list(_analysis!['highlights']))
                    BulletText('$item'),
                  for (final item in _list(_analysis!['gaps']))
                    BulletText('$item'),
                  for (final suggestion in _list(_analysis!['suggestions']))
                    SuggestionTile(data: _map(suggestion)),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Refresh analysis',
                    loading: _loading,
                    onPressed: _loading ? null : _analyze,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Meal swaps',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a logged meal to get healthier, higher-protein, lower-calorie, higher-fiber, and similar-taste options.',
              style: TextStyle(color: _mutedColor(context), fontSize: 13),
            ),
            const SizedBox(height: 10),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < meals.length; i++) ...[
                    MealTile(
                      meal: meals[i],
                      onTap: () => _suggestSwaps(meals[i]),
                    ),
                    if (i != meals.length - 1)
                      const Divider(
                        height: 1,
                        indent: 70,
                        color: AppColors.line,
                      ),
                  ],
                ],
              ),
            ),
            if (_swaps != null) ...[
              const SizedBox(height: 14),
              AiResultCard(
                title: 'Swaps for ${_swaps!['food'] ?? 'this meal'}',
                children: [
                  for (final swap in _list(_swaps!['swaps']))
                    SwapTile(data: _map(swap)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.repo.askAssistant(
        action: 'daily_analysis',
        message: widget.isTodayReview
            ? 'Analyze today’s logged intake and suggest what to do next.'
            : 'Analyze this past logged day. Explain what could have been done better that day and give practical suggestions for a similar future day. Do not call it today.',
        dashboard: _dashboardWithSortedMeals(widget.dashboard),
        goals: widget.goals,
      );
      if (mounted) setState(() => _analysis = response);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _suggestSwaps(Map<String, dynamic> meal) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.repo.askAssistant(
        action: 'food_swap',
        food: meal,
        dashboard: _dashboardWithSortedMeals(widget.dashboard),
        goals: widget.goals,
      );
      if (mounted) setState(() => _swaps = response);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class AddHubScreen extends StatelessWidget {
  const AddHubScreen({
    required this.repo,
    required this.onFoodLogged,
    super.key,
  });

  final NutritionRepository repo;
  final Future<void> Function() onFoodLogged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      children: [
        const Text(
          'Add',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Quickly log nutrition, activity, and progress.',
          style: TextStyle(color: _mutedColor(context), fontSize: 13),
        ),
        const SizedBox(height: 18),
        QuickActionCard(
          icon: Icons.restaurant_rounded,
          title: 'Add food',
          subtitle: 'Type a meal, scan a photo, or log restaurant food.',
          enabled: true,
          onTap: () => _openAddFood(context),
        ),
        const SizedBox(height: 10),
        QuickActionCard(
          icon: Icons.fitness_center_rounded,
          title: 'Add workout',
          subtitle:
              'Workout logging will connect activity to nutrition insights.',
          enabled: true,
          onTap: () => _showWorkoutSheet(context),
        ),
        const SizedBox(height: 10),
        QuickActionCard(
          icon: Icons.monitor_weight_rounded,
          title: 'Add weight',
          subtitle: 'Log today’s weight and set a target weight.',
          enabled: true,
          onTap: () => _openAddWeight(context),
        ),
        const SizedBox(height: 10),
        const QuickActionCard(
          icon: Icons.water_drop_rounded,
          title: 'Add water',
          subtitle: 'Hydration tracking is coming soon.',
        ),
        const SizedBox(height: 10),
        const QuickActionCard(
          icon: Icons.bedtime_rounded,
          title: 'Add sleep',
          subtitle: 'Sleep tracking is coming soon for recovery insights.',
        ),
      ],
    );
  }

  Future<void> _openAddFood(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: AddFoodScreen(
              repo: repo,
              onDone: () async {
                await onFoodLogged();
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkoutSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddWorkoutSheet(),
    );
  }

  Future<void> _openAddWeight(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddWeightScreen(repo: repo)),
    );
    if (saved == true) await onFoodLogged();
  }
}

class AddWeightScreen extends StatefulWidget {
  const AddWeightScreen({required this.repo, super.key});

  final NutritionRepository repo;

  @override
  State<AddWeightScreen> createState() => _AddWeightScreenState();
}

class _AddWeightScreenState extends State<AddWeightScreen> {
  final _weight = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Weight',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today’s weigh-in',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For the best trend, weigh yourself every day at the same time, ideally under similar conditions.',
                    style: TextStyle(color: _mutedColor(context), height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _weight,
                    label: 'Current weight lb',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    useHintText: true,
                    hideHintWhenNotEmpty: true,
                  ),
                  if (_message != null) MessageBox(message: _message!),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Save Weight',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.repo.assistantProfile(const {});
      if (!mounted) return;
      final weightKg = _num(profile['weight_kg']);
      if (weightKg > 0) _weight.text = _formatWeightPounds(weightKg);
    } catch (_) {}
  }

  Future<void> _save() async {
    final weight = num.tryParse(_weight.text.trim());
    if (weight == null || weight <= 0) {
      setState(() => _message = 'Enter a valid current weight.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.repo.logWeight(weightPounds: weight);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not save weight: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AddWorkoutSheet extends StatelessWidget {
  const AddWorkoutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: _lineColor(context),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add Workout',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'What type of activity?',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 18),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const [
                WorkoutTypeRow(
                  icon: Icons.fitness_center_rounded,
                  title: 'Strength Training',
                  subtitle: 'Build and tone muscles',
                ),
                Divider(height: 1, color: AppColors.line),
                WorkoutTypeRow(
                  icon: Icons.favorite_rounded,
                  title: 'Cardio',
                  subtitle: 'Running, cycling, walking, etc.',
                  color: Colors.redAccent,
                ),
                Divider(height: 1, color: AppColors.line),
                WorkoutTypeRow(
                  icon: Icons.sports_basketball_rounded,
                  title: 'Sports',
                  subtitle: 'Tennis, basketball, soccer, etc.',
                ),
                Divider(height: 1, color: AppColors.line),
                WorkoutTypeRow(
                  icon: Icons.more_horiz_rounded,
                  title: 'Other Activity',
                  subtitle: 'Yoga, stretching, HIIT, etc.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class WorkoutTypeRow extends StatelessWidget {
  const WorkoutTypeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? _textColor(context);
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout logging is coming soon.')),
        );
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: _mutedColor(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _mutedColor(context)),
          ],
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? onTap : null,
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.green.withValues(alpha: .13)
                    : _panelColor(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: active ? AppColors.deepGreen : _mutedColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _panelColor(context),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Coming soon',
                            style: TextStyle(
                              color: _mutedColor(context),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.deepGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({
    required this.repo,
    required this.onDone,
    this.logDate,
    super.key,
  });

  final NutritionRepository repo;
  final Future<void> Function() onDone;
  final DateTime? logDate;

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _text = TextEditingController();
  final _caption = TextEditingController();
  XFile? _selectedPhoto;
  String? _loadingMode;
  String? _message;

  bool get _loading => _loadingMode != null;

  @override
  Widget build(BuildContext context) {
    final isPastDayEntry = widget.logDate != null;
    final showBackButton = isPastDayEntry || Navigator.of(context).canPop();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      children: [
        Row(
          children: [
            if (showBackButton)
              RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              )
            else
              const SizedBox(width: 42),
            const Expanded(
              child: Center(
                child: Text(
                  'Add Food',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Type what you ate, upload a photo, or scan a package code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        if (widget.logDate != null) ...[
          const SizedBox(height: 10),
          DateTargetBanner(date: widget.logDate!),
        ],
        const SizedBox(height: 18),
        AddEntryCard(
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.green,
          title: 'Type meal',
          subtitle: 'AI breaks it down, then you review before saving',
          child: Column(
            children: [
              AppTextField(
                controller: _text,
                label: 'Chicken rice broccoli or Chipotle burrito bowl',
                useHintText: true,
                hideHintWhenNotEmpty: true,
              ),
              const SizedBox(height: 12),
              if (_loadingMode == 'text')
                const AnalyzingMealIndicator(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Analyzing meal',
                  subtitle: 'Finding portions, macros, and nutrients',
                )
              else
                PrimaryButton(
                  label: 'Analyze meal',
                  compact: true,
                  onPressed: _loading ? null : _reviewTypedMeal,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AddEntryCard(
          icon: Icons.camera_alt_rounded,
          iconColor: AppColors.green,
          title: 'Upload photo',
          subtitle: 'Scan a plate, confirm ingredients, then save',
          child: Column(
            children: [
              AppTextField(
                controller: _caption,
                label: 'Optional: grilled chicken bowl',
                useHintText: true,
                hideHintWhenNotEmpty: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _choosePhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Take photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textColor(context),
                        side: BorderSide(color: _lineColor(context)),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _choosePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textColor(context),
                        side: BorderSide(color: _lineColor(context)),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedPhoto != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedPhoto!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _loadingMode == 'photo'
                  ? const AnalyzingMealIndicator(
                      icon: Icons.image_search_rounded,
                      title: 'Scanning photo',
                      subtitle: 'Detecting foods and portions',
                    )
                  : PrimaryButton(
                      label: 'Analyze photo',
                      compact: true,
                      onPressed: _selectedPhoto == null || _loading
                          ? null
                          : _logPhoto,
                    ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AddEntryCard(
          icon: Icons.qr_code_scanner_rounded,
          iconColor: AppColors.green,
          title: 'Scan package',
          subtitle: 'Scan a barcode or QR code, then review the serving',
          child: _loadingMode == 'code'
              ? const AnalyzingMealIndicator(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Looking up package',
                  subtitle: 'Estimating nutrition from the scanned code',
                )
              : PrimaryButton(
                  label: 'Scan code',
                  compact: true,
                  onPressed: _loading ? null : _scanPackagedFood,
                ),
        ),
        if (_message != null) MessageBox(message: _message!),
      ],
    );
  }

  Future<void> _choosePhoto(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
    );
    if (image == null) return;
    setState(() => _selectedPhoto = image);
  }

  Future<void> _logPhoto() async {
    final image = _selectedPhoto;
    if (image == null) return;
    final extension = image.name
        .split('.')
        .last
        .toLowerCase()
        .replaceAll('jpg', 'jpeg');
    final bytes = await image.readAsBytes();
    await _reviewDraft(
      () async => widget.repo.analyzePhotoFood(
        bytes: bytes,
        extension: extension,
        caption: _caption.text,
      ),
      mode: 'photo',
      source: 'photo',
      rawInput: _caption.text.trim().isEmpty ? 'Food photo' : _caption.text,
      imageBytes: bytes,
      imageExtension: extension,
    );
  }

  Future<void> _reviewTypedMeal() async {
    final input = _text.text.trim();
    if (input.isEmpty) {
      setState(() => _message = 'Type what you ate before analyzing.');
      return;
    }
    final clarified = await _maybeClarifyVagueMeal(input);
    if (!mounted || clarified == null) return;
    await _reviewDraft(
      () => widget.repo.analyzeTextFood(clarified),
      mode: 'text',
      source: 'text',
      rawInput: clarified,
    );
  }

  Future<void> _scanPackagedFood() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FoodCodeScannerScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    final normalizedCode = code.trim();
    await _reviewDraft(
      () => widget.repo.analyzeBarcodeFood(normalizedCode),
      mode: 'code',
      source: 'barcode',
      rawInput: 'Scanned package code: $normalizedCode',
    );
  }

  Future<void> _reviewDraft(
    Future<ParsedFood> Function() action, {
    required String mode,
    required String source,
    required String rawInput,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    setState(() {
      _loadingMode = mode;
      _message = null;
    });
    try {
      final parsed = await action();
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodReviewScreen(
            repo: widget.repo,
            initialMeal: parsed,
            source: source,
            rawInput: rawInput,
            logDate: widget.logDate,
            imageBytes: imageBytes,
            imageExtension: imageExtension,
          ),
        ),
      );
      if (saved == true) await widget.onDone();
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyFoodError(error));
    } finally {
      if (mounted) setState(() => _loadingMode = null);
    }
  }

  Future<String?> _maybeClarifyVagueMeal(String input) async {
    if (!_looksVagueMixedFood(input)) return input;
    final controller = TextEditingController();
    final clarified = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What was in it?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Mixed meals are more accurate when you add ingredients, portions, sauces, and toppings.',
                    style: TextStyle(color: _mutedColor(context), height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText:
                          'Wheat bread, turkey, Colby jack, mayo, lettuce',
                      filled: true,
                      fillColor: _panelColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(input),
                          child: const Text('Use as is'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final detail = controller.text.trim();
                            Navigator.of(context).pop(
                              detail.isEmpty ? input : '$input with $detail',
                            );
                          },
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    return clarified;
  }
}

class FoodReviewScreen extends StatefulWidget {
  const FoodReviewScreen({
    required this.repo,
    required this.initialMeal,
    required this.source,
    required this.rawInput,
    this.existingMeal,
    this.logDate,
    this.imageBytes,
    this.imageExtension,
    super.key,
  });

  final NutritionRepository repo;
  final ParsedFood initialMeal;
  final String source;
  final String rawInput;
  final Map<String, dynamic>? existingMeal;
  final DateTime? logDate;
  final Uint8List? imageBytes;
  final String? imageExtension;

  @override
  State<FoodReviewScreen> createState() => _FoodReviewScreenState();
}

class FoodCodeScannerScreen extends StatefulWidget {
  const FoodCodeScannerScreen({super.key});

  @override
  State<FoodCodeScannerScreen> createState() => _FoodCodeScannerScreenState();
}

class _FoodCodeScannerScreenState extends State<FoodCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf14,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            Positioned(
              left: 18,
              right: 18,
              top: 14,
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Scan package',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _controller.toggleTorch(),
                    icon: const Icon(
                      Icons.flashlight_on_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.green, width: 4),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Point the camera at a barcode or QR code on the package. You will review the serving before saving.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }
}

class _FoodReviewScreenState extends State<FoodReviewScreen> {
  late final TextEditingController _mealName;
  late String _mealType;
  late List<FoodMatch> _items;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _mealName = TextEditingController(text: widget.initialMeal.mealName);
    _mealType = widget.initialMeal.mealType;
    _items = List<FoodMatch>.from(widget.initialMeal.items);
  }

  @override
  void dispose() {
    _mealName.dispose();
    super.dispose();
  }

  Map<String, num> get _totals {
    return {
      for (final key in nutrientKeys)
        key: _items.fold<num>(0, (sum, item) => sum + item.nutrition[key]!),
    };
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Review your meal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Edit anything before saving so your nutrition is more accurate.',
              style: TextStyle(color: _mutedColor(context), height: 1.35),
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _mealName,
                    decoration: InputDecoration(
                      labelText: 'Meal name',
                      filled: true,
                      fillColor: _panelColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _mealType,
                    decoration: InputDecoration(
                      labelText: 'Meal type',
                      filled: true,
                      fillColor: _panelColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'snack', child: Text('Snack')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _mealType = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TotalsReviewCard(totals: totals),
            const SizedBox(height: 14),
            SectionHeader(
              title: 'Detected foods',
              action: 'Add item',
              onAction: () => _editItem(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _scanAdditionalItem,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan package item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textColor(context),
                side: BorderSide(color: _lineColor(context)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              const EmptyMeals(message: 'Add at least one food item to save.')
            else ...[
              for (var i = 0; i < _items.length; i++) ...[
                _FoodReviewItemCard(
                  item: _items[i],
                  onEdit: () => _editItem(index: i),
                  onRemove: () => setState(() => _items.removeAt(i)),
                  onAlternative: (alternative) {
                    setState(() {
                      _items[i] = _items[i].copyWith(
                        name: alternative,
                        query: alternative.toLowerCase(),
                        confidenceLabel: 'medium',
                        confidence: .7,
                      );
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (_message != null) MessageBox(message: _message!),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Save meal',
              loading: _saving,
              onPressed: _items.isEmpty || _saving ? null : _saveMeal,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMeal() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final reviewedMeal = widget.initialMeal.copyWith(
        mealName: _mealName.text.trim().isEmpty
            ? 'Reviewed Meal'
            : _mealName.text.trim(),
        mealType: _mealType,
        needsReview: false,
        items: _items,
      );
      final existingMeal = widget.existingMeal;
      if (existingMeal == null) {
        await widget.repo.saveReviewedMeal(
          parsed: reviewedMeal,
          source: widget.source,
          rawInput: widget.rawInput,
          date: widget.logDate,
          imageBytes: widget.imageBytes,
          imageExtension: widget.imageExtension,
        );
      } else {
        await widget.repo.updateReviewedMeal(
          meal: existingMeal,
          parsed: reviewedMeal,
          source: widget.source,
          rawInput: widget.rawInput,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyFoodError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editItem({int? index}) async {
    final current = index == null ? null : _items[index];
    final edited = await showModalBottomSheet<FoodMatch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodItemEditor(repo: widget.repo, item: current),
    );
    if (edited == null) return;
    setState(() {
      if (index == null) {
        _items.add(edited);
      } else {
        _items[index] = edited;
      }
    });
  }

  Future<void> _scanAdditionalItem() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FoodCodeScannerScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final parsed = await widget.repo.analyzeBarcodeFood(code.trim());
      if (!mounted) return;
      setState(() {
        _items.addAll(parsed.items);
        if (_mealName.text.trim().isEmpty ||
            _mealName.text.trim() == 'Reviewed Meal') {
          _mealName.text = parsed.mealName;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyFoodError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TotalsReviewCard extends StatelessWidget {
  const _TotalsReviewCard({required this.totals});

  final Map<String, num> totals;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated totals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TotalChip(
                label: 'Calories',
                value: '${totals['calories']!.round()}',
              ),
              _TotalChip(
                label: 'Protein',
                value: '${_compactNum(totals['protein'])}g',
              ),
              _TotalChip(
                label: 'Carbs',
                value: '${_compactNum(totals['carbs'])}g',
              ),
              _TotalChip(label: 'Fat', value: '${_compactNum(totals['fat'])}g'),
              _TotalChip(
                label: 'Fiber',
                value: '${_compactNum(totals['fiber'])}g',
              ),
              _TotalChip(
                label: 'Sodium',
                value: '${totals['sodium']!.round()}mg',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: _isDark(context) ? .16 : .09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: _mutedColor(context), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FoodReviewItemCard extends StatelessWidget {
  const _FoodReviewItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    required this.onAlternative,
  });

  final FoodMatch item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final ValueChanged<String> onAlternative;

  @override
  Widget build(BuildContext context) {
    final lowConfidence = item.confidenceLabel == 'low';
    final accent = lowConfidence ? const Color(0xFFFF6B6B) : AppColors.green;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  lowConfidence
                      ? Icons.help_outline_rounded
                      : Icons.check_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_compactNum(item.amount)} ${item.unit} • ${item.confidenceLabel} confidence',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${item.nutrition['calories']!.round()} kcal  •  P ${_compactNum(item.nutrition['protein'])}g  •  C ${_compactNum(item.nutrition['carbs'])}g  •  F ${_compactNum(item.nutrition['fat'])}g',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          if (item.clarifyingQuestion != null &&
              item.clarifyingQuestion!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.clarifyingQuestion!,
              style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
            ),
          ],
          if (item.alternatives.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final alternative in item.alternatives)
                  ActionChip(
                    label: Text(alternative),
                    onPressed: () => onAlternative(alternative),
                    backgroundColor: _panelColor(context),
                    side: BorderSide(color: _lineColor(context)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FoodItemEditor extends StatefulWidget {
  const _FoodItemEditor({required this.repo, this.item});

  final NutritionRepository repo;
  final FoodMatch? item;

  @override
  State<_FoodItemEditor> createState() => _FoodItemEditorState();
}

class _FoodItemEditorState extends State<_FoodItemEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;
  late final TextEditingController _sugar;
  late final TextEditingController _sodium;
  late String _unit;
  late num _baseAmount;
  bool _estimateLoading = false;
  bool _doneLoading = false;
  String? _estimateMessage;

  bool get _busy => _estimateLoading || _doneLoading;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _amount = TextEditingController(text: _compactNum(item?.amount ?? 1));
    _unit = _supportedUnits.contains(item?.unit) ? item!.unit : 'serving';
    _calories = TextEditingController(
      text: _compactNum(item?.nutrition['calories'] ?? 0),
    );
    _protein = TextEditingController(
      text: _compactNum(item?.nutrition['protein'] ?? 0),
    );
    _carbs = TextEditingController(
      text: _compactNum(item?.nutrition['carbs'] ?? 0),
    );
    _fat = TextEditingController(
      text: _compactNum(item?.nutrition['fat'] ?? 0),
    );
    _fiber = TextEditingController(
      text: _compactNum(item?.nutrition['fiber'] ?? 0),
    );
    _sugar = TextEditingController(
      text: _compactNum(item?.nutrition['sugar'] ?? 0),
    );
    _sodium = TextEditingController(
      text: _compactNum(item?.nutrition['sodium'] ?? 0),
    );
    _baseAmount = item?.amount == 0 ? 1 : item?.amount ?? 1;
    _amount.addListener(_scaleNutritionForAmount);
  }

  @override
  void dispose() {
    _amount.removeListener(_scaleNutritionForAmount);
    for (final controller in [
      _name,
      _amount,
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scaleNutritionForAmount() {
    final item = widget.item;
    if (item == null) return;
    final nextAmount = num.tryParse(_amount.text.trim());
    if (nextAmount == null || nextAmount <= 0 || _baseAmount <= 0) return;
    final ratio = nextAmount / _baseAmount;
    void setScaled(TextEditingController controller, String key) {
      controller.text = _compactNum((item.nutrition[key] ?? 0) * ratio);
    }

    setScaled(_calories, 'calories');
    setScaled(_protein, 'protein');
    setScaled(_carbs, 'carbs');
    setScaled(_fat, 'fat');
    setScaled(_fiber, 'fiber');
    setScaled(_sugar, 'sugar');
    setScaled(_sodium, 'sodium');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item == null ? 'Add ingredient' : 'Edit ingredient',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _editorField(_name, 'Food name'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(_amount, 'Amount', number: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: _editorDecoration(context, 'Unit'),
                        items: [
                          for (final unit in _supportedUnits)
                            DropdownMenuItem(value: unit, child: Text(unit)),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _unit = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nutrition estimate',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'We can estimate this from the food name, amount, and unit.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(_calories, 'Calories', number: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _editorField(_protein, 'Protein', number: true),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(_carbs, 'Carbs', number: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _editorField(_fat, 'Fat', number: true)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _editorField(_fiber, 'Fiber', number: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _editorField(_sugar, 'Sugar', number: true),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _editorField(_sodium, 'Sodium mg', number: true),
                if (_estimateMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _estimateMessage!,
                    style: TextStyle(
                      color: _estimateMessage!.startsWith('Estimated')
                          ? AppColors.deepGreen
                          : _mutedColor(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _estimateNutrition,
                        icon: _estimateLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Estimate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textColor(context),
                          side: BorderSide(color: _lineColor(context)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Done',
                        compact: true,
                        loading: _doneLoading,
                        onPressed: _busy ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorField(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _editorDecoration(context, label),
    );
  }

  InputDecoration _editorDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _panelColor(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _doneLoading = true;
      _estimateMessage = null;
    });
    try {
      if (_shouldEstimateBeforeSaving()) {
        final estimated = await _estimateNutrition(
          showMessage: false,
          fromDone: true,
        );
        if (!estimated && _nutritionIsEmpty()) {
          if (mounted) {
            setState(() {
              _estimateMessage =
                  'Could not estimate this item. You can enter nutrition manually.';
            });
          }
          return;
        }
      }
      final amount = num.tryParse(_amount.text.trim()) ?? 1;
      final nutrition = {
        for (final key in nutrientKeys) key: widget.item?.nutrition[key] ?? 0,
        'calories': num.tryParse(_calories.text.trim()) ?? 0,
        'protein': num.tryParse(_protein.text.trim()) ?? 0,
        'carbs': num.tryParse(_carbs.text.trim()) ?? 0,
        'fat': num.tryParse(_fat.text.trim()) ?? 0,
        'fiber': num.tryParse(_fiber.text.trim()) ?? 0,
        'sugar': num.tryParse(_sugar.text.trim()) ?? 0,
        'sodium': num.tryParse(_sodium.text.trim()) ?? 0,
      };
      final existing = widget.item;
      final item = existing == null
          ? FoodMatch(
              name: name,
              query: name.toLowerCase(),
              portionLabel: _reviewPortionLabel(amount, _unit),
              amount: amount,
              unit: _unit,
              servingGrams: _estimatedGrams(amount, _unit),
              provider: 'manual',
              providerFoodId:
                  'manual-${name.toLowerCase().replaceAll(' ', '-')}',
              confidence: _nutritionIsEmpty() ? 1 : .75,
              confidenceLabel: _nutritionIsEmpty() ? 'high' : 'medium',
              alternatives: const [],
              clarifyingQuestion: null,
              nutrition: nutrition,
              rawProviderPayload: {
                'amount': amount,
                'unit': _unit,
                'was_ai_estimated': !_nutritionIsEmpty(),
              },
            )
          : existing.copyWith(
              name: name,
              query: name.toLowerCase(),
              portionLabel: _reviewPortionLabel(amount, _unit),
              amount: amount,
              unit: _unit,
              servingGrams: _estimatedGrams(amount, _unit),
              nutrition: nutrition,
              rawProviderPayload: {
                ...existing.rawProviderPayload,
                'amount': amount,
                'unit': _unit,
              },
            );
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } finally {
      if (mounted) setState(() => _doneLoading = false);
    }
  }

  Future<bool> _estimateNutrition({
    bool showMessage = true,
    bool fromDone = false,
  }) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _estimateMessage = 'Enter a food name first.');
      return false;
    }
    final amount = num.tryParse(_amount.text.trim()) ?? 1;
    if (!fromDone) {
      setState(() {
        _estimateLoading = true;
        _estimateMessage = null;
      });
    }
    try {
      final parsed = await widget.repo.analyzeTextFood(
        '${_compactNum(amount)} $_unit $name',
      );
      if (!mounted) return false;
      if (parsed.items.isEmpty) throw StateError('No food estimate returned.');
      final estimate = parsed.items.first;
      _calories.text = _compactNum(estimate.nutrition['calories']);
      _protein.text = _compactNum(estimate.nutrition['protein']);
      _carbs.text = _compactNum(estimate.nutrition['carbs']);
      _fat.text = _compactNum(estimate.nutrition['fat']);
      _fiber.text = _compactNum(estimate.nutrition['fiber']);
      _sugar.text = _compactNum(estimate.nutrition['sugar']);
      _sodium.text = _compactNum(estimate.nutrition['sodium']);
      if (showMessage) {
        setState(() => _estimateMessage = 'Estimated nutrition updated.');
      }
      return true;
    } catch (_) {
      if (showMessage) {
        if (mounted) {
          setState(() {
            _estimateMessage =
                'Could not estimate this item. You can enter nutrition manually.';
          });
        }
      }
      return false;
    } finally {
      if (!fromDone && mounted) setState(() => _estimateLoading = false);
    }
  }

  bool _shouldEstimateBeforeSaving() {
    final existing = widget.item;
    if (existing == null) return _nutritionIsEmpty();
    final nameChanged =
        _name.text.trim().toLowerCase() != existing.name.toLowerCase();
    return nameChanged || _nutritionIsEmpty();
  }

  bool _nutritionIsEmpty() {
    return [
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _sodium,
    ].every((controller) => (num.tryParse(controller.text.trim()) ?? 0) == 0);
  }
}

const _supportedUnits = [
  'grams',
  'ounces',
  'cups',
  'tbsp',
  'tsp',
  'pieces',
  'slices',
  'large',
  'medium',
  'small',
  'serving',
  'container',
  'package',
];

bool _looksVagueMixedFood(String input) {
  final text = input.toLowerCase().trim();
  final vagueTerms = [
    'sandwich',
    'salad',
    'bowl',
    'burrito',
    'wrap',
    'smoothie',
    'omelet',
    'omelette',
    'soup',
    'pasta',
    'pizza',
  ];
  if (!vagueTerms.any((term) => RegExp('\\b$term\\b').hasMatch(text))) {
    return false;
  }
  final detailSignals = [
    ' with ',
    ' and ',
    ',',
    'chicken',
    'turkey',
    'beef',
    'rice',
    'beans',
    'cheese',
    'mayo',
    'lettuce',
    'protein',
  ];
  return !detailSignals.any(text.contains) &&
      text.split(RegExp(r'\s+')).length <= 4;
}

String _friendlyFoodError(Object error) {
  final text = error.toString();
  if (text.toLowerCase().contains('gemini') ||
      text.toLowerCase().contains('ai food parsing')) {
    return 'We could not analyze that meal clearly. Try describing it with portions or retake the photo.';
  }
  if (text.toLowerCase().contains('barcode') ||
      text.toLowerCase().contains('packaged food match')) {
    return 'We could not find an exact packaged food match for that barcode. Try scanning again, or add the item manually so it does not guess the wrong food.';
  }
  if (text.toLowerCase().contains('socket') ||
      text.toLowerCase().contains('host lookup') ||
      text.toLowerCase().contains('network')) {
    return 'No internet connection. Please try again when you are back online.';
  }
  return 'Something went wrong while saving this meal. Please review the items and try again.';
}

String _compactNum(Object? value) {
  final number = value is num ? value : num.tryParse('$value') ?? 0;
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(1);
}

String _reviewPortionLabel(num amount, String unit) {
  return '${_compactNum(amount)} $unit';
}

String _mealPlanVarietyInstruction({
  required int days,
  required int mealsPerDay,
  required String varietyMode,
  required String repeatPreference,
}) {
  final baseline =
      'Build the meal plan around the user selected budget, variety, and repeat preferences. Reuse core grocery ingredients when it helps cost and prep, and add variety when the user asks for it.';
  final weekly = days >= 7
      ? 'For a 7-day plan, avoid accidental copy-paste repetition unless the user selected repeat-heavy planning. It is okay to repeat meals for budget or prep, but the repetition should match the repeat preference.'
      : 'For shorter plans, keep the plan practical and match the requested variety level.';
  final mode = switch (varietyMode) {
    'Grocery efficient' =>
      'Prioritize a shorter grocery list, shared ingredients, leftovers, and batch-prep-friendly recipes.',
    'More variety' =>
      'Prioritize more distinct meals and flavors, while still combining duplicate grocery ingredients where practical.',
    _ =>
      'Balance variety and grocery savings. Repeat some ingredients and meals, but keep the week from feeling monotonous.',
  };
  final repeats = switch (repeatPreference) {
    'Repeat often' =>
      'The user is comfortable repeating meals often to save money and simplify grocery shopping.',
    'Mostly unique' =>
      'The user prefers mostly unique meals and is willing to buy more ingredients for variety.',
    _ =>
      'The user wants some repeated meals for convenience, with enough variety to stay interesting.',
  };
  return '$baseline $weekly $mode $repeats Meals per day requested: $mealsPerDay.';
}

num _estimatedGrams(num amount, String unit) {
  return switch (unit) {
    'ounces' => amount * 28,
    'cups' => amount * 240,
    'tbsp' => amount * 15,
    'tsp' => amount * 5,
    'slices' => amount * 28,
    'large' => amount * 50,
    'medium' => amount * 100,
    'small' => amount * 75,
    _ => amount,
  };
}

class DateTargetBanner extends StatelessWidget {
  const DateTargetBanner({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: _isDark(context) ? .16 : .09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: AppColors.deepGreen,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Adding to ${_formatHistoryDate(date)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    required this.repo,
    required this.dashboard,
    required this.goals,
    required this.onRefresh,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic>? goals;
  final Future<void> Function() onRefresh;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _chat = TextEditingController();
  final _chatScroll = ScrollController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadAssistantState();
  }

  @override
  void dispose() {
    _chat
      ..clear()
      ..dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: AiChatHeader(goals: _map(widget.goals))),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: _messages.isEmpty && _chat.text.trim().isEmpty
                        ? () {}
                        : _resetChat,
                  ),
                ],
              ),
            ),
            Expanded(child: _chatTab()),
            AiChatComposer(
              controller: _chat,
              loading: _loading,
              onSend: _loading ? null : _sendChat,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTab() {
    return ListView(
      controller: _chatScroll,
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
      children: [
        _assistantDisclaimer(),
        const SizedBox(height: 12),
        if (_messages.isEmpty) ...[
          AiChatEmptyState(onPrompt: _usePrompt),
          const SizedBox(height: 12),
        ],
        for (final message in _messages)
          AiMessageBubble(message: message, mine: message['role'] == 'user'),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AiTypingIndicator(),
          ),
        if (_error != null) MessageBox(message: _error!),
      ],
    );
  }

  Widget _assistantDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.health_and_safety_rounded,
            color: AppColors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'For medical nutrition needs, allergies, diabetes, kidney disease, pregnancy, or eating disorder concerns, use professional guidance.',
              style: TextStyle(color: _mutedColor(context), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _usePrompt(String prompt) {
    setState(() => _chat.text = prompt);
  }

  Future<void> _loadAssistantState() async {
    try {
      final messages = await widget.repo.chatMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
      });
      _scrollChatToBottom();
    } catch (_) {}
  }

  Future<void> _sendChat() async {
    final text = _chat.text.trim();
    if (text.isEmpty) return;
    if (!_isNutritionChatAllowed(text, _messages)) {
      _chat.clear();
      setState(() {
        _messages = [
          ..._messages,
          {'role': 'user', 'content': text},
          {
            'role': 'assistant',
            'content':
                'I can only help with nutrition, food logging, meals, macros, groceries, workouts, recovery, goals, and activity-related questions. Try asking me about protein, calories, food swaps, meal prep, training days, or how your intake lines up with your plan.',
          },
        ];
      });
      _scrollChatToBottom();
      return;
    }
    await _runAi(() async {
      _chat.clear();
      setState(() {
        _messages = [
          ..._messages,
          {'role': 'user', 'content': text},
        ];
      });
      _scrollChatToBottom();
      final response = await widget.repo.askAssistant(
        action: 'general_chat',
        message: text,
        dashboard: widget.dashboard,
        goals: widget.goals,
      );
      final messages = await widget.repo.chatMessages();
      setState(() {
        _messages = messages;
        if (response['message'] is String && messages.isEmpty) {
          _messages = [
            {'role': 'assistant', 'content': response['message']},
          ];
        }
      });
      _scrollChatToBottom();
    });
  }

  Future<void> _runAi(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _scrollChatToBottom();
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        _scrollChatToBottom();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollChatToBottom();
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _resetChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset chat?'),
        content: const Text(
          'This clears your coach chat history and starts a fresh conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _chat.clear();
      _messages = [];
      _error = null;
    });
    try {
      await widget.repo.clearChatMessages();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not reset chat: $error');
    }
  }
}

bool _isNutritionChatAllowed(
  String text, [
  List<Map<String, dynamic>> previousMessages = const [],
]) {
  final lower = text.toLowerCase();
  const blockedTerms = [
    'code',
    'coding',
    'programming',
    'python',
    'javascript',
    'typescript',
    'flutter code',
    'sql',
    'politics',
    'election',
    'movie',
    'movies',
    'tv show',
    'video game',
    'weather',
    'stock',
    'crypto',
    'homework',
    'essay',
  ];
  if (blockedTerms.any(lower.contains)) return false;

  const allowedTerms = [
    'food',
    'meal',
    'nutrition',
    'nutrient',
    'calorie',
    'calories',
    'macro',
    'protein',
    'carb',
    'carbs',
    'fat',
    'fiber',
    'sugar',
    'sodium',
    'vitamin',
    'mineral',
    'diet',
    'weight',
    'fat loss',
    'muscle',
    'gain',
    'maintain',
    'snack',
    'breakfast',
    'lunch',
    'dinner',
    'recipe',
    'ingredient',
    'grocery',
    'groceries',
    'restaurant',
    'healthy',
    'healthier',
    'swap',
    'portion',
    'serving',
    'hydration',
    'water',
    'activity',
    'exercise',
    'workout',
    'workout program',
    'training',
    'strength',
    'cardio',
    'steps',
    'walking',
    'running',
    'lifting',
    'burn',
    'metabolism',
    'goal',
    'plan',
    'prep',
    'energy',
    'hungry',
    'hunger',
    'full',
    'satisfied',
    'tired',
    'sore',
    'recovery',
    'recover',
    'soreness',
    'sleep',
    'craving',
    'cravings',
  ];
  if (allowedTerms.any(lower.contains)) return true;

  final lastAssistant = previousMessages.reversed
      .map(_map)
      .firstWhere(
        (message) => message['role'] == 'assistant',
        orElse: () => const {},
      );
  final lastAssistantText = '${lastAssistant['content'] ?? ''}'.toLowerCase();
  final lastAssistantWasNutrition =
      lastAssistantText.contains('?') &&
      allowedTerms.any(lastAssistantText.contains);
  if (!lastAssistantWasNutrition) return false;

  const contextualTerms = [
    'yes',
    'no',
    'yeah',
    'yep',
    'nope',
    'good',
    'bad',
    'okay',
    'ok',
    'fine',
    'great',
    'pretty',
    'better',
    'worse',
    'more',
    'less',
    'some',
    'a little',
    'a lot',
    'hungry',
    'full',
    'tired',
    'feel',
    'feeling',
    'energy',
    'them',
    'they',
    'it',
    'that',
  ];
  final wordCount = lower
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .length;
  return wordCount <= 14 || contextualTerms.any(lower.contains);
}

class AiChatHeader extends StatelessWidget {
  const AiChatHeader({required this.goals, super.key});

  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final planName = goals['plan_name'] ?? 'nutrition plan';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark(context)
              ? const [Color(0xFF17361F), Color(0xFF14221A)]
              : const [Color(0xFFEAF8E7), Color(0xFFF8FCF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.lime, AppColors.deepGreen],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coach Chat',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Nutrition and workout guidance for your $planName goals.',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _mutedColor(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiChatEmptyState extends StatelessWidget {
  const AiChatEmptyState({required this.onPrompt, super.key});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'How can I hit my protein goal today?',
      'Suggest a high-fiber snack.',
      'What should I eat after a workout?',
      'How do my meals and activity look today?',
    ];
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What can I help with?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask about calories, macros, meal prep, food swaps, workouts, recovery, or simple ways to improve your day.',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => onPrompt(prompt),
                  backgroundColor: AppColors.green.withValues(alpha: .1),
                  side: BorderSide(
                    color: AppColors.green.withValues(alpha: .22),
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiChatComposer extends StatelessWidget {
  const AiChatComposer({
    required this.controller,
    required this.loading,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final bool loading;
  final Future<void> Function()? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        border: Border(top: BorderSide(color: _lineColor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend?.call(),
              decoration: InputDecoration(
                hintText: 'Ask about meals, workouts, macros...',
                filled: true,
                fillColor: _panelColor(context),
                hintStyle: TextStyle(color: _mutedColor(context)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.lime, AppColors.deepGreen],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white.withValues(alpha: loading ? .45 : 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AiTypingIndicator extends StatelessWidget {
  const AiTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: _panelColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _lineColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking through your plan...',
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiAssistantPromoCard extends StatelessWidget {
  const AiAssistantPromoCard({
    required this.onTap,
    this.title = 'Coach Chat',
    this.subtitle =
        'Ask about meals, macros, workouts, recovery, food swaps, and meal prep.',
    super.key,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.lime, AppColors.deepGreen],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.deepGreen,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiMealPlanEntryCard extends StatelessWidget {
  const AiMealPlanEntryCard({
    required this.planName,
    required this.planDescription,
    required this.planColor,
    required this.planIcon,
    required this.onEditPlan,
    required this.onTap,
    super.key,
  });

  final String planName;
  final String planDescription;
  final Color planColor;
  final IconData planIcon;
  final VoidCallback onEditPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Meal Plans',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(
                  alpha: _isDark(context) ? .16 : .09,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: .28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Generate meals and grocery lists from your current goal.',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.deepGreen,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _panelColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _lineColor(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: planColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(planIcon, color: planColor, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (planDescription.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            planDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _mutedColor(context),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditPlan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: AppColors.deepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionHistoryCalendarCard extends StatelessWidget {
  const NutritionHistoryCalendarCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _lineColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.orange,
                    size: 30,
                  ),
                  Positioned(
                    bottom: 13,
                    child: Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nutrition Calendar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse tracked days, meals, trends, and goal progress.',
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.orange,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NutritionFeatureGrid extends StatelessWidget {
  const NutritionFeatureGrid({
    required this.planName,
    required this.onEditPlan,
    required this.onHistory,
    required this.onMealPlanner,
    super.key,
  });

  final String planName;
  final VoidCallback onEditPlan;
  final VoidCallback onHistory;
  final VoidCallback onMealPlanner;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: NutritionFeatureTile(
            icon: Icons.calendar_month_rounded,
            iconColor: AppColors.orange,
            title: 'Nutrition Calendar',
            subtitle: 'Track intake and view trends.',
            onTap: onHistory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NutritionFeatureTile(
            icon: Icons.restaurant_menu_rounded,
            iconColor: AppColors.green,
            title: 'AI Meal Planner',
            subtitle: 'Generate meals and grocery lists.',
            onTap: onMealPlanner,
            footer: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _panelColor(context),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Goal: $planName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEditPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: AppColors.deepGreen,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NutritionFeatureTile(
            icon: Icons.storefront_rounded,
            iconColor: AppColors.orange,
            title: 'Restaurant Recommendations',
            subtitle: 'Get AI suggestions from restaurant menus.',
            badge: 'Coming Soon',
          ),
        ),
      ],
    );
  }
}

class NutritionFeatureTile extends StatelessWidget {
  const NutritionFeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.footer,
    this.badge,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? footer;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 156,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _lineColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDark(context) ? 0 : .03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _mutedColor(context), fontSize: 11.5),
            ),
            const Spacer(),
            ?footer,
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AiMealPlanScreen extends StatefulWidget {
  const AiMealPlanScreen({required this.repo, required this.goals, super.key});

  final NutritionRepository repo;
  final Map<String, dynamic>? goals;

  @override
  State<AiMealPlanScreen> createState() => _AiMealPlanScreenState();
}

class _AiMealPlanScreenState extends State<AiMealPlanScreen> {
  final _likes = TextEditingController();
  final _dislikes = TextEditingController();
  final _allergies = TextEditingController();
  final _restrictions = TextEditingController();
  final _days = TextEditingController(text: '3');
  final _mealsPerDay = TextEditingController(text: '4');
  final _household = TextEditingController(text: '1');
  String _budget = 'moderate';
  String _skill = 'easy';
  String _prep = 'some prep';
  String _planGoal = 'high protein';
  bool _loading = false;
  String? _loadingAction;
  String? _error;
  Map<String, dynamic>? _mealPlan;
  Map<String, dynamic>? _groceryList;
  Map<String, dynamic>? _preferences;
  Map<String, dynamic>? _assistantProfile;
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _savedPlans = [];
  bool _loadingSavedPlans = true;
  String? _editingMealPlanId;
  final Set<String> _checkedGroceries = {};
  bool _showPlanSettings = false;

  static const _foods = [
    'Eggs',
    'Chicken',
    'Greek yogurt',
    'Oatmeal',
    'Rice',
    'Pasta',
    'Spaghetti',
    'Fish',
    'Beans',
    'Vegetables',
    'Fruit',
    'Cereal',
    'Protein shakes',
    'Turkey',
    'Tofu',
    'Potatoes',
    'Avocado',
    'Cottage cheese',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Meal Planner',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Create personalized meal plans based on your current goals.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingSavedPlans)
                const LoadingMealPlansCard()
              else if (_savedPlans.isEmpty)
                EmptyMealPlansCard(onCreate: _openWizard)
              else
                SavedMealPlansSection(
                  plans: _savedPlans,
                  selectedId: null,
                  groceryLoadingId:
                      _loadingAction?.startsWith('grocery_') == true
                      ? _loadingAction!.replaceFirst('grocery_', '')
                      : null,
                  onOpen: _openSavedPlan,
                  onEdit: _editSavedPlan,
                  onDelete: _deleteSavedPlan,
                  onGrocery: _openSavedPlanGrocery,
                  onCreate: _openWizard,
                ),
              if (_error != null) MessageBox(message: _error!),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _foodPreferenceCard(String food) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Text(
            'Food Preferences',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Start here so your meal plan uses foods you actually want.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.green.withValues(alpha: .2)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.deepGreen,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  food,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PreferenceActionButton(
                  icon: Icons.close_rounded,
                  label: 'Dislike',
                  onPressed: () => _savePreference(food, 'disliked'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PreferenceActionButton(
                  icon: Icons.remove_rounded,
                  label: 'Skip',
                  onPressed: () => _savePreference(food, 'neutral'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PreferenceActionButton(
                  icon: Icons.favorite_rounded,
                  label: 'Like',
                  filled: true,
                  onPressed: () => _savePreference(food, 'liked'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _preferenceHealthNotesCard() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Add allergies or diet restrictions now so AI avoids unsafe or unwanted foods.',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          if (_assistantProfile != null &&
              (_list(_assistantProfile!['allergies']).isNotEmpty ||
                  _list(
                    _assistantProfile!['dietary_restrictions'],
                  ).isNotEmpty)) ...[
            const SizedBox(height: 8),
            Text(
              'Saved: ${[..._list(_assistantProfile!['allergies']), ..._list(_assistantProfile!['dietary_restrictions'])].join(', ')}',
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppTextField(
            controller: _allergies,
            label: 'Allergies, separated by commas',
            useHintText: true,
            hideHintWhenNotEmpty: true,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _restrictions,
            label: 'Diet restrictions, separated by commas',
            useHintText: true,
            hideHintWhenNotEmpty: true,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Save health notes',
            compact: true,
            onPressed: _saveHealthNotes,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _preferenceTrainingIntro() {
    final answered = _actionablePreferenceCount();
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.tips_and_updates_rounded,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Train your meal plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'The more choices you answer, the better food choices the AI will recommend.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 13),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (answered / 5).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: AppColors.green,
                    backgroundColor: _panelColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$answered / 5 like or dislike answers before you can skip ahead',
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _preferenceContinueCard() {
    final canContinue = _canContinuePreferenceTraining();
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canContinue
                ? 'Ready for plan settings'
                : 'Answer 5 likes or dislikes to continue',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            canContinue
                ? 'You can keep answering foods later. For now, continue to your meal plan details.'
                : 'Skip choices do get saved, but they do not count toward unlocking plan settings.',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Continue to plan settings',
            onPressed: canContinue ? _continueToPlanSettings : null,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _planSettingsContent(Map<String, dynamic> goals) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Plan Settings',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ).copyWith(color: _textColor(context)),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showPlanSettings = false),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: const Text('More preferences'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PlanStepHeader(
                step: '1',
                title: 'Plan basics',
                subtitle: 'Choose the goal, days, meals, and people.',
              ),
              const SizedBox(height: 12),
              AssistantChoiceRow(
                label: 'Goal',
                value: _planGoal,
                values: const [
                  'fat loss',
                  'muscle gain',
                  'maintenance',
                  'general health',
                  'high protein',
                ],
                onChanged: (value) => setState(() => _planGoal = value),
              ),
              AssistantNumberRow(
                days: _days,
                meals: _mealsPerDay,
                household: _household,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PlanStepHeader(
                step: '2',
                title: 'Food rules',
                subtitle: 'Add anything the preference cards missed.',
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _likes, label: 'Extra foods you like'),
              const SizedBox(height: 10),
              AppTextField(
                controller: _dislikes,
                label: 'Extra foods you dislike',
              ),
              const SizedBox(height: 10),
              AppTextField(controller: _allergies, label: 'Allergies'),
              const SizedBox(height: 10),
              AppTextField(
                controller: _restrictions,
                label: 'Diet restrictions',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PlanStepHeader(
                step: '3',
                title: 'Shopping and prep',
                subtitle: 'Tell AI how realistic the plan should be.',
              ),
              const SizedBox(height: 12),
              AssistantChoiceRow(
                label: 'Budget',
                value: _budget,
                values: const ['low', 'moderate', 'flexible'],
                onChanged: (value) => setState(() => _budget = value),
              ),
              AssistantChoiceRow(
                label: 'Cooking',
                value: _skill,
                values: const ['easy', 'moderate', 'advanced'],
                onChanged: (value) => setState(() => _skill = value),
              ),
              AssistantChoiceRow(
                label: 'Meal prep',
                value: _prep,
                values: const ['minimal prep', 'some prep', 'batch cooking'],
                onChanged: (value) => setState(() => _prep = value),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _editingMealPlanId == null
                    ? 'Generate meal plan'
                    : 'Update meal plan',
                loading: _loadingAction == 'meal_plan',
                onPressed: _loading ? null : () => _generateMealPlan(goals),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loadingSavedPlans = true;
        _error = null;
      });
    }
    try {
      final preferences = await widget.repo.foodPreferences();
      final profile = await widget.repo.assistantProfile(_map(widget.goals));
      final dashboard = await widget.repo.dashboard();
      final savedPlans = await widget.repo.mealPlans();
      if (!mounted) return;
      if (_allergies.text.isEmpty) {
        _allergies.text = _list(profile['allergies']).join(', ');
      }
      if (_restrictions.text.isEmpty) {
        _restrictions.text = _list(profile['dietary_restrictions']).join(', ');
      }
      setState(() {
        _preferences = preferences;
        _assistantProfile = profile;
        _dashboard = dashboard;
        _savedPlans = savedPlans;
        _showPlanSettings =
            _showPlanSettings || _canContinuePreferenceTraining(preferences);
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load meal plans: $error');
    } finally {
      if (mounted) setState(() => _loadingSavedPlans = false);
    }
  }

  Set<String> _answeredFoods([Map<String, dynamic>? source]) {
    final prefs = source ?? _preferences;
    return {
      ..._list(prefs?['liked_foods']).map((item) => '$item'),
      ..._list(prefs?['disliked_foods']).map((item) => '$item'),
      ..._list(prefs?['neutral_foods']).map((item) => '$item'),
    };
  }

  // ignore: unused_element
  String? _nextPreferenceFood() {
    final answered = _answeredFoods();
    for (final food in _foods) {
      if (!answered.contains(food)) return food;
    }
    return null;
  }

  int _actionablePreferenceCount([Map<String, dynamic>? source]) {
    final prefs = source ?? _preferences;
    return {
      ..._list(prefs?['liked_foods']).map((item) => '$item'),
      ..._list(prefs?['disliked_foods']).map((item) => '$item'),
    }.length;
  }

  bool _canContinuePreferenceTraining([Map<String, dynamic>? source]) {
    return _actionablePreferenceCount(source) >= 5 ||
        _answeredFoods(source).length >= _foods.length;
  }

  Future<void> _saveHealthNotes() async {
    await widget.repo.updateAssistantProfile({
      'allergies': _splitText(_allergies.text),
      'dietary_restrictions': _splitText(_restrictions.text),
    });
    final profile = await widget.repo.assistantProfile(_map(widget.goals));
    if (!mounted) return;
    setState(() => _assistantProfile = profile);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Health notes saved.')));
  }

  Future<void> _continueToPlanSettings() async {
    await _saveHealthNotes();
    if (mounted) setState(() => _showPlanSettings = true);
  }

  // ignore: unused_element
  Future<void> _generateMealPlan(Map<String, dynamic> goals) async {
    final likedFoods = [
      ..._list(_preferences?['liked_foods']).map((item) => '$item'),
      ..._splitText(_likes.text),
    ];
    final dislikedFoods = [
      ..._list(_preferences?['disliked_foods']).map((item) => '$item'),
      ..._splitText(_dislikes.text),
    ];
    final request = {
      'goal': _planGoal,
      'calories_per_day': _num(goals['calories'], fallback: 2200),
      'protein_target': _num(goals['protein'], fallback: 150),
      'carb_target': _num(goals['carbs'], fallback: 250),
      'fat_target': _num(goals['fat'], fallback: 70),
      'fiber_target': _num(goals['fiber'], fallback: 30),
      'days': int.tryParse(_days.text) ?? 3,
      'meals_per_day': int.tryParse(_mealsPerDay.text) ?? 4,
      'household_size': int.tryParse(_household.text) ?? 1,
      'foods_like': likedFoods.toSet().toList(),
      'foods_dislike': dislikedFoods.toSet().toList(),
      'allergies': _allergies.text,
      'dietary_restrictions': _restrictions.text,
      'budget_preference': _budget,
      'cooking_difficulty': _skill,
      'meal_prep_preference': _prep,
      'variety_mode': 'Balanced rotation',
      'repeat_preference': 'Some repeats',
      'variety_instruction': _mealPlanVarietyInstruction(
        days: int.tryParse(_days.text) ?? 3,
        mealsPerDay: int.tryParse(_mealsPerDay.text) ?? 4,
        varietyMode: 'Balanced rotation',
        repeatPreference: 'Some repeats',
      ),
    };
    await _runAi('meal_plan', () async {
      await widget.repo.updateAssistantProfile({
        'goal_type': _planGoal,
        'household_size': request['household_size'],
        'budget_preference': _budget,
        'cooking_skill': _skill,
        'meal_prep_preference': _prep,
        'allergies': _splitText(_allergies.text),
        'dietary_restrictions': _splitText(_restrictions.text),
      });
      final response = await widget.repo.askAssistant(
        action: 'meal_plan',
        request: request,
        dashboard: _dashboard,
        goals: widget.goals,
      );
      if (_editingMealPlanId == null) {
        await widget.repo.saveMealPlan(response);
      } else {
        await widget.repo.updateMealPlan(_editingMealPlanId!, response);
      }
      final savedPlans = await widget.repo.mealPlans();
      setState(() {
        _mealPlan = response;
        _groceryList = null;
        _checkedGroceries.clear();
        _savedPlans = savedPlans;
        _editingMealPlanId = null;
      });
    });
  }

  // ignore: unused_element
  Future<void> _generateGroceryList() async {
    final plan = _mealPlan;
    if (plan == null) return;
    await _runAi('grocery', () async {
      final response = await widget.repo.askAssistant(
        action: 'grocery_list',
        mealPlan: plan,
        dashboard: _dashboard,
        goals: widget.goals,
      );
      await widget.repo.saveGroceryList(response);
      setState(() {
        _groceryList = response;
        _checkedGroceries.clear();
      });
    });
  }

  // ignore: unused_element
  Future<void> _copyGroceryList({required bool jsonMode}) async {
    final list = _groceryList;
    if (list == null) return;
    final text = jsonMode
        ? const JsonEncoder.withIndent('  ').convert(list)
        : _stringValue(list['export_text'], _groceryText(list));
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(jsonMode ? 'JSON copied.' : 'Grocery list copied.'),
      ),
    );
  }

  Future<void> _savePreference(String food, String preference) async {
    await widget.repo.saveFoodPreference(food: food, preference: preference);
    final prefs = await widget.repo.foodPreferences();
    if (!mounted) return;
    setState(() {
      _preferences = prefs;
    });
  }

  Future<void> _runAi(String actionName, Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _loadingAction = actionName;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _openWizard() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealPlanWizardScreen(
          repo: widget.repo,
          goals: _map(widget.goals),
          initialProfile: _assistantProfile,
          preferences: _preferences,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openSavedPlan(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealPlanDetailScreen(
          repo: widget.repo,
          goals: _map(widget.goals),
          planRow: row,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openSavedPlanGrocery(Map<String, dynamic> row) async {
    setState(() {
      _loading = true;
      _loadingAction = 'grocery_${row['id']}';
      _error = null;
    });
    try {
      final plan = _normalizeMealPlanCalendar(_map(row['plan']));
      final response = await widget.repo.askAssistant(
        action: 'grocery_list',
        mealPlan: plan,
        dashboard: _dashboard,
        goals: _map(widget.goals),
      );
      await widget.repo.saveGroceryList(response, mealPlanId: '${row['id']}');
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => GroceryListScreen(initialList: response),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not open grocery list: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _editSavedPlan(Map<String, dynamic> row) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MealPlanWizardScreen(
          repo: widget.repo,
          goals: _map(widget.goals),
          initialProfile: _assistantProfile,
          preferences: _preferences,
          planRow: row,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteSavedPlan(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal plan?'),
        content: Text(
          'Delete ${_stringValue(row['title'], 'this meal plan')} permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repo.deleteMealPlan('${row['id']}');
    await _load();
  }
}

class LoadingMealPlansCard extends StatelessWidget {
  const LoadingMealPlansCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.deepGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loading saved plans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pulling your meal plans from your account.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyMealPlansCard extends StatelessWidget {
  const EmptyMealPlansCard({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.deepGreen,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No meal plans yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first AI meal plan based on your nutrition goals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Create Meal Plan',
            onPressed: () async => onCreate(),
          ),
        ],
      ),
    );
  }
}

class MealPlanWizardScreen extends StatefulWidget {
  const MealPlanWizardScreen({
    required this.repo,
    required this.goals,
    this.initialProfile,
    this.preferences,
    this.planRow,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic> goals;
  final Map<String, dynamic>? initialProfile;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? planRow;

  @override
  State<MealPlanWizardScreen> createState() => _MealPlanWizardScreenState();
}

class _MealPlanWizardScreenState extends State<MealPlanWizardScreen> {
  int _step = 0;
  int _days = 3;
  int _meals = 4;
  bool _customMeals = false;
  bool _snacks = true;
  int _household = 1;
  String _budget = 'Balanced';
  String _difficulty = 'Easy';
  String _prep = 'Standard cooking';
  String _variety = 'Balanced rotation';
  String _repeats = 'Some repeats';
  final _likes = TextEditingController();
  final _dislikes = TextEditingController();
  final _allergies = TextEditingController();
  final _restrictions = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = _map(widget.planRow?['plan']);
    if (plan.isNotEmpty) {
      _days = _num(plan['days'], fallback: 3).round();
      _meals = _num(plan['meals_per_day'], fallback: 4).round();
      _customMeals = !const [3, 4, 5].contains(_meals);
      _household = _num(plan['household_size'], fallback: 1).round();
      _variety = _stringValue(plan['variety_mode'], _variety);
      _repeats = _stringValue(plan['repeat_preference'], _repeats);
    }
    final profile = _map(widget.initialProfile);
    _allergies.text = _list(profile['allergies']).join(', ');
    _restrictions.text = _list(profile['dietary_restrictions']).join(', ');
    final prefs = _map(widget.preferences);
    _likes.text = _list(prefs['liked_foods']).join(', ');
    _dislikes.text = _list(prefs['disliked_foods']).join(', ');
  }

  @override
  void dispose() {
    _likes.dispose();
    _dislikes.dispose();
    _allergies.dispose();
    _restrictions.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.planRow != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Meal Plan' : 'Create Meal Plan',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            WizardProgress(step: _step),
            const SizedBox(height: 14),
            if (_step == 0) _goalStep(),
            if (_step == 1) _settingsStep(),
            if (_step == 2) _foodRulesStep(),
            if (_step == 3) _reviewStep(),
            if (_error != null) MessageBox(message: _error!),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_step > 0) ...[
                  SizedBox(
                    width: 132,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 132,
                  child: PrimaryButton(
                    label: _step == 3
                        ? (isEditing ? 'Update' : 'Generate')
                        : 'Continue',
                    loading: _loading,
                    onPressed: _loading
                        ? null
                        : _step == 3
                        ? _generate
                        : () async => setState(() => _step++),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalStep() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlanStepHeader(
            step: '1',
            title: 'Use current goal',
            subtitle: 'The plan will use your active targets from the app.',
          ),
          const SizedBox(height: 12),
          CurrentGoalMiniCard(goals: widget.goals, onEdit: _openGoalEditor),
          const SizedBox(height: 12),
          TargetSummaryGrid(goals: widget.goals),
        ],
      ),
    );
  }

  Widget _settingsStep() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlanStepHeader(
            step: '2',
            title: 'Meal plan settings',
            subtitle: 'Choose the plan length and how realistic it should be.',
          ),
          const SizedBox(height: 12),
          DropdownNumberRow(
            label: 'Days',
            value: _days,
            values: const [1, 2, 3, 4, 5, 6, 7],
            onChanged: (v) => setState(() => _days = v),
          ),
          AssistantChoiceRow(
            label: 'Meals/day',
            value: _customMeals ? 'Custom' : '$_meals',
            values: const ['3', '4', '5', 'Custom'],
            onChanged: (v) => setState(() {
              _customMeals = v == 'Custom';
              if (!_customMeals) _meals = int.tryParse(v) ?? _meals;
            }),
          ),
          if (_customMeals)
            DropdownNumberRow(
              label: 'Custom meals/day',
              value: _meals,
              values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
              onChanged: (v) => setState(() => _meals = v),
            ),
          NumberChoiceRow(
            label: 'Servings',
            value: _household,
            values: const [1, 2, 3, 4],
            onChanged: (v) => setState(() => _household = v),
          ),
          SwitchListTile(
            value: _snacks,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Include snacks',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onChanged: (v) => setState(() => _snacks = v),
          ),
          AssistantChoiceRow(
            label: 'Budget',
            value: _budget,
            values: const ['Budget-friendly', 'Balanced', 'Premium'],
            onChanged: (v) => setState(() => _budget = v),
          ),
          AssistantChoiceRow(
            label: 'Cooking',
            value: _difficulty,
            values: const ['Easy', 'Moderate', 'Advanced'],
            onChanged: (v) => setState(() => _difficulty = v),
          ),
          AssistantChoiceRow(
            label: 'Prep style',
            value: _prep,
            values: const [
              'Minimal cooking',
              'Standard cooking',
              'Meal prep friendly',
            ],
            onChanged: (v) => setState(() => _prep = v),
          ),
          AssistantChoiceRow(
            label: 'Variety',
            value: _variety,
            values: const [
              'Grocery efficient',
              'Balanced rotation',
              'More variety',
            ],
            onChanged: (v) => setState(() => _variety = v),
          ),
          AssistantChoiceRow(
            label: 'Repeats',
            value: _repeats,
            values: const ['Repeat often', 'Some repeats', 'Mostly unique'],
            onChanged: (v) => setState(() => _repeats = v),
          ),
        ],
      ),
    );
  }

  Widget _foodRulesStep() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlanStepHeader(
            step: '3',
            title: 'Food rules',
            subtitle: 'Optional preferences to personalize the plan.',
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _likes, label: 'Foods you like'),
          const SizedBox(height: 10),
          AppTextField(controller: _dislikes, label: 'Foods you dislike'),
          const SizedBox(height: 10),
          AppTextField(controller: _allergies, label: 'Allergies'),
          const SizedBox(height: 10),
          AppTextField(controller: _restrictions, label: 'Diet restrictions'),
          const SizedBox(height: 10),
          AppTextField(controller: _notes, label: 'Notes for AI'),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlanStepHeader(
            step: '4',
            title: 'Review and generate',
            subtitle: 'Confirm the details before AI builds your plan.',
          ),
          const SizedBox(height: 12),
          ReviewLine(
            label: 'Goal',
            value: _stringValue(widget.goals['plan_name'], 'Current goal'),
          ),
          ReviewLine(label: 'Days', value: '$_days'),
          ReviewLine(label: 'Meals/day', value: '$_meals'),
          ReviewLine(
            label: 'Snacks',
            value: _snacks ? 'Included' : 'Not included',
          ),
          ReviewLine(label: 'Servings', value: '$_household'),
          ReviewLine(label: 'Budget', value: _budget),
          ReviewLine(label: 'Cooking', value: _difficulty),
          ReviewLine(label: 'Prep', value: _prep),
          ReviewLine(label: 'Variety', value: _variety),
          ReviewLine(label: 'Repeats', value: _repeats),
        ],
      ),
    );
  }

  Future<void> _openGoalEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(
          goals: widget.goals,
          repo: widget.repo,
          isSetup: widget.goals['setup_completed'] != true,
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = {
        'goal': widget.goals['plan_name'],
        'calories_per_day': _num(widget.goals['calories']),
        'protein_target': _num(widget.goals['protein']),
        'carb_target': _num(widget.goals['carbs']),
        'fat_target': _num(widget.goals['fat']),
        'fiber_target': _num(widget.goals['fiber']),
        'sugar_target': _num(widget.goals['sugar']),
        'sodium_target': _num(widget.goals['sodium']),
        'potassium_target': _num(widget.goals['potassium']),
        'profile': widget.initialProfile ?? {},
        'days': _days,
        'meals_per_day': _meals,
        'include_snacks': _snacks,
        'household_size': _household,
        'budget_preference': _budget,
        'cooking_difficulty': _difficulty,
        'meal_prep_preference': _prep,
        'variety_mode': _variety,
        'repeat_preference': _repeats,
        'variety_instruction': _mealPlanVarietyInstruction(
          days: _days,
          mealsPerDay: _meals,
          varietyMode: _variety,
          repeatPreference: _repeats,
        ),
        'foods_like': _splitText(_likes.text),
        'foods_dislike': _splitText(_dislikes.text),
        'allergies': _splitText(_allergies.text),
        'dietary_restrictions': _splitText(_restrictions.text),
        'notes': _notes.text,
      };
      final uniqueRequested =
          _repeats == 'Mostly unique' || _variety == 'More variety';
      var attempt = 0;
      Map<String, dynamic>? plan;
      var avoidNames = <String>[];
      while (attempt < (uniqueRequested ? 3 : 1)) {
        final generatedPlan = await widget.repo.generateMealPlan(
          request: {
            ...request,
            if (attempt > 0) ...{
              'retry_reason':
                  'The previous response repeated too many meal names, returned blank days, or did not provide enough unique meals for the selected preferences.',
              'unique_retry': true,
              'avoid_repeated_meal_names': avoidNames,
              'variety_instruction':
                  '${request['variety_instruction']} This is retry ${attempt + 1}. Return all $_days days with actual meals for each day. Create genuinely different meal names and recipes across the plan. Do not copy Day 1 into every day.',
            },
          },
          goals: widget.goals,
        );
        plan = _normalizeMealPlanCalendar({
          ...generatedPlan,
          'days': _days,
          'meals_per_day': _meals,
          'household_size': _household,
        }, fillMissingMeals: !uniqueRequested);
        if (!_planNeedsUniqueRetry(
          plan,
          varietyMode: _variety,
          repeatPreference: _repeats,
        )) {
          break;
        }
        avoidNames = _mealNamesForPlan(plan);
        attempt++;
      }
      if (plan == null || _planHasBlankDays(plan)) {
        throw StateError(
          'AI returned an incomplete meal plan. Please generate again.',
        );
      }
      Map<String, dynamic> row;
      if (widget.planRow == null) {
        row = await widget.repo.saveMealPlan(plan);
      } else {
        await widget.repo.updateMealPlan('${widget.planRow!['id']}', plan);
        row = {
          ...widget.planRow!,
          'plan': plan,
          'title': plan['title'] ?? widget.planRow!['title'],
        };
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<bool, bool>(
        MaterialPageRoute(
          builder: (_) => MealPlanDetailScreen(
            repo: widget.repo,
            goals: widget.goals,
            planRow: row,
          ),
        ),
        result: true,
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not generate plan: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class MealPlanDetailScreen extends StatefulWidget {
  const MealPlanDetailScreen({
    required this.repo,
    required this.goals,
    required this.planRow,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic> goals;
  final Map<String, dynamic> planRow;

  @override
  State<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends State<MealPlanDetailScreen> {
  late Map<String, dynamic> _plan;
  Map<String, dynamic>? _groceryList;
  int _selectedDayIndex = 0;
  String? _loadingAction;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _plan = _normalizeMealPlanCalendar(_map(widget.planRow['plan']));
  }

  @override
  Widget build(BuildContext context) {
    final planDays = _list(_plan['days_plan']).map(_map).toList();
    final selectedDay = planDays.isEmpty
        ? <String, dynamic>{}
        : planDays[_selectedDayIndex.clamp(0, planDays.length - 1)];
    final days = _num(_plan['days'], fallback: planDays.length);
    final mealsPerDay = _num(_plan['meals_per_day'], fallback: 0);
    final calories = _averageDailyPlanValue(_plan, 'calories');
    final protein = _averageDailyPlanValue(_plan, 'protein');
    final carbs = _averageDailyPlanValue(_plan, 'carbs');
    final fat = _averageDailyPlanValue(_plan, 'fat');
    final saved =
        '${widget.planRow['id']}'.isNotEmpty &&
        '${widget.planRow['id']}' != 'null';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(_changed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meal Plan',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _stringValue(_plan['title'], 'AI Meal Plan'),
                        style: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: saved
                        ? AppColors.green.withValues(alpha: .13)
                        : _panelColor(context),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: saved ? AppColors.green : _lineColor(context),
                    ),
                  ),
                  child: Text(
                    saved ? 'Saved' : 'Save',
                    style: const TextStyle(
                      color: AppColors.deepGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            MealPlanSummaryCard(
              plan: _plan,
              goals: widget.goals,
              days: days.round(),
              mealsPerDay: mealsPerDay.round(),
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check_circle_rounded, size: 17),
                    label: Text(saved ? 'Done' : 'Save'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingAction == null
                        ? () => setState(
                            () => _error =
                                'Full plan regeneration is available from Create Meal Plan.',
                          )
                        : null,
                    icon: const Icon(Icons.autorenew_rounded, size: 17),
                    label: const Text('Redo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingAction == null ? _openGroceryList : null,
                    icon: _loadingAction == 'grocery'
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_cart_rounded, size: 17),
                    label: const Text('Grocery'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingAction == null ? _resetPlanDates : null,
              icon: _loadingAction == 'reset_dates'
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.today_rounded, size: 17),
              label: const Text('Reset dates to today'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            MealPlanWeekSelector(
              days: planDays,
              selectedIndex: _selectedDayIndex,
              onSelected: (index) => setState(() => _selectedDayIndex = index),
            ),
            const SizedBox(height: 14),
            if (selectedDay.isNotEmpty)
              MealPlanSelectedDayView(
                day: selectedDay,
                date: _dateForPlanDay(selectedDay),
                onRegenerateMeal: _regenerateMeal,
                onToggleEaten: _toggleMealEaten,
                onOpenMeal: _openMealDetails,
              )
            else
              const EmptyMeals(message: 'No meals found in this plan.'),
            if (_list(_plan['prep_notes']).isNotEmpty) ...[
              const SizedBox(height: 14),
              AiResultCard(
                title: 'Prep Notes',
                children: [
                  for (final note in _list(_plan['prep_notes']))
                    BulletText('$note'),
                ],
              ),
            ],
            if (_error != null) MessageBox(message: _error!),
          ],
        ),
      ),
    );
  }

  Future<void> _openGroceryList() async {
    if ('${widget.planRow['id']}'.isEmpty ||
        '${widget.planRow['id']}' == 'null') {
      setState(() {
        _error = 'Save this meal plan first to generate a grocery list.';
      });
      return;
    }
    final list = _groceryList ?? await _generateGrocery();
    if (list == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => GroceryListScreen(initialList: list)),
    );
  }

  Future<Map<String, dynamic>?> _generateGrocery() async {
    setState(() {
      _loadingAction = 'grocery';
      _error = null;
    });
    try {
      final response = await widget.repo.askAssistant(
        action: 'grocery_list',
        mealPlan: _plan,
        goals: widget.goals,
      );
      await widget.repo.saveGroceryList(
        response,
        mealPlanId: '${widget.planRow['id']}',
      );
      if (mounted) setState(() => _groceryList = response);
      return response;
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not generate grocery list: $error');
      }
      return null;
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _regenerateMeal(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
  ) async {
    final controller = TextEditingController();
    final quickOptions = [
      'I do not like this food',
      'Make it higher protein',
      'Make it lower calorie',
      'Make it easier to cook',
      'Use cheaper ingredients',
      'Avoid this ingredient',
    ];
    String? selected;
    final change = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Swap this meal',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell AI what should change while keeping the day close to your targets.',
                    style: TextStyle(color: _mutedColor(context), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in quickOptions)
                        ChoiceChip(
                          label: Text(option),
                          selected: selected == option,
                          onSelected: (_) =>
                              setModalState(() => selected = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'No rice, more chicken, lower carb...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Regenerate Meal',
                    onPressed: () async {
                      final typed = controller.text.trim();
                      final quickChoice = selected;
                      Navigator.of(context).pop(
                        [?quickChoice, if (typed.isNotEmpty) typed].join('. '),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (change == null || change.trim().isEmpty) return;

    setState(() {
      _loadingAction = 'meal_${day['day']}_${meal['meal_type']}';
      _error = null;
    });
    try {
      final replacement = await widget.repo.regenerateMeal(
        mealPlan: _plan,
        meal: meal,
        request: {
          'day': day['day'],
          'meal_type': meal['meal_type'],
          'requested_change': change,
          'other_meals_for_day': _list(
            day['meals'],
          ).where((item) => !identical(item, meal)).toList(),
        },
        goals: widget.goals,
      );
      final normalized = _normalizeRegeneratedMeal(replacement, meal);
      _replaceMeal(day, meal, normalized);
      await widget.repo.updateMealPlan('${widget.planRow['id']}', _plan);
      if (!mounted) return;
      setState(() {
        _changed = true;
        _groceryList = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not regenerate meal: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  void _replaceMeal(
    Map<String, dynamic> day,
    Map<String, dynamic> original,
    Map<String, dynamic> replacement,
  ) {
    final days = _list(_plan['days_plan']).map(_map).toList();
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      if ('${days[dayIndex]['day']}' != '${day['day']}') continue;
      final meals = _list(days[dayIndex]['meals']).map(_map).toList();
      for (var mealIndex = 0; mealIndex < meals.length; mealIndex++) {
        final sameType =
            '${meals[mealIndex]['meal_type']}' == '${original['meal_type']}';
        final sameName = '${meals[mealIndex]['name']}' == '${original['name']}';
        if (sameType && sameName) {
          meals[mealIndex] = {
            ...replacement,
            'meal_id': _mealIdFor(day, replacement, fallback: original),
            'is_eaten': false,
            'eaten_at': null,
          };
          break;
        }
      }
      days[dayIndex] = {...days[dayIndex], 'meals': meals};
      break;
    }
    _plan = {..._plan, 'days_plan': days};
  }

  Future<void> _toggleMealEaten(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
    bool eaten,
  ) async {
    final previousPlan = _plan;
    final timestamp = eaten ? DateTime.now().toIso8601String() : null;
    final existingLoggedMealId = _stringValue(meal['logged_meal_id'], '');
    setState(() {
      _plan = _updateMealInPlan(day, meal, {
        ...meal,
        'is_eaten': eaten,
        'eaten_at': timestamp,
      });
      _changed = true;
    });
    try {
      String? loggedMealId;
      if (eaten && existingLoggedMealId.isEmpty) {
        loggedMealId = await widget.repo.logMealPlanMeal(
          meal,
          date: _dateForPlanDay(day),
        );
      }
      if (loggedMealId != null) {
        _plan = _updateMealInPlan(day, meal, {
          ...meal,
          'is_eaten': true,
          'eaten_at': timestamp,
          'logged_meal_id': loggedMealId,
          'logged_date': _date(_dateForPlanDay(day)),
        });
      }
      await widget.repo.updateMealPlan('${widget.planRow['id']}', _plan);
      if (mounted) {
        setState(() {
          _changed = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plan = previousPlan;
        _error = 'Could not update this meal. Please try again.';
      });
    }
  }

  Future<void> _resetPlanDates() async {
    final previousPlan = _plan;
    final days = _list(_plan['days_plan']).map(_map).toList();
    if (days.isEmpty) return;
    final activeIndex = _nextUneatenDayIndex(days);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final updatedDays = <Map<String, dynamic>>[];
    for (var index = 0; index < days.length; index++) {
      final date = normalizedToday.add(Duration(days: index - activeIndex));
      updatedDays.add({...days[index], 'day_date': _date(date)});
    }
    final planStartDate = normalizedToday.subtract(Duration(days: activeIndex));
    setState(() {
      _loadingAction = 'reset_dates';
      _error = null;
      _selectedDayIndex = activeIndex;
      _plan = {
        ..._plan,
        'plan_start_date': _date(planStartDate),
        'days_plan': updatedDays,
      };
      _changed = true;
    });
    try {
      await widget.repo.updateMealPlan('${widget.planRow['id']}', _plan);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plan = previousPlan;
        _error = 'Could not reset plan dates. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _openMealDetails(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MealPlanMealDetailsSheet(
        day: day,
        meal: meal,
        date: _dateForPlanDay(day),
        onToggleEaten: (eaten) async {
          Navigator.of(context).pop();
          await _toggleMealEaten(day, meal, eaten);
        },
        onRegenerate: () async {
          Navigator.of(context).pop();
          await _regenerateMeal(day, meal);
        },
      ),
    );
  }

  Map<String, dynamic> _updateMealInPlan(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
    Map<String, dynamic> replacement,
  ) {
    final days = _list(_plan['days_plan']).map(_map).toList();
    final targetMealId = _mealIdFor(day, meal);
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      if ('${days[dayIndex]['day']}' != '${day['day']}') continue;
      final meals = _list(days[dayIndex]['meals']).map(_map).toList();
      for (var mealIndex = 0; mealIndex < meals.length; mealIndex++) {
        if (_mealIdFor(days[dayIndex], meals[mealIndex]) == targetMealId) {
          meals[mealIndex] = replacement;
          break;
        }
      }
      days[dayIndex] = {...days[dayIndex], 'meals': meals};
      break;
    }
    return {..._plan, 'days_plan': days};
  }
}

class MealPlanStatTile extends StatelessWidget {
  const MealPlanStatTile({
    required this.label,
    required this.value,
    this.unit,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class MealPlanSummaryCard extends StatelessWidget {
  const MealPlanSummaryCard({
    required this.plan,
    required this.goals,
    required this.days,
    required this.mealsPerDay,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    super.key,
  });

  final Map<String, dynamic> plan;
  final Map<String, dynamic> goals;
  final int days;
  final int mealsPerDay;
  final num calories;
  final num protein;
  final num carbs;
  final num fat;

  @override
  Widget build(BuildContext context) {
    final household = _num(plan['household_size'], fallback: 1).round();
    final goal = _stringValue(
      plan['goal_type'],
      _stringValue(goals['plan_name'], 'Current goal'),
    );
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$days days • $mealsPerDay meals/day • $household servings',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MealFactChip(
                label: '${calories.round()} kcal/day',
                color: AppColors.orange,
              ),
              _MealFactChip(
                label: 'P ${protein.round()}g',
                color: AppColors.green,
              ),
              _MealFactChip(
                label: 'C ${carbs.round()}g',
                color: AppColors.yellow,
              ),
              _MealFactChip(
                label: 'F ${fat.round()}g',
                color: AppColors.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MealPlanWeekSelector extends StatelessWidget {
  const MealPlanWeekSelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<Map<String, dynamic>> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AiResultCard(
      title: days.length >= 7 ? 'Weekly View' : 'Plan Days',
      children: [
        Text(
          'Tap a day to review meals, nutrition, and swaps.',
          style: TextStyle(color: _mutedColor(context), fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final day = days[index];
              final selected = index == selectedIndex;
              final meals = _list(day['meals']).map(_map).toList();
              final eaten = meals
                  .where((meal) => meal['is_eaten'] == true)
                  .length;
              final date = _dateForPlanDay(day);
              return GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 138,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.green.withValues(
                            alpha: _isDark(context) ? .22 : .13,
                          )
                        : _panelColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppColors.green : _lineColor(context),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.green
                                  : _surfaceColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: _lineColor(context)),
                            ),
                            child: Text(
                              '${day['day'] ?? index + 1}',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : _textColor(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: selected
                                ? AppColors.deepGreen
                                : _mutedColor(context),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Day ${day['day'] ?? index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatPlanDate(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 11.5,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$eaten/${meals.length} meals eaten',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.deepGreen
                              : _mutedColor(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MealPlanSelectedDayView extends StatelessWidget {
  const MealPlanSelectedDayView({
    required this.day,
    required this.date,
    required this.onRegenerateMeal,
    required this.onToggleEaten,
    required this.onOpenMeal,
    super.key,
  });

  final Map<String, dynamic> day;
  final DateTime date;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)
  onRegenerateMeal;
  final void Function(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
    bool eaten,
  )
  onToggleEaten;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)
  onOpenMeal;

  @override
  Widget build(BuildContext context) {
    final meals = _list(day['meals']).map(_map).toList();
    final calories = meals.fold<num>(
      0,
      (total, meal) => total + _num(meal['calories']),
    );
    final protein = meals.fold<num>(
      0,
      (total, meal) => total + _num(meal['protein']),
    );
    final carbs = meals.fold<num>(
      0,
      (total, meal) => total + _num(meal['carbs']),
    );
    final fat = meals.fold<num>(0, (total, meal) => total + _num(meal['fat']));
    final eaten = meals.where((meal) => meal['is_eaten'] == true).length;
    return AiResultCard(
      title: 'Day ${day['day'] ?? ''} · ${_formatPlanDate(date)}',
      children: [
        Text(
          '$eaten of ${meals.length} meals completed',
          style: TextStyle(
            color: _mutedColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MealFactChip(
              label: '${calories.round()} kcal',
              color: AppColors.orange,
            ),
            _MealFactChip(
              label: 'P ${protein.round()}g',
              color: AppColors.green,
            ),
            _MealFactChip(
              label: 'C ${carbs.round()}g',
              color: AppColors.yellow,
            ),
            _MealFactChip(label: 'F ${fat.round()}g', color: AppColors.violet),
          ],
        ),
        const SizedBox(height: 12),
        for (final meal in meals)
          MealPlanMealCard(
            day: day,
            meal: meal,
            onRegenerateMeal: onRegenerateMeal,
            onToggleEaten: onToggleEaten,
            onOpenMeal: onOpenMeal,
          ),
      ],
    );
  }
}

class MealPlanMealCard extends StatelessWidget {
  const MealPlanMealCard({
    required this.day,
    required this.meal,
    required this.onRegenerateMeal,
    required this.onToggleEaten,
    required this.onOpenMeal,
    super.key,
  });

  final Map<String, dynamic> day;
  final Map<String, dynamic> meal;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)
  onRegenerateMeal;
  final void Function(
    Map<String, dynamic> day,
    Map<String, dynamic> meal,
    bool eaten,
  )
  onToggleEaten;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)
  onOpenMeal;

  @override
  Widget build(BuildContext context) {
    final eaten = meal['is_eaten'] == true;
    final ingredients = _list(meal['ingredients']).map(_map).toList();
    final preview = ingredients
        .take(3)
        .map((item) => _stringValue(item['name'], ''))
        .where((item) => item.isNotEmpty)
        .join(', ');
    return GestureDetector(
      onTap: () => onOpenMeal(day, meal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: eaten
              ? AppColors.green.withValues(alpha: _isDark(context) ? .18 : .09)
              : _surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: eaten ? AppColors.green : _lineColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: eaten
                        ? AppColors.green
                        : AppColors.green.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    eaten ? Icons.check_rounded : Icons.restaurant_rounded,
                    color: eaten ? Colors.white : AppColors.deepGreen,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleCaseChoice(
                          _stringValue(meal['meal_type'], 'Meal'),
                        ),
                        style: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _stringValue(meal['name'], 'Meal'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: eaten
                        ? AppColors.green.withValues(alpha: .16)
                        : _panelColor(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    eaten ? 'Eaten' : 'Planned',
                    style: TextStyle(
                      color: eaten ? AppColors.deepGreen : _mutedColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_num(meal['calories']).round()} kcal · P ${_num(meal['protein']).round()}g · C ${_num(meal['carbs']).round()}g · F ${_num(meal['fat']).round()}g',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Ingredients: $preview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _mutedColor(context), fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onToggleEaten(day, meal, !eaten),
                    icon: Icon(
                      eaten
                          ? Icons.remove_done_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(eaten ? 'Unmark' : 'Mark eaten'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => onOpenMeal(day, meal),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('View'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MealPlanMealDetailsSheet extends StatelessWidget {
  const MealPlanMealDetailsSheet({
    required this.day,
    required this.meal,
    required this.date,
    required this.onToggleEaten,
    required this.onRegenerate,
    super.key,
  });

  final Map<String, dynamic> day;
  final Map<String, dynamic> meal;
  final DateTime date;
  final Future<void> Function(bool eaten) onToggleEaten;
  final Future<void> Function() onRegenerate;

  @override
  Widget build(BuildContext context) {
    final eaten = meal['is_eaten'] == true;
    final ingredients = _list(meal['ingredients']).map(_map).toList();
    final instructions = _instructionsForMeal(meal);
    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .45,
      maxChildSize: .92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _lineColor(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _titleCaseChoice(_stringValue(meal['meal_type'], 'Meal')),
                style: TextStyle(
                  color: _mutedColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stringValue(meal['name'], 'Meal'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Day ${day['day'] ?? ''} · ${_formatPlanDate(date)}',
                style: TextStyle(color: _mutedColor(context), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MealFactChip(
                    label: '${_num(meal['calories']).round()} kcal',
                    color: AppColors.orange,
                  ),
                  _MealFactChip(
                    label: 'P ${_num(meal['protein']).round()}g',
                    color: AppColors.green,
                  ),
                  _MealFactChip(
                    label: 'C ${_num(meal['carbs']).round()}g',
                    color: AppColors.yellow,
                  ),
                  _MealFactChip(
                    label: 'F ${_num(meal['fat']).round()}g',
                    color: AppColors.violet,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingredients',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (ingredients.isEmpty)
                Text(
                  'No ingredients listed.',
                  style: TextStyle(color: _mutedColor(context)),
                )
              else
                for (final ingredient in ingredients)
                  BulletText(_formatIngredientLine(ingredient)),
              const SizedBox(height: 14),
              const Text(
                'Instructions',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (instructions.isEmpty)
                Text(
                  'No instructions listed.',
                  style: TextStyle(color: _mutedColor(context)),
                )
              else
                for (final instruction in instructions) BulletText(instruction),
              const SizedBox(height: 14),
              const Text(
                'Nutrition Facts',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              MealNutritionGrid(meal: meal),
              if (_stringValue(meal['why_this_fits'], '').isNotEmpty ||
                  _stringValue(meal['whyThisMealFits'], '').isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Why this fits',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  _stringValue(
                    meal['why_this_fits'],
                    _stringValue(meal['whyThisMealFits'], ''),
                  ),
                  style: TextStyle(color: _mutedColor(context), height: 1.35),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: eaten ? 'Unmark eaten' : 'Mark as eaten',
                compact: true,
                onPressed: () async => onToggleEaten(!eaten),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRegenerate,
                icon: const Icon(Icons.autorenew_rounded),
                label: const Text('Regenerate this meal'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MealNutritionGrid extends StatelessWidget {
  const MealNutritionGrid({required this.meal, super.key});

  final Map<String, dynamic> meal;

  @override
  Widget build(BuildContext context) {
    final facts = [
      ('Calories', meal['calories'], 'kcal'),
      ('Protein', meal['protein'], 'g'),
      ('Carbs', meal['carbs'], 'g'),
      ('Fat', meal['fat'], 'g'),
      ('Fiber', meal['fiber'], 'g'),
      ('Sugar', meal['sugar'], 'g'),
      ('Sodium', meal['sodium'], 'mg'),
      ('Potassium', meal['potassium'], 'mg'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fact in facts)
          Container(
            width: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _panelColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _lineColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.$1,
                  style: TextStyle(color: _mutedColor(context), fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_num(fact.$2).round()} ${fact.$3}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({required this.initialList, super.key});

  final Map<String, dynamic> initialList;

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Grocery List',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GroceryListView(
              list: widget.initialList,
              checkedItems: _checked,
              onToggle: (key, checked) => setState(
                () => checked ? _checked.add(key) : _checked.remove(key),
              ),
              onCopyText: () => _copyGrocery(jsonMode: false),
              onCopyJson: () => _copyGrocery(jsonMode: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyGrocery({required bool jsonMode}) async {
    final text = jsonMode
        ? const JsonEncoder.withIndent('  ').convert(widget.initialList)
        : _stringValue(
            widget.initialList['export_text'],
            _groceryText(widget.initialList),
          );
    await Clipboard.setData(ClipboardData(text: text));
  }
}

class WizardProgress extends StatelessWidget {
  const WizardProgress({required this.step, super.key});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          WizardStepDot(index: i, currentStep: step),
          if (i != 3) Expanded(child: WizardStepConnector(completed: i < step)),
        ],
      ],
    );
  }
}

class WizardStepDot extends StatelessWidget {
  const WizardStepDot({
    required this.index,
    required this.currentStep,
    super.key,
  });

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final completed = index < currentStep;
    final active = index == currentStep;
    final color = completed || active ? AppColors.green : _lineColor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 34 : 30,
      height: active ? 34 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: completed || active ? AppColors.green : _panelColor(context),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: active ? 2 : 1),
      ),
      child: completed
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: active ? Colors.white : _mutedColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class WizardStepConnector extends StatelessWidget {
  const WizardStepConnector({required this.completed, super.key});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.green.withValues(alpha: .75)
            : _lineColor(context),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class CurrentGoalMiniCard extends StatelessWidget {
  const CurrentGoalMiniCard({required this.goals, this.onEdit, super.key});

  final Map<String, dynamic> goals;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final planName = _stringValue(goals['plan_name'], 'Current goal');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Goal',
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  planName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: const Text(
                'Edit Goal',
                style: TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TargetSummaryGrid extends StatelessWidget {
  const TargetSummaryGrid({required this.goals, super.key});
  final Map<String, dynamic> goals;
  @override
  Widget build(BuildContext context) {
    final items = const [
      (
        'Calories Target',
        'calories',
        'kcal',
        Icons.local_fire_department_rounded,
      ),
      ('Protein Target', 'protein', 'g', Icons.paid_rounded),
      ('Carbs Target', 'carbs', 'g', Icons.grain_rounded),
      ('Fat Target', 'fat', 'g', Icons.water_drop_rounded),
      ('Fiber Target', 'fiber', 'g', Icons.spa_rounded),
      ('Sugar Target', 'sugar', 'g', Icons.shield_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(items[i].$4, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i].$1,
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${_num(goals[items[i].$2]).round()} ${items[i].$3}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Divider(height: 1, color: _lineColor(context)),
          ],
        ],
      ),
    );
  }
}

class NumberChoiceRow extends StatelessWidget {
  const NumberChoiceRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    super.key,
  });
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return AssistantChoiceRow(
      label: label,
      value: '$value',
      values: [for (final item in values) '$item'],
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
    );
  }
}

class DropdownNumberRow extends StatelessWidget {
  const DropdownNumberRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: values.contains(value) ? value : values.first,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: _panelColor(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: _lineColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: _lineColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.4,
                ),
              ),
            ),
            items: [
              for (final item in values)
                DropdownMenuItem<int>(
                  value: item,
                  child: Text(
                    '$item',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class ReviewLine extends StatelessWidget {
  const ReviewLine({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _mutedColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class FitnessScreen extends StatelessWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      children: [
        const Text(
          'Fitness',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Plan training, estimate effort, and connect activity to your nutrition.',
          style: TextStyle(color: _mutedColor(context), fontSize: 13),
        ),
        const SizedBox(height: 18),
        const FitnessTodayCard(),
        const SizedBox(height: 14),
        const FitnessWeeklyCard(),
        const SizedBox(height: 14),
        const Text(
          'Training tools',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Workout plans',
          subtitle: 'Choose a simple weekly structure for your goal.',
          color: AppColors.green,
          onTap: () => _openFitnessTool(context, const WorkoutPlansScreen()),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.menu_book_rounded,
          title: 'Exercise library',
          subtitle: 'Browse movements, muscles, coaching cues, and swaps.',
          color: AppColors.orange,
          onTap: () => _openFitnessTool(context, const ExerciseLibraryScreen()),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.trending_up_rounded,
          title: 'Strength tracker',
          subtitle: 'Estimate strength from recent working sets.',
          color: AppColors.violet,
          onTap: () => _openFitnessTool(context, const StrengthTrackerScreen()),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.directions_run_rounded,
          title: 'Cardio estimator',
          subtitle: 'Estimate activity calories and training intensity.',
          color: Colors.cyan,
          onTap: () => _openFitnessTool(context, const CardioEstimatorScreen()),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.calculate_rounded,
          title: 'One-rep max',
          subtitle: 'Calculate estimated maxes and useful training loads.',
          color: Colors.redAccent,
          onTap: () => _openFitnessTool(context, const OneRepMaxScreen()),
        ),
        const SizedBox(height: 10),
        FitnessToolCard(
          icon: Icons.battery_charging_full_rounded,
          title: 'Recovery check',
          subtitle:
              'Rate sleep, soreness, and stress for today’s training call.',
          color: AppColors.yellow,
          onTap: () => _openFitnessTool(context, const RecoveryCheckScreen()),
        ),
      ],
    );
  }

  void _openFitnessTool(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class FitnessTodayCard extends StatelessWidget {
  const FitnessTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s workout',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'No workout logged yet. Future activity data can help AI adjust meal and recovery suggestions.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FitnessWeeklyCard extends StatelessWidget {
  const FitnessWeeklyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final days = [
      ('M', true),
      ('T', false),
      ('W', true),
      ('T', false),
      ('F', false),
      ('S', false),
      ('S', false),
    ];
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training week',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the tools below to plan workouts, estimate effort, and build consistency.',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: day.$2
                        ? AppColors.green.withValues(alpha: .16)
                        : _panelColor(context),
                    border: Border.all(
                      color: day.$2 ? AppColors.green : _lineColor(context),
                    ),
                  ),
                  child: Text(
                    day.$1,
                    style: TextStyle(
                      color: day.$2
                          ? AppColors.deepGreen
                          : _mutedColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class FitnessToolCard extends StatelessWidget {
  const FitnessToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: _mutedColor(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _mutedColor(context)),
          ],
        ),
      ),
    );
  }
}

class FitnessToolScreen extends StatelessWidget {
  const FitnessToolScreen({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: _mutedColor(context), height: 1.35),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class WorkoutPlansScreen extends StatelessWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FitnessToolScreen(
      title: 'Workout Plans',
      subtitle: 'Pick a structure that matches your current goal and schedule.',
      children: const [
        WorkoutPlanCard(
          title: '3-Day Strength Foundation',
          focus: 'Build muscle and basic strength',
          days: [
            'Day 1: Squat, bench, row, core',
            'Day 2: Deadlift, overhead press, pulldown',
            'Day 3: Lunge, incline press, row, carries',
          ],
        ),
        SizedBox(height: 12),
        WorkoutPlanCard(
          title: '4-Day Muscle Gain Split',
          focus: 'Upper/lower routine with more weekly volume',
          days: [
            'Upper A: Bench, row, shoulders, arms',
            'Lower A: Squat, hinge, calves, core',
            'Upper B: Incline, pulldown, rear delts, arms',
            'Lower B: Deadlift, split squat, hamstrings',
          ],
        ),
        SizedBox(height: 12),
        WorkoutPlanCard(
          title: 'Fat Loss Conditioning',
          focus: 'Strength plus cardio without burning out',
          days: [
            'Strength full body: 45 min',
            'Zone 2 cardio: 30-40 min',
            'Strength full body: 45 min',
            'Intervals or sport: 20-30 min',
          ],
        ),
      ],
    );
  }
}

class WorkoutPlanCard extends StatelessWidget {
  const WorkoutPlanCard({
    required this.title,
    required this.focus,
    required this.days,
    super.key,
  });

  final String title;
  final String focus;
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            focus,
            style: TextStyle(color: _mutedColor(context), fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final day in days) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(day)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase().trim();
    final exercises = _exerciseLibrary.where((exercise) {
      if (query.isEmpty) return true;
      return exercise.name.toLowerCase().contains(query) ||
          exercise.muscles.toLowerCase().contains(query);
    }).toList();
    return FitnessToolScreen(
      title: 'Exercise Library',
      subtitle: 'Search common movements and use the cues to keep form simple.',
      children: [
        AppTextField(
          controller: _search,
          label: 'Search exercise or muscle',
          useHintText: true,
          hideHintWhenNotEmpty: true,
        ),
        const SizedBox(height: 12),
        for (final exercise in exercises) ...[
          ExerciseLibraryCard(exercise: exercise),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ExerciseLibraryCard extends StatelessWidget {
  const ExerciseLibraryCard({required this.exercise, super.key});

  final ExerciseGuide exercise;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            exercise.muscles,
            style: TextStyle(color: _mutedColor(context), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(exercise.cue),
          const SizedBox(height: 8),
          Text(
            'Swap: ${exercise.swap}',
            style: const TextStyle(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StrengthTrackerScreen extends StatefulWidget {
  const StrengthTrackerScreen({super.key});

  @override
  State<StrengthTrackerScreen> createState() => _StrengthTrackerScreenState();
}

class _StrengthTrackerScreenState extends State<StrengthTrackerScreen> {
  final _exercise = TextEditingController(text: 'Bench press');
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final List<StrengthSetResult> _sets = [];

  @override
  void dispose() {
    _exercise.dispose();
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FitnessToolScreen(
      title: 'Strength Tracker',
      subtitle: 'Add recent working sets to estimate strength trends.',
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppTextField(controller: _exercise, label: 'Exercise'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _weight,
                      label: 'Weight lb',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _reps,
                      label: 'Reps',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Add Set', onPressed: () async => _addSet()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_sets.isEmpty)
          const EmptyMeals(message: 'No strength sets added yet.')
        else
          for (final set in _sets.reversed) ...[
            StrengthSetCard(result: set),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  void _addSet() {
    final weight = num.tryParse(_weight.text.trim());
    final reps = int.tryParse(_reps.text.trim());
    if (weight == null || weight <= 0 || reps == null || reps <= 0) return;
    setState(() {
      _sets.add(
        StrengthSetResult(
          exercise: _exercise.text.trim().isEmpty
              ? 'Strength set'
              : _exercise.text.trim(),
          weight: weight,
          reps: reps,
          oneRepMax: _estimateOneRepMax(weight, reps),
        ),
      );
      _weight.clear();
      _reps.clear();
    });
  }
}

class StrengthSetCard extends StatelessWidget {
  const StrengthSetCard({required this.result, super.key});

  final StrengthSetResult result;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.fitness_center_rounded, color: AppColors.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${result.exercise}\n${_compactNum(result.weight)} lb x ${result.reps}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${_compactNum(result.oneRepMax)} lb\nest. 1RM',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class CardioEstimatorScreen extends StatefulWidget {
  const CardioEstimatorScreen({super.key});

  @override
  State<CardioEstimatorScreen> createState() => _CardioEstimatorScreenState();
}

class _CardioEstimatorScreenState extends State<CardioEstimatorScreen> {
  String _activity = 'Walking';
  String _intensity = 'Moderate';
  final _minutes = TextEditingController();
  final _weight = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = num.tryParse(_minutes.text) ?? 0;
    final weightLb = num.tryParse(_weight.text) ?? 0;
    final calories = _estimateCardioCalories(
      activity: _activity,
      intensity: _intensity,
      minutes: minutes,
      weightLb: weightLb,
    );
    return FitnessToolScreen(
      title: 'Cardio Estimator',
      subtitle:
          'Estimate activity calories. This is useful for context, not a precise burn number.',
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FitnessDropdown(
                label: 'Activity',
                value: _activity,
                options: const [
                  'Walking',
                  'Running',
                  'Cycling',
                  'Tennis',
                  'Rowing',
                ],
                onChanged: (value) => setState(() => _activity = value),
              ),
              const SizedBox(height: 10),
              FitnessDropdown(
                label: 'Intensity',
                value: _intensity,
                options: const ['Easy', 'Moderate', 'Hard'],
                onChanged: (value) => setState(() => _intensity = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _minutes,
                      label: 'Minutes',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _weight,
                      label: 'Weight lb',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FitnessResultCard(
          icon: Icons.local_fire_department_rounded,
          title: '${calories.round()} kcal',
          subtitle: 'Estimated activity calories',
        ),
      ],
    );
  }
}

class OneRepMaxScreen extends StatefulWidget {
  const OneRepMaxScreen({super.key});

  @override
  State<OneRepMaxScreen> createState() => _OneRepMaxScreenState();
}

class _OneRepMaxScreenState extends State<OneRepMaxScreen> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weight = num.tryParse(_weight.text.trim()) ?? 0;
    final reps = int.tryParse(_reps.text.trim()) ?? 0;
    final max = weight > 0 && reps > 0 ? _estimateOneRepMax(weight, reps) : 0;
    return FitnessToolScreen(
      title: 'One-Rep Max',
      subtitle:
          'Estimate your max and common training loads from a working set.',
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _weight,
                  label: 'Weight lb',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: _reps,
                  label: 'Reps',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FitnessResultCard(
          icon: Icons.calculate_rounded,
          title: max > 0 ? '${_compactNum(max)} lb' : '--',
          subtitle: 'Estimated one-rep max',
        ),
        if (max > 0) ...[
          const SizedBox(height: 12),
          FitnessLoadTable(oneRepMax: max),
        ],
      ],
    );
  }
}

class RecoveryCheckScreen extends StatefulWidget {
  const RecoveryCheckScreen({super.key});

  @override
  State<RecoveryCheckScreen> createState() => _RecoveryCheckScreenState();
}

class _RecoveryCheckScreenState extends State<RecoveryCheckScreen> {
  double _sleep = 3;
  double _soreness = 2;
  double _stress = 2;

  @override
  Widget build(BuildContext context) {
    final score = ((_sleep + (6 - _soreness) + (6 - _stress)) / 15 * 100)
        .round();
    final recommendation = score >= 75
        ? 'You look ready for a normal training day.'
        : score >= 55
        ? 'Keep training moderate and prioritize warmups.'
        : 'Consider an easier session, mobility, or a walk today.';
    return FitnessToolScreen(
      title: 'Recovery Check',
      subtitle: 'Quickly rate readiness before choosing today’s training.',
      children: [
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FitnessSlider(
                label: 'Sleep quality',
                value: _sleep,
                onChanged: (value) => setState(() => _sleep = value),
              ),
              FitnessSlider(
                label: 'Soreness',
                value: _soreness,
                onChanged: (value) => setState(() => _soreness = value),
              ),
              FitnessSlider(
                label: 'Stress',
                value: _stress,
                onChanged: (value) => setState(() => _stress = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FitnessResultCard(
          icon: Icons.battery_charging_full_rounded,
          title: '$score%',
          subtitle: recommendation,
        ),
      ],
    );
  }
}

class FitnessDropdown extends StatelessWidget {
  const FitnessDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _panelColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class FitnessResultCard extends StatelessWidget {
  const FitnessResultCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: _mutedColor(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FitnessLoadTable extends StatelessWidget {
  const FitnessLoadTable({required this.oneRepMax, super.key});

  final num oneRepMax;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('90%', oneRepMax * .9, 'Heavy singles/triples'),
      ('80%', oneRepMax * .8, 'Strength work'),
      ('70%', oneRepMax * .7, 'Volume work'),
      ('60%', oneRepMax * .6, 'Technique/warmups'),
    ];
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    row.$1,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(child: Text(row.$3)),
                Text('${_compactNum(row.$2)} lb'),
              ],
            ),
            if (row != rows.last) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class FitnessSlider extends StatelessWidget {
  const FitnessSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text('${value.round()}/5'),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppColors.green,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class ExerciseGuide {
  const ExerciseGuide({
    required this.name,
    required this.muscles,
    required this.cue,
    required this.swap,
  });

  final String name;
  final String muscles;
  final String cue;
  final String swap;
}

class StrengthSetResult {
  const StrengthSetResult({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.oneRepMax,
  });

  final String exercise;
  final num weight;
  final int reps;
  final num oneRepMax;
}

const _exerciseLibrary = [
  ExerciseGuide(
    name: 'Squat',
    muscles: 'Quads, glutes, core',
    cue: 'Brace, keep the midfoot planted, and drive up through the floor.',
    swap: 'Leg press or goblet squat',
  ),
  ExerciseGuide(
    name: 'Deadlift',
    muscles: 'Hamstrings, glutes, back',
    cue: 'Keep the bar close, brace hard, and push the floor away.',
    swap: 'Romanian deadlift or trap-bar deadlift',
  ),
  ExerciseGuide(
    name: 'Bench Press',
    muscles: 'Chest, triceps, shoulders',
    cue: 'Set your upper back, control the lowering, then press smoothly.',
    swap: 'Dumbbell press or push-up',
  ),
  ExerciseGuide(
    name: 'Row',
    muscles: 'Back, biceps, rear delts',
    cue: 'Pull elbows toward your hips and avoid shrugging.',
    swap: 'Cable row or chest-supported row',
  ),
  ExerciseGuide(
    name: 'Overhead Press',
    muscles: 'Shoulders, triceps, core',
    cue: 'Squeeze glutes, brace ribs down, and press in a straight path.',
    swap: 'Dumbbell shoulder press',
  ),
  ExerciseGuide(
    name: 'Lunge',
    muscles: 'Quads, glutes, balance',
    cue: 'Step far enough to keep the front foot planted and torso controlled.',
    swap: 'Split squat or step-up',
  ),
];

num _estimateOneRepMax(num weight, int reps) {
  if (reps <= 1) return weight;
  return weight * (1 + reps / 30);
}

num _estimateCardioCalories({
  required String activity,
  required String intensity,
  required num minutes,
  required num weightLb,
}) {
  if (minutes <= 0 || weightLb <= 0) return 0;
  final weightKg = weightLb * 0.45359237;
  final baseMet = switch (activity) {
    'Running' => 8.5,
    'Cycling' => 6.8,
    'Tennis' => 7.0,
    'Rowing' => 7.0,
    _ => 3.5,
  };
  final multiplier = switch (intensity) {
    'Easy' => .82,
    'Hard' => 1.25,
    _ => 1.0,
  };
  return baseMet * multiplier * 3.5 * weightKg / 200 * minutes;
}

class AiMessageBubble extends StatelessWidget {
  const AiMessageBubble({required this.message, required this.mine, super.key});

  final Map<String, dynamic> message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 292),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(colors: [AppColors.lime, AppColors.green])
            : null,
        color: mine ? null : _surfaceColor(context),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
        border: Border.all(color: mine ? AppColors.green : _lineColor(context)),
        boxShadow: [
          BoxShadow(
            color: _isDark(context)
                ? const Color(0x22000000)
                : const Color(0x08000000),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: mine ? Colors.white : _textColor(context),
            fontSize: 14,
            height: 1.35,
            fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
          ),
          children: _chatMessageSpans(
            '${message['content'] ?? ''}',
            baseColor: mine ? Colors.white : _textColor(context),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.lime, AppColors.deepGreen],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

List<TextSpan> _chatMessageSpans(String text, {required Color baseColor}) {
  final cleaned = text
      .replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '• ');
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final match in pattern.allMatches(cleaned)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: cleaned.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1) ?? '',
        style: TextStyle(color: baseColor, fontWeight: FontWeight.w900),
      ),
    );
    cursor = match.end;
  }
  if (cursor < cleaned.length) {
    spans.add(TextSpan(text: cleaned.substring(cursor)));
  }
  return spans.isEmpty ? [TextSpan(text: cleaned)] : spans;
}

class AiResultCard extends StatelessWidget {
  const AiResultCard({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class BulletText extends StatelessWidget {
  const BulletText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.green),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stringValue(data['title'], 'Suggestion'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(_stringValue(data['reason'], '')),
          if (_stringValue(data['example'], '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _stringValue(data['example'], ''),
              style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class SwapTile extends StatelessWidget {
  const SwapTile({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final diff = _map(data['estimated_difference']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stringValue(data['type'], 'Swap'),
            style: const TextStyle(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _stringValue(data['suggestion'], ''),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(_stringValue(data['why'], '')),
          const SizedBox(height: 6),
          Text(
            diff.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('  '),
            style: TextStyle(color: _mutedColor(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AssistantChoiceRow extends StatelessWidget {
  const AssistantChoiceRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final hasLongLabel = values.any((value) => value.length > 11);
              final columns = values.length <= 3 && !compact && !hasLongLabel
                  ? values.length
                  : 2;
              final spacing = 8.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in values)
                    SizedBox(
                      width: itemWidth,
                      child: AssistantChoiceTile(
                        label: item,
                        selected: item == value,
                        onTap: () => onChanged(item),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AssistantChoiceTile extends StatelessWidget {
  const AssistantChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withValues(
                    alpha: _isDark(context) ? .22 : .12,
                  )
                : _panelColor(context),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.green : _lineColor(context),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.green : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.green
                            : _mutedColor(context),
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _titleCaseChoice(label),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.deepGreen : _textColor(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
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

String _titleCaseChoice(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class PreferenceActionButton extends StatelessWidget {
  const PreferenceActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size.fromHeight(44),
          shape: shape,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size.fromHeight(44),
        shape: shape,
      ),
      child: child,
    );
  }
}

class AssistantNumberRow extends StatelessWidget {
  const AssistantNumberRow({
    required this.days,
    required this.meals,
    required this.household,
    super.key,
  });

  final TextEditingController days;
  final TextEditingController meals;
  final TextEditingController household;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PlanNumberField(
              controller: days,
              label: 'Days',
              icon: Icons.calendar_today_rounded,
            ),
          ),
          Container(width: 1, height: 54, color: _lineColor(context)),
          Expanded(
            child: PlanNumberField(
              controller: meals,
              label: 'Meals/day',
              icon: Icons.restaurant_rounded,
            ),
          ),
          Container(width: 1, height: 54, color: _lineColor(context)),
          Expanded(
            child: PlanNumberField(
              controller: household,
              label: 'People',
              icon: Icons.groups_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class PlanNumberField extends StatelessWidget {
  const PlanNumberField({
    required this.controller,
    required this.label,
    required this.icon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.green),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PlanStepHeader extends StatelessWidget {
  const PlanStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MealPlannerGuideCard extends StatelessWidget {
  const MealPlannerGuideCard({
    required this.stateLabel,
    required this.savedCount,
    super.key,
  });

  final String stateLabel;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stateLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      savedCount > 0
                          ? '$savedCount saved plan${savedCount == 1 ? '' : 's'} available.'
                          : 'Create your first plan, then generate a grocery list.',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: PlannerStepPill(label: 'Preferences', step: '1'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: PlannerStepPill(label: 'Settings', step: '2'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: PlannerStepPill(label: 'Plan', step: '3'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlannerStepPill extends StatelessWidget {
  const PlannerStepPill({required this.label, required this.step, super.key});

  final String label;
  final String step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class CurrentMealPlanActions extends StatelessWidget {
  const CurrentMealPlanActions({
    required this.editing,
    required this.onEdit,
    required this.onNew,
    super.key,
  });

  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Saved plan selected' : 'New plan ready',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Edit the settings, create another version, or generate groceries below.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit plan',
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New plan',
          ),
        ],
      ),
    );
  }
}

class SavedMealPlansSection extends StatelessWidget {
  const SavedMealPlansSection({
    required this.plans,
    required this.selectedId,
    required this.groceryLoadingId,
    required this.onOpen,
    required this.onEdit,
    required this.onGrocery,
    required this.onDelete,
    required this.onCreate,
    super.key,
  });

  final List<Map<String, dynamic>> plans;
  final String? selectedId;
  final String? groceryLoadingId;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onGrocery;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved Meal Plans',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Open a saved plan, edit its settings, or create a fresh version.',
            style: TextStyle(color: _mutedColor(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final planRow in plans.take(5)) ...[
            SavedMealPlanTile(
              row: planRow,
              selected: '${planRow['id']}' == selectedId,
              groceryLoading: '${planRow['id']}' == groceryLoadingId,
              onOpen: () => onOpen(planRow),
              onEdit: () => onEdit(planRow),
              onGrocery: () => onGrocery(planRow),
              onDelete: () => onDelete(planRow),
            ),
            if (planRow != plans.take(5).last)
              const Divider(height: 18, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class SavedMealPlanTile extends StatelessWidget {
  const SavedMealPlanTile({
    required this.row,
    required this.selected,
    required this.groceryLoading,
    required this.onOpen,
    required this.onEdit,
    required this.onGrocery,
    required this.onDelete,
    super.key,
  });

  final Map<String, dynamic> row;
  final bool selected;
  final bool groceryLoading;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onGrocery;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final plan = _map(row['plan']);
    final days = _num(row['days'], fallback: _num(plan['days'], fallback: 1));
    final protein = _num(row['total_protein']);
    final calories = _num(row['total_calories']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.green.withValues(alpha: _isDark(context) ? .18 : .09)
            : _panelColor(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.green : _lineColor(context),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.deepGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stringValue(row['title'], 'AI Meal Plan'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${days.round()} days • ${calories.round()} kcal total • P ${protein.round()}g total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('Open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: groceryLoading ? null : onGrocery,
                icon: groceryLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_basket_rounded),
                tooltip: 'Grocery list',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MealPlanView extends StatelessWidget {
  const MealPlanView({required this.plan, this.onRegenerateMeal, super.key});

  final Map<String, dynamic> plan;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)?
  onRegenerateMeal;

  @override
  Widget build(BuildContext context) {
    return AiResultCard(
      title: _stringValue(plan['title'], 'AI Meal Plan'),
      children: [
        Text(
          '${plan['days'] ?? ''} days • ${plan['meals_per_day'] ?? ''} meals/day • ${plan['household_size'] ?? ''} people',
          style: TextStyle(color: _mutedColor(context), fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final day in _list(plan['days_plan']))
          MealPlanDayTile(day: _map(day), onRegenerateMeal: onRegenerateMeal),
        for (final note in _list(plan['prep_notes'])) BulletText('$note'),
      ],
    );
  }
}

class MealPlanDayTile extends StatelessWidget {
  const MealPlanDayTile({required this.day, this.onRegenerateMeal, super.key});

  final Map<String, dynamic> day;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)?
  onRegenerateMeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day['day'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final meal in _list(day['meals']))
            MealPlanMealTile(
              day: day,
              meal: _map(meal),
              onRegenerateMeal: onRegenerateMeal,
            ),
        ],
      ),
    );
  }
}

class MealPlanMealTile extends StatefulWidget {
  const MealPlanMealTile({
    required this.day,
    required this.meal,
    required this.onRegenerateMeal,
    super.key,
  });

  final Map<String, dynamic> day;
  final Map<String, dynamic> meal;
  final void Function(Map<String, dynamic> day, Map<String, dynamic> meal)?
  onRegenerateMeal;

  @override
  State<MealPlanMealTile> createState() => _MealPlanMealTileState();
}

class _MealPlanMealTileState extends State<MealPlanMealTile> {
  bool _showInstructions = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final ingredients = _list(meal['ingredients']).map(_map).toList();
    final instructions = _list(meal['instructions']);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _lineColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleCaseChoice(_stringValue(meal['meal_type'], 'Meal')),
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _stringValue(meal['name'], 'Meal'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          if (_stringValue(meal['description'], '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              _stringValue(meal['description'], ''),
              style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MealFactChip(
                label: '${_num(meal['calories']).round()} kcal',
                color: AppColors.orange,
              ),
              _MealFactChip(
                label: 'P ${_num(meal['protein']).round()}g',
                color: AppColors.green,
              ),
              _MealFactChip(
                label: 'C ${_num(meal['carbs']).round()}g',
                color: AppColors.yellow,
              ),
              _MealFactChip(
                label: 'F ${_num(meal['fat']).round()}g',
                color: AppColors.violet,
              ),
            ],
          ),
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Ingredients',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            for (final ingredient in ingredients.take(8))
              BulletText(_formatIngredientLine(ingredient)),
          ],
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showInstructions = !_showInstructions),
              icon: Icon(
                _showInstructions
                    ? Icons.expand_less_rounded
                    : Icons.menu_book_rounded,
                size: 18,
              ),
              label: Text(
                _showInstructions ? 'Hide Instructions' : 'Instructions',
              ),
            ),
            if (_showInstructions) ...[
              const SizedBox(height: 6),
              for (final instruction in instructions.take(8))
                BulletText('$instruction'),
            ],
          ],
          if (_stringValue(meal['why_this_fits'], '').isNotEmpty ||
              _stringValue(meal['whyThisMealFits'], '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _stringValue(
                meal['why_this_fits'],
                _stringValue(meal['whyThisMealFits'], ''),
              ),
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.onRegenerateMeal != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => widget.onRegenerateMeal!(widget.day, meal),
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text('Regenerate Meal'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealFactChip extends StatelessWidget {
  const _MealFactChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark(context) ? .18 : .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _textColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class GroceryListView extends StatelessWidget {
  const GroceryListView({
    required this.list,
    required this.checkedItems,
    required this.onToggle,
    required this.onCopyText,
    required this.onCopyJson,
    super.key,
  });

  final Map<String, dynamic> list;
  final Set<String> checkedItems;
  final void Function(String key, bool checked) onToggle;
  final Future<void> Function() onCopyText;
  final Future<void> Function() onCopyJson;

  @override
  Widget build(BuildContext context) {
    final items = _list(list['items']).map(_map).toList();
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      categories
          .putIfAbsent(_stringValue(item['category'], 'Other'), () => [])
          .add(item);
    }
    return AiResultCard(
      title: _stringValue(list['title'], 'Grocery List'),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopyText,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy text'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopyJson,
                icon: const Icon(Icons.data_object_rounded),
                label: const Text('Copy JSON'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in categories.entries) ...[
          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final item in entry.value)
            GroceryCheckItem(
              item: item,
              checked: checkedItems.contains(_groceryItemKey(item)),
              onChanged: (checked) => onToggle(_groceryItemKey(item), checked),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class GroceryCheckItem extends StatelessWidget {
  const GroceryCheckItem({
    required this.item,
    required this.checked,
    required this.onChanged,
    super.key,
  });

  final Map<String, dynamic> item;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label =
        '${item['name']} - ${_formatFactValue(_num(item['quantity']))} ${item['unit'] ?? ''}';
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              activeColor: AppColors.deepGreen,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: checked ? _mutedColor(context) : _textColor(context),
                  decoration: checked ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreferenceSummary extends StatelessWidget {
  const PreferenceSummary({required this.preferences, super.key});

  final Map<String, dynamic> preferences;

  @override
  Widget build(BuildContext context) {
    return AiResultCard(
      title: 'Saved Preferences',
      children: [
        Text('Likes: ${_list(preferences['liked_foods']).join(', ')}'),
        const SizedBox(height: 8),
        Text('Dislikes: ${_list(preferences['disliked_foods']).join(', ')}'),
      ],
    );
  }
}

class AnalyzingMealIndicator extends StatefulWidget {
  const AnalyzingMealIndicator({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  State<AnalyzingMealIndicator> createState() => _AnalyzingMealIndicatorState();
}

class _AnalyzingMealIndicatorState extends State<AnalyzingMealIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.compact ? 48 : 64,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 14,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              width: widget.compact ? 28 : 36,
              height: widget.compact ? 28 : 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.lime, AppColors.deepGreen],
                ),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.compact ? 16 : 20,
              ),
            ),
          ),
          SizedBox(width: widget.compact ? 8 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!widget.compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.history,
    required this.goals,
    required this.repo,
    required this.onRefresh,
    this.showBackButton = false,
    super.key,
  });

  final Map<String, dynamic>? history;
  final Map<String, dynamic>? goals;
  final NutritionRepository repo;
  final Future<void> Function() onRefresh;
  final bool showBackButton;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _metric;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final series = _list(widget.history?['series']).map(_map).toList();
    final averages = _trackedDayAverages(series);
    final goals = _map(widget.goals);
    final selectedMetric = _metric == null ? null : _historyMetric(_metric!);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
              ],
              const Expanded(
                child: Text(
                  'History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a day to review meals and nutrition totals.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Goal Calendar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                HistoryFilterBar(
                  selectedMetric: _metric,
                  onSelected: (key) => setState(() => _metric = key),
                ),
                const SizedBox(height: 10),
                HistoryLegend(metric: selectedMetric),
                const SizedBox(height: 16),
                HistoryMonthHeader(
                  month: _visibleMonth,
                  onPrevious: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  onNext: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                ),
                const SizedBox(height: 12),
                HistoryCalendarGrid(
                  series: series,
                  goals: goals,
                  metric: selectedMetric,
                  visibleMonth: _visibleMonth,
                  onDaySelected: _openDay,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatBlock(
                  label: 'Avg calories',
                  value: _num(averages['calories']).round().toString(),
                ),
                StatBlock(
                  label: 'Protein',
                  value: '${_num(averages['protein']).round()}g',
                ),
                StatBlock(
                  label: 'Carbs',
                  value: '${_num(averages['carbs']).round()}g',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDay(Map<String, dynamic> day) async {
    final date = DateTime.tryParse('${day['log_date']}');
    if (date == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HistoryDayScreen(
          date: date,
          repo: widget.repo,
          goals: _map(widget.goals),
        ),
      ),
    );
    if (changed == true) await widget.onRefresh();
  }
}

class HistoryCalendarGrid extends StatelessWidget {
  const HistoryCalendarGrid({
    required this.series,
    required this.goals,
    required this.metric,
    required this.visibleMonth,
    required this.onDaySelected,
    super.key,
  });

  final List<Map<String, dynamic>> series;
  final Map<String, dynamic> goals;
  final HistoryMetric? metric;
  final DateTime visibleMonth;
  final ValueChanged<Map<String, dynamic>> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final daysByDate = {
      for (final day in series)
        if (DateTime.tryParse('${day['log_date']}') case final date?)
          _dateKey(date): day,
    };
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final leadingDays = monthStart.weekday % 7;
    final gridStart = monthStart.subtract(Duration(days: leadingDays));
    final cells = [
      for (int i = 0; i < 42; i++) gridStart.add(Duration(days: i)),
    ];

    return Column(
      children: [
        const Row(
          children: [
            CalendarWeekday('S'),
            CalendarWeekday('M'),
            CalendarWeekday('T'),
            CalendarWeekday('W'),
            CalendarWeekday('T'),
            CalendarWeekday('F'),
            CalendarWeekday('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: cells.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final date = cells[index];
            final day =
                daysByDate[_dateKey(date)] ?? {'log_date': _dateKey(date)};
            final isCurrentMonth =
                date.year == visibleMonth.year &&
                date.month == visibleMonth.month;
            final statusColor = _historyStatusColor(day, goals, metric);
            final noEntry = statusColor == AppColors.line;
            final cellFill = noEntry
                ? _panelColor(
                    context,
                  ).withValues(alpha: isCurrentMonth ? 1 : .35)
                : statusColor.withValues(
                    alpha: _isDark(context)
                        ? (isCurrentMonth ? .24 : .08)
                        : (isCurrentMonth ? .13 : .05),
                  );
            final cellBorder = noEntry
                ? _lineColor(
                    context,
                  ).withValues(alpha: isCurrentMonth ? 1 : .35)
                : statusColor.withValues(
                    alpha: _isDark(context)
                        ? (isCurrentMonth ? .8 : .25)
                        : (isCurrentMonth ? .5 : .15),
                  );
            return GestureDetector(
              onTap: () => onDaySelected(day),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cellFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cellBorder),
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isCurrentMonth
                        ? (noEntry ? _mutedColor(context) : _textColor(context))
                        : _mutedColor(context).withValues(alpha: .45),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class HistoryFilterBar extends StatelessWidget {
  const HistoryFilterBar({
    required this.selectedMetric,
    required this.onSelected,
    super.key,
  });

  final String? selectedMetric;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final options = <_HistoryFilterOption>[
      const _HistoryFilterOption(
        key: null,
        label: 'Tracked',
        icon: Icons.check_circle_rounded,
        color: AppColors.green,
      ),
      for (final metric in _historyMetrics)
        _HistoryFilterOption(
          key: metric.key,
          label: metric.label,
          icon: _historyFilterIcon(metric.key),
          color: metric.color,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF101214).withValues(alpha: .62)
            : const Color(0xFFFBFCFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            for (var index = 0; index < options.length; index++) ...[
              _HistoryFilterButton(
                option: options[index],
                selected: selectedMetric == options[index].key,
                onTap: () {
                  final key = options[index].key;
                  onSelected(selectedMetric == key ? null : key);
                },
              ),
              if (index != options.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class HistoryLegend extends StatelessWidget {
  const HistoryLegend({required this.metric, super.key});

  final HistoryMetric? metric;

  @override
  Widget build(BuildContext context) {
    final items = metric == null
        ? const [
            _HistoryLegendItem(color: AppColors.green, label: 'Tracked'),
            _HistoryLegendItem(color: AppColors.line, label: 'No entries'),
          ]
        : _historyLegendItems(metric!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelColor(
          context,
        ).withValues(alpha: _isDark(context) ? .7 : 1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineColor(context)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              HistoryLegendPill(
                color: items[index].color,
                label: items[index].label,
              ),
              if (index != items.length - 1) const SizedBox(width: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryLegendItem {
  const _HistoryLegendItem({required this.color, required this.label});

  final Color color;
  final String label;
}

class HistoryLegendPill extends StatelessWidget {
  const HistoryLegendPill({
    required this.color,
    required this.label,
    super.key,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isEmpty = color == AppColors.line;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: isEmpty ? _mutedColor(context) : color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: _textColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HistoryFilterButton extends StatelessWidget {
  const _HistoryFilterButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _HistoryFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final isTracked = option.key == null;
    final fill = selected
        ? option.color
        : option.color.withValues(alpha: dark ? .12 : .08);
    final border = selected
        ? option.color.withValues(alpha: dark ? .9 : .78)
        : _lineColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: isTracked ? 78 : 68,
          height: 86,
          padding: const EdgeInsets.fromLTRB(7, 8, 7, 9),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: border, width: selected ? 1.2 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: option.color.withValues(alpha: dark ? .2 : .18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: isTracked ? 44 : 40,
                height: isTracked ? 44 : 40,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: isTracked ? .18 : .92)
                      : _surfaceColor(context),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: .18)
                        : option.color.withValues(alpha: dark ? .2 : .18),
                  ),
                ),
                child: Icon(
                  option.icon,
                  color: selected
                      ? (isTracked ? Colors.white : option.color)
                      : option.color,
                  size: isTracked ? 23 : 21,
                ),
              ),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : dark
                      ? _textColor(context)
                      : AppColors.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryFilterOption {
  const _HistoryFilterOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String? key;
  final String label;
  final IconData icon;
  final Color color;
}

IconData _historyFilterIcon(String key) {
  switch (key) {
    case 'protein':
      return Icons.fitness_center_rounded;
    case 'carbs':
      return Icons.grain_rounded;
    case 'fat':
      return Icons.water_drop_rounded;
    case 'fiber':
      return Icons.spa_rounded;
    case 'sugar':
      return Icons.cookie_rounded;
    default:
      return Icons.tune_rounded;
  }
}

class HistoryMonthHeader extends StatelessWidget {
  const HistoryMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _formatHistoryMonth(month),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ),
        RoundIconButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        const SizedBox(width: 8),
        RoundIconButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class CalendarWeekday extends StatelessWidget {
  const CalendarWeekday(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ).copyWith(color: _mutedColor(context)),
        ),
      ),
    );
  }
}

class HistoryDayScreen extends StatefulWidget {
  const HistoryDayScreen({
    required this.date,
    required this.repo,
    required this.goals,
    super.key,
  });

  final DateTime date;
  final NutritionRepository repo;
  final Map<String, dynamic> goals;

  @override
  State<HistoryDayScreen> createState() => _HistoryDayScreenState();
}

class _HistoryDayScreenState extends State<HistoryDayScreen> {
  late Future<Map<String, dynamic>> _dashboard;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _dashboard = widget.repo.dashboard(widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboard,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorState(
                  error: snapshot.error.toString(),
                  onRetry: _reload,
                );
              }

              final dashboard = snapshot.data ?? {};
              final totals = _map(dashboard['totals']);
              final goals = _map(dashboard['goals']).isEmpty
                  ? widget.goals
                  : _map(dashboard['goals']);
              final meals = _list(dashboard['meals']).map(_map).toList();
              final isToday = _dateKey(widget.date) == _dateKey(DateTime.now());
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(_changed),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatHistoryDate(widget.date),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${meals.length} meals logged',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isToday) ...[
                        const SizedBox(width: 10),
                        RoundIconButton(
                          icon: Icons.add_rounded,
                          onTap: _addMealToDay,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        NutritionFactRow(
                          label: 'Calories',
                          value: _num(totals['calories']),
                          goal: _num(goals['calories'], fallback: 2200),
                          keyName: 'calories',
                          goals: goals,
                          unit: 'kcal',
                          color: AppColors.orange,
                          prominent: true,
                        ),
                        const Divider(height: 24, color: AppColors.line),
                        NutritionFactRow(
                          label: 'Protein',
                          value: _num(totals['protein']),
                          goal: _num(goals['protein'], fallback: 150),
                          keyName: 'protein',
                          goals: goals,
                          unit: 'g',
                          color: AppColors.green,
                        ),
                        NutritionFactRow(
                          label: 'Carbs',
                          value: _num(totals['carbs']),
                          goal: _num(goals['carbs'], fallback: 250),
                          keyName: 'carbs',
                          goals: goals,
                          unit: 'g',
                          color: AppColors.yellow,
                        ),
                        NutritionFactRow(
                          label: 'Fat',
                          value: _num(totals['fat']),
                          goal: _num(goals['fat'], fallback: 70),
                          keyName: 'fat',
                          goals: goals,
                          unit: 'g',
                          color: AppColors.violet,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!isToday && meals.isNotEmpty) ...[
                    TodayAiReviewCard(
                      mealCount: meals.length,
                      title: 'AI day review',
                      enabledSubtitle:
                          'Review what could have gone better and get simple suggestions.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DailyMealAnalysisScreen(
                            repo: widget.repo,
                            dashboard: dashboard,
                            goals: goals,
                            reviewDate: widget.date,
                            isTodayReview: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text(
                    'Meals',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: meals.isEmpty
                        ? const EmptyMeals(
                            message: 'No meals have been logged for this day.',
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < meals.length; i++) ...[
                                MealTile(
                                  meal: meals[i],
                                  onTap: () => _openMeal(meals[i], goals),
                                ),
                                if (i != meals.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 70,
                                    color: AppColors.line,
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _dashboard = widget.repo.dashboard(widget.date);
    });
    await _dashboard;
  }

  Future<void> _addMealToDay() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: AddFoodScreen(
              repo: widget.repo,
              logDate: widget.date,
              onDone: () async {
                _changed = true;
                await _reload();
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openMeal(
    Map<String, dynamic> meal,
    Map<String, dynamic> goals,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NutritionFactsScreen.forMeal(
          meal: meal,
          goals: goals,
          repo: widget.repo,
          deleteContext: 'this day',
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _reload();
    }
  }
}

class NutritionTodayDetails extends StatelessWidget {
  const NutritionTodayDetails({
    required this.dashboard,
    required this.goals,
    required this.repo,
    required this.onRefresh,
    super.key,
  });

  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic> goals;
  final NutritionRepository repo;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (dashboard == null) {
      return const SoftCard(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final totals = _map(dashboard?['totals']);
    final dashboardGoals = {...goals, ..._map(dashboard?['goals'])};
    final meals = _sortMealsNewestFirst(_list(dashboard?['meals']).map(_map));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              SectionHeader(
                title: "Today's Nutrition",
                action: 'See all',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NutritionFactsScreen(
                      title: "Today's Nutrition",
                      subtitle: 'All nutrition facts for the day',
                      nutrition: totals,
                      goals: dashboardGoals,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              CompactMacroSummary(totals: totals, goals: dashboardGoals),
              const SizedBox(height: 16),
              MicroProgress(
                label: 'Fiber',
                keyName: 'fiber',
                totals: totals,
                goals: dashboardGoals,
                color: AppColors.green,
              ),
              MicroProgress(
                label: 'Sugar',
                keyName: 'sugar',
                totals: totals,
                goals: dashboardGoals,
                color: AppColors.orange,
              ),
              MicroProgress(
                label: 'Vit. C',
                keyName: 'vitamin_c',
                totals: totals,
                goals: dashboardGoals,
                color: AppColors.yellow,
              ),
              MicroProgress(
                label: 'Iron',
                keyName: 'iron',
                totals: totals,
                goals: dashboardGoals,
                color: AppColors.violet,
              ),
              MicroProgress(
                label: 'Calcium',
                keyName: 'calcium',
                totals: totals,
                goals: dashboardGoals,
                color: Colors.cyan,
              ),
              MicroProgress(
                label: 'Sodium',
                keyName: 'sodium',
                totals: totals,
                goals: dashboardGoals,
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Today's Meals",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${meals.length} logged',
                      style: const TextStyle(
                        color: AppColors.deepGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TodayAiReviewCard(
                mealCount: meals.length,
                onTap: meals.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DailyMealAnalysisScreen(
                            repo: repo,
                            dashboard: dashboard,
                            goals: dashboardGoals,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _panelColor(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _lineColor(context)),
                ),
                child: meals.isEmpty
                    ? const EmptyMeals(
                        message:
                            'No meals logged yet. Tap + to get started by adding food.',
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < meals.length; i++) ...[
                            MealTile(
                              meal: meals[i],
                              onTap: () async {
                                final changed = await Navigator.of(context)
                                    .push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NutritionFactsScreen.forMeal(
                                              meal: meals[i],
                                              goals: dashboardGoals,
                                              repo: repo,
                                              deleteContext: 'today',
                                            ),
                                      ),
                                    );
                                if (changed == true) await onRefresh();
                              },
                            ),
                            if (i != meals.length - 1)
                              Divider(
                                height: 1,
                                indent: 70,
                                color: _lineColor(context),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CompactMacroSummary extends StatelessWidget {
  const CompactMacroSummary({
    required this.totals,
    required this.goals,
    super.key,
  });

  final Map<String, dynamic> totals;
  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final items = [
      _CompactMacroItem(
        label: 'Calories',
        keyName: 'calories',
        value: _num(totals['calories']).round(),
        goal: _num(goals['calories'], fallback: 2200).round(),
        unit: 'kcal',
        color: AppColors.orange,
      ),
      _CompactMacroItem(
        label: 'Protein',
        keyName: 'protein',
        value: _num(totals['protein']).round(),
        goal: _num(goals['protein'], fallback: 150).round(),
        unit: 'g',
        color: AppColors.green,
      ),
      _CompactMacroItem(
        label: 'Carbs',
        keyName: 'carbs',
        value: _num(totals['carbs']).round(),
        goal: _num(goals['carbs'], fallback: 250).round(),
        unit: 'g',
        color: Colors.blueAccent,
      ),
      _CompactMacroItem(
        label: 'Fat',
        keyName: 'fat',
        value: _num(totals['fat']).round(),
        goal: _num(goals['fat'], fallback: 70).round(),
        unit: 'g',
        color: AppColors.violet,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: _CompactMacroTile(item: items[i], goals: goals),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CompactMacroItem {
  const _CompactMacroItem({
    required this.label,
    required this.keyName,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  final String label;
  final String keyName;
  final int value;
  final int goal;
  final String unit;
  final Color color;
}

class _CompactMacroTile extends StatelessWidget {
  const _CompactMacroTile({required this.item, required this.goals});

  final _CompactMacroItem item;
  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final statusColor = _goalStatusColor(
      item.keyName,
      item.value,
      item.goal,
      goals,
    );
    final color = statusColor == AppColors.muted ? item.color : statusColor;
    final definition = _goalDefinition(item.keyName, goals);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark(context) ? .18 : .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${item.value}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '/ ${item.goal}${item.unit} ${definition.shortLabel}',
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.goals,
    required this.dashboard,
    required this.history,
    required this.repo,
    required this.onSaved,
    required this.onRefresh,
    super.key,
  });

  final Map<String, dynamic>? goals;
  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic>? history;
  final NutritionRepository repo;
  final Future<void> Function() onSaved;
  final Future<void> Function() onRefresh;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final isSetup = widget.goals?['setup_completed'] == true;
    final selectedPlanName = widget.goals?['plan_name'] is String
        ? '${widget.goals?['plan_name']}'
        : null;
    final selectedPlan = _selectedGoalPlan(selectedPlanName);
    final goalDefinitions = {..._map(widget.goals)};
    if (selectedPlanName != null) {
      goalDefinitions['plan_name'] = selectedPlanName;
    }
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isSetup ? 'Nutrition' : 'Set Your Nutrition Plan',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (isSetup)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openHistory,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: .16),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.deepGreen,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isSetup
              ? 'Manage food tracking, targets, meal plans, and grocery planning.'
              : 'Start with a simple plan. You can edit every number before saving.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (isSetup) ...[
          NutritionTodayDetails(
            dashboard: widget.dashboard,
            goals: goalDefinitions,
            repo: widget.repo,
            onRefresh: widget.onRefresh,
          ),
          const SizedBox(height: 18),
          AiMealPlanEntryCard(
            planName: selectedPlan?.name ?? selectedPlanName ?? 'Custom plan',
            planDescription:
                selectedPlan?.description ??
                'Your saved daily targets are active.',
            planColor: selectedPlan?.color ?? AppColors.green,
            planIcon: selectedPlan?.icon ?? Icons.tune_rounded,
            onEditPlan: _openEditor,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AiMealPlanScreen(repo: widget.repo, goals: widget.goals),
              ),
            ),
          ),
          const SizedBox(height: 16),
          NutritionActionCard(
            icon: Icons.storefront_rounded,
            title: 'Restaurant Recommendations',
            subtitle: 'Search menus and compare what fits your goals.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RestaurantRecommendationsScreen(
                  repo: widget.repo,
                  goals: goalDefinitions,
                  dashboard: widget.dashboard,
                ),
              ),
            ),
          ),
        ] else ...[
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your details, choose a goal, and review your recommended daily targets.',
                  style: TextStyle(color: _mutedColor(context), fontSize: 13),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Set Up Plan', onPressed: _openEditor),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: HistoryScreen(
              history: widget.history,
              goals: widget.goals,
              repo: widget.repo,
              onRefresh: widget.onRefresh,
              showBackButton: true,
            ),
          ),
        ),
      ),
    );
    await widget.onRefresh();
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(
          goals: widget.goals,
          repo: widget.repo,
          isSetup: widget.goals?['setup_completed'] != true,
        ),
      ),
    );
    if (saved == true) await widget.onSaved();
  }
}

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    required this.goals,
    required this.repo,
    required this.isSetup,
    super.key,
  });

  final Map<String, dynamic>? goals;
  final NutritionRepository repo;
  final bool isSetup;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final Map<String, TextEditingController> _controllers;
  final _age = TextEditingController();
  final _heightInches = TextEditingController();
  final _weightPounds = TextEditingController();
  String? _selectedPlan;
  String _gender = 'female';
  String _activityLevel = 'moderate';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final key in [
        'calories',
        'protein',
        'carbs',
        'fat',
        'fiber',
        'sugar',
        'sodium',
        'potassium',
      ])
        key: TextEditingController(),
    };
    _sync();
    _loadBodyProfile();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _age.dispose();
    _heightInches.dispose();
    _weightPounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalDefinitions = {
      ..._map(widget.goals),
      if (_selectedPlan != null) 'plan_name': _selectedPlan,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isSetup ? 'Set Your Plan' : 'Edit Plan',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Update your personal details, goal, and daily targets.',
                        style: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BodyProfileCard(
              age: _age,
              heightInches: _heightInches,
              weightPounds: _weightPounds,
              gender: _gender,
              activityLevel: _activityLevel,
              onGenderChanged: (value) => setState(() {
                _gender = value;
                _applyRecommendedTargets();
              }),
              onActivityChanged: (value) => setState(() {
                _activityLevel = value;
                _applyRecommendedTargets();
              }),
              onChanged: _applyRecommendedTargets,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a Plan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final plan in _goalPlans)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GoalPlanCard(
                  plan: plan,
                  selected: plan.name == _selectedPlan,
                  onTap: () => _applyPlan(plan),
                ),
              ),
            const SizedBox(height: 8),
            GoalEditorSection(
              title: 'Targets',
              children: [
                GoalInput(
                  controller: _controllers['calories']!,
                  label: _goalInputLabel(
                    'Calories',
                    'calories',
                    goalDefinitions,
                  ),
                  unit: 'kcal',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['protein']!,
                  label: _goalInputLabel('Protein', 'protein', goalDefinitions),
                  unit: 'g',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['carbs']!,
                  label: _goalInputLabel('Carbs', 'carbs', goalDefinitions),
                  unit: 'g',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['fat']!,
                  label: _goalInputLabel('Fat', 'fat', goalDefinitions),
                  unit: 'g',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['fiber']!,
                  label: _goalInputLabel('Fiber', 'fiber', goalDefinitions),
                  unit: 'g',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['sugar']!,
                  label: _goalInputLabel('Sugar', 'sugar', goalDefinitions),
                  unit: 'g',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['sodium']!,
                  label: _goalInputLabel('Sodium', 'sodium', goalDefinitions),
                  unit: 'mg',
                  readOnly: false,
                ),
                GoalInput(
                  controller: _controllers['potassium']!,
                  label: _goalInputLabel(
                    'Potassium',
                    'potassium',
                    goalDefinitions,
                  ),
                  unit: 'mg',
                  readOnly: false,
                ),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: widget.isSetup ? 'Save and start tracking' : 'Save Plan',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _sync() {
    final goals = widget.goals;
    if (goals == null) return;
    for (final entry in _controllers.entries) {
      if (entry.value.text.isEmpty) {
        entry.value.text = _num(goals[entry.key]).round().toString();
      }
    }
    _selectedPlan ??= goals['plan_name'] is String ? goals['plan_name'] : null;
  }

  void _applyPlan(GoalPlan plan) {
    setState(() {
      _selectedPlan = plan.name;
      final values = _recommendedTargets(plan) ?? plan.values;
      for (final entry in values.entries) {
        _controllers[entry.key]?.text = entry.value.round().toString();
      }
    });
  }

  void _applyRecommendedTargets() {
    final selected = _selectedGoalPlan(_selectedPlan);
    if (selected == null) return;
    final values = _recommendedTargets(selected);
    if (values == null) return;
    for (final entry in values.entries) {
      _controllers[entry.key]?.text = entry.value.round().toString();
    }
  }

  Map<String, num>? _recommendedTargets(GoalPlan plan) {
    final age = num.tryParse(_age.text);
    final height = num.tryParse(_heightInches.text);
    final weight = num.tryParse(_weightPounds.text);
    if (age == null || height == null || weight == null) return null;
    return _recommendedTargetsForProfile(
      plan.name,
      age: age,
      heightInches: height,
      weightPounds: weight,
      gender: _gender,
      activityLevel: _activityLevel,
    );
  }

  Future<void> _loadBodyProfile() async {
    try {
      final profile = await widget.repo.assistantProfile(_map(widget.goals));
      if (!mounted) return;
      final age = _num(profile['age']);
      final heightCm = _num(profile['height_cm']);
      final weightKg = _num(profile['weight_kg']);
      if (age > 0 && _age.text.isEmpty) _age.text = age.round().toString();
      if (heightCm > 0 && _heightInches.text.isEmpty) {
        _heightInches.text = (heightCm / 2.54).round().toString();
      }
      if (weightKg > 0 && _weightPounds.text.isEmpty) {
        _weightPounds.text = (weightKg / 0.45359237).round().toString();
      }
      setState(() {
        _gender = '${profile['gender'] ?? _gender}';
        _activityLevel = '${profile['activity_level'] ?? _activityLevel}';
      });
      _applyRecommendedTargets();
    } catch (_) {
      // Goal setup can still work if the optional profile row is not ready yet.
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final values = <String, num>{};
    for (final entry in _controllers.entries) {
      values[entry.key] = num.tryParse(entry.value.text) ?? 0;
    }
    final age = num.tryParse(_age.text);
    final heightInches = num.tryParse(_heightInches.text);
    final weightPounds = num.tryParse(_weightPounds.text);
    final calculated =
        age == null || heightInches == null || weightPounds == null
        ? const <String, num>{}
        : _recommendedTargetsForProfile(
            _selectedPlan ?? 'Maintain weight',
            age: age,
            heightInches: heightInches,
            weightPounds: weightPounds,
            gender: _gender,
            activityLevel: _activityLevel,
          );
    try {
      await widget.repo.updateAssistantProfile({
        'goal_type': _selectedPlan,
        'height_cm': (heightInches ?? 0) * 2.54,
        'weight_kg': (weightPounds ?? 0) * 0.45359237,
        'age': age?.round(),
        'gender': _gender,
        'activity_level': _activityLevel,
        'calorie_target': values['calories'],
        'protein_target': values['protein'],
        'carb_target': values['carbs'],
        'fat_target': values['fat'],
        'fiber_target': values['fiber'],
        'sugar_limit': values['sugar'],
        'sodium_target': values['sodium'],
        'potassium_target': values['potassium'],
        'bmr': calculated['bmr'],
        'tdee': calculated['tdee'],
        'calorie_adjustment_percent': calculated['calorie_adjustment_percent'],
        'calculation_method': 'mifflin_st_jeor',
      });
      await widget.repo.updateGoals(values, planName: _selectedPlan);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class BodyProfileCard extends StatefulWidget {
  const BodyProfileCard({
    required this.age,
    required this.heightInches,
    required this.weightPounds,
    required this.gender,
    required this.activityLevel,
    required this.onGenderChanged,
    required this.onActivityChanged,
    required this.onChanged,
    super.key,
  });

  final TextEditingController age;
  final TextEditingController heightInches;
  final TextEditingController weightPounds;
  final String gender;
  final String activityLevel;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onActivityChanged;
  final VoidCallback onChanged;

  @override
  State<BodyProfileCard> createState() => _BodyProfileCardState();
}

class _BodyProfileCardState extends State<BodyProfileCard> {
  @override
  void initState() {
    super.initState();
    widget.age.addListener(widget.onChanged);
    widget.heightInches.addListener(widget.onChanged);
    widget.weightPounds.addListener(widget.onChanged);
  }

  @override
  void dispose() {
    widget.age.removeListener(widget.onChanged);
    widget.heightInches.removeListener(widget.onChanged);
    widget.weightPounds.removeListener(widget.onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal details',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'These answers help calculate calorie and macro targets for your plan.',
            style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: widget.age,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: widget.heightInches,
                  label: 'Height in',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  controller: widget.weightPounds,
                  label: 'Weight lb',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SegmentedPicker(
            label: 'Gender',
            value: widget.gender,
            options: const {
              'female': 'Female',
              'male': 'Male',
              'other': 'Other',
            },
            onChanged: widget.onGenderChanged,
          ),
          const SizedBox(height: 12),
          _SegmentedPicker(
            label: 'Activity',
            value: widget.activityLevel,
            options: const {
              'sedentary': 'Low',
              'light': 'Light',
              'moderate': 'Moderate',
              'active': 'Active',
              'very_active': 'Very active',
            },
            onChanged: widget.onActivityChanged,
          ),
        ],
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: value == option.key,
                onSelected: (_) => onChanged(option.key),
                selectedColor: AppColors.green.withValues(alpha: .16),
                labelStyle: TextStyle(
                  color: value == option.key
                      ? AppColors.deepGreen
                      : _mutedColor(context),
                  fontWeight: FontWeight.w900,
                ),
                side: BorderSide(
                  color: value == option.key
                      ? AppColors.green
                      : _lineColor(context),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class SelectedGoalPlanCard extends StatelessWidget {
  const SelectedGoalPlanCard({
    required this.planName,
    required this.description,
    required this.color,
    required this.icon,
    required this.onEdit,
    super.key,
  });

  final String planName;
  final String description;
  final Color color;
  final IconData icon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit Plan')),
        ],
      ),
    );
  }
}

class NutritionModuleCard extends StatelessWidget {
  const NutritionModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.deepGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.deepGreen),
          ],
        ),
      ),
    );
  }
}

class NutritionComingSoonCard extends StatelessWidget {
  const NutritionComingSoonCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _panelColor(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Coming soon',
                        style: TextStyle(
                          color: _mutedColor(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionActionCard extends StatelessWidget {
  const NutritionActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.orange,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantRecommendationsScreen extends StatefulWidget {
  const RestaurantRecommendationsScreen({
    required this.repo,
    required this.goals,
    this.dashboard,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic> goals;
  final Map<String, dynamic>? dashboard;

  @override
  State<RestaurantRecommendationsScreen> createState() =>
      _RestaurantRecommendationsScreenState();
}

class _RestaurantRecommendationsScreenState
    extends State<RestaurantRecommendationsScreen> {
  final _restaurant = TextEditingController();
  final _message = TextEditingController();
  Map<String, dynamic>? _result;
  final List<_RestaurantChatMessage> _messages = [];
  Map<String, dynamic>? _selectedRecommendation;
  bool _loading = false;
  bool _chatLoading = false;
  String? _error;

  @override
  void dispose() {
    _restaurant.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = _list(
      _result?['recommendations'],
    ).map(_map).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restaurant Coach',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedRecommendation == null
                              ? 'Ask what to order.'
                              : 'Discussing ${_stringValue(_selectedRecommendation?['name'], 'selected option')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _mutedColor(context),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_result != null)
                    IconButton(
                      onPressed: _resetChat,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
            ),
            if (_result != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: _RestaurantOptionsPanel(
                  result: _result!,
                  recommendations: recommendations,
                  selectedRecommendation: _selectedRecommendation,
                  onSelect: _selectRecommendation,
                  onReset: _resetChat,
                ),
              ),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  if (_result == null)
                    _RestaurantIntroCard(goals: widget.goals),
                  if (_error != null) MessageBox(message: _error!),
                  for (final message in _messages) ...[
                    _RestaurantChatBubble(message: message),
                    const SizedBox(height: 10),
                  ],
                  if (_loading) ...[
                    const AnalyzingMealIndicator(
                      icon: Icons.storefront_rounded,
                      title: 'Searching the menu',
                      subtitle: 'Comparing options against your goals',
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_chatLoading)
                    _RestaurantChatBubble(
                      message: const _RestaurantChatMessage(
                        role: _RestaurantChatRole.assistant,
                        text: 'Thinking through the best menu fit...',
                      ),
                      loading: true,
                    ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                14 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: _surfaceColor(context),
                border: Border(top: BorderSide(color: _lineColor(context))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_result != null && _selectedRecommendation != null) ...[
                    _SelectedRestaurantOptionPill(
                      recommendation: _selectedRecommendation!,
                      onClear: () =>
                          setState(() => _selectedRecommendation = null),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _result == null ? _restaurant : _message,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _result == null
                                ? 'Where are you eating? Example: Chick-fil-A'
                                : _selectedRecommendation == null
                                ? 'Ask about another meal or what fits best...'
                                : 'Ask about the selected option...',
                            filled: true,
                            fillColor: _panelColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _loading || _chatLoading
                            ? null
                            : _handleSend,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: Colors.white,
                          fixedSize: const Size(52, 52),
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        child: _loading || _chatLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    if (_result == null) {
      await _generateRecommendations();
    } else {
      await _askFollowUp();
    }
  }

  void _selectRecommendation(Map<String, dynamic> recommendation) {
    setState(() {
      _selectedRecommendation = recommendation;
    });
  }

  void _resetChat() {
    setState(() {
      _result = null;
      _selectedRecommendation = null;
      _messages.clear();
      _error = null;
      _message.clear();
      _restaurant.clear();
    });
  }

  Future<void> _generateRecommendations() async {
    final restaurant = _restaurant.text.trim();
    if (restaurant.isEmpty) {
      setState(() => _error = 'Enter a restaurant first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _messages.add(
        _RestaurantChatMessage(
          role: _RestaurantChatRole.user,
          text: restaurant,
        ),
      );
    });
    try {
      final response = await widget.repo.askAssistant(
        action: 'restaurant_recommendations',
        request: _requestPayload(),
        dashboard: widget.dashboard,
        goals: widget.goals,
      );
      if (!mounted) return;
      setState(() {
        _result = response;
        _messages.add(
          _RestaurantChatMessage(
            role: _RestaurantChatRole.assistant,
            text: _stringValue(
              response['summary'],
              'I found 3 options that can fit your goals.',
            ),
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Could not get restaurant recommendations: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _askFollowUp() async {
    final message = _message.text.trim();
    if (message.isEmpty) return;
    final selected = _selectedRecommendation;
    setState(() {
      _chatLoading = true;
      _error = null;
      _messages.add(
        _RestaurantChatMessage(
          role: _RestaurantChatRole.user,
          text: selected == null
              ? message
              : '${_optionLabel(selected)}: $message',
        ),
      );
      _message.clear();
    });
    try {
      final response = await widget.repo.askAssistant(
        action: 'restaurant_recommendations',
        request: {
          ..._requestPayload(),
          'message': message,
          'selected_recommendation': selected,
          'previous_recommendations': _result,
        },
        dashboard: widget.dashboard,
        goals: widget.goals,
      );
      if (!mounted) return;
      setState(() {
        _result = response;
        _messages.add(
          _RestaurantChatMessage(
            role: _RestaurantChatRole.assistant,
            text: _stringValue(
              response['discussion_reply'],
              _stringValue(
                response['summary'],
                'Here is how I would think about that choice.',
              ),
            ),
          ),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not answer that: $error');
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Map<String, dynamic> _requestPayload() {
    return {
      'restaurant': _restaurant.text.trim(),
      'message': _message.text.trim(),
      'goals': widget.goals,
      'today_totals': _map(widget.dashboard?['totals']),
      'today_meals': _list(widget.dashboard?['meals']),
    };
  }
}

enum _RestaurantChatRole { user, assistant }

class _RestaurantChatMessage {
  const _RestaurantChatMessage({required this.role, required this.text});

  final _RestaurantChatRole role;
  final String text;
}

String _optionLabel(Map<String, dynamic> recommendation) {
  final rank = _num(recommendation['rank'], fallback: 1).round();
  final name = _stringValue(recommendation['name'], 'Menu option');
  return 'Option $rank - $name';
}

class _RestaurantIntroCard extends StatelessWidget {
  const _RestaurantIntroCard({required this.goals});

  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Where are you eating?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Type a restaurant, then choose one of the 3 recommended meals to discuss swaps or your favorite order.',
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Goal: ${_stringValue(goals['plan_name'], 'Nutrition plan')}',
                  style: const TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantChatBubble extends StatelessWidget {
  const _RestaurantChatBubble({required this.message, this.loading = false});

  final _RestaurantChatMessage message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _RestaurantChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? AppColors.lime : _surfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: isUser ? null : Border.all(color: _lineColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : _textColor(context),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantOptionsPanel extends StatelessWidget {
  const _RestaurantOptionsPanel({
    required this.result,
    required this.recommendations,
    required this.selectedRecommendation,
    required this.onSelect,
    required this.onReset,
  });

  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> recommendations;
  final Map<String, dynamic>? selectedRecommendation;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stringValue(result['restaurant'], 'Restaurant options'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap an option to discuss it in the chat.',
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                final selected =
                    selectedRecommendation != null &&
                    _stringValue(selectedRecommendation?['name'], '') ==
                        _stringValue(recommendation['name'], '');
                return _RestaurantOptionMiniCard(
                  recommendation: recommendation,
                  selected: selected,
                  onTap: () => onSelect(recommendation),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantOptionMiniCard extends StatelessWidget {
  const _RestaurantOptionMiniCard({
    required this.recommendation,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> recommendation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nutrition = _map(recommendation['estimated_nutrition']);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 184,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: _isDark(context) ? .18 : .1)
              : _panelColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.green : _lineColor(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.green
                        : AppColors.green.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${_num(recommendation['rank'], fallback: 1).round()}',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.deepGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    selected ? 'Selected' : 'Option',
                    style: TextStyle(
                      color: selected
                          ? AppColors.deepGreen
                          : _mutedColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _stringValue(recommendation['name'], 'Menu option'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Text(
              '${_num(nutrition['calories']).round()} kcal  •  P ${_num(nutrition['protein']).round()}g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedRestaurantOptionPill extends StatelessWidget {
  const _SelectedRestaurantOptionPill({
    required this.recommendation,
    required this.onClear,
  });

  final Map<String, dynamic> recommendation;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: _isDark(context) ? .16 : .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.deepGreen,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_optionLabel(recommendation)} selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class CompactPlanTargetsCard extends StatelessWidget {
  const CompactPlanTargetsCard({required this.goals, super.key});

  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final keyTargets = [
      _PlanTargetSummary(
        label: 'Calories',
        keyName: 'calories',
        value: _num(goals['calories']).round(),
        unit: 'kcal',
        color: AppColors.orange,
      ),
      _PlanTargetSummary(
        label: 'Protein',
        keyName: 'protein',
        value: _num(goals['protein']).round(),
        unit: 'g',
        color: AppColors.green,
      ),
      _PlanTargetSummary(
        label: 'Carbs',
        keyName: 'carbs',
        value: _num(goals['carbs']).round(),
        unit: 'g',
        color: AppColors.yellow,
      ),
      _PlanTargetSummary(
        label: 'Fat',
        keyName: 'fat',
        value: _num(goals['fat']).round(),
        unit: 'g',
        color: AppColors.violet,
      ),
      _PlanTargetSummary(
        label: 'Fiber',
        keyName: 'fiber',
        value: _num(goals['fiber']).round(),
        unit: 'g',
        color: Colors.teal,
      ),
      _PlanTargetSummary(
        label: 'Sugar',
        keyName: 'sugar',
        value: _num(goals['sugar']).round(),
        unit: 'g',
        color: Colors.redAccent,
      ),
      _PlanTargetSummary(
        label: 'Sodium',
        keyName: 'sodium',
        value: _num(goals['sodium']).round(),
        unit: 'mg',
        color: Colors.cyan,
      ),
      _PlanTargetSummary(
        label: 'Potassium',
        keyName: 'potassium',
        value: _num(goals['potassium']).round(),
        unit: 'mg',
        color: Colors.lightGreen,
      ),
    ];

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily target snapshot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(
                Icons.insights_rounded,
                color: AppColors.deepGreen,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: .96,
            children: [
              for (final target in keyTargets)
                _CompactPlanTargetTile(target: target, goals: goals),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactPlanTargetTile extends StatelessWidget {
  const _CompactPlanTargetTile({required this.target, required this.goals});

  final _PlanTargetSummary target;
  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final direction = _goalDefinition(target.keyName, goals).shortLabel;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: target.color.withValues(alpha: _isDark(context) ? .14 : .09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: target.color.withValues(alpha: _isDark(context) ? .22 : .16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: target.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  direction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              target.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${target.value} ${target.unit}',
              maxLines: 1,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTargetSummary {
  const _PlanTargetSummary({
    required this.label,
    required this.keyName,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String keyName;
  final int value;
  final String unit;
  final Color color;
}

class GoalPlanCard extends StatelessWidget {
  const GoalPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GoalPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? plan.color.withValues(alpha: .13)
              : _surfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? plan.color : _lineColor(context),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: plan.color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(plan.icon, color: plan.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: plan.color, size: 24),
          ],
        ),
      ),
    );
  }
}

class GoalEditorSection extends StatelessWidget {
  const GoalEditorSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<GoalInput> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.75,
            children: children,
          ),
        ],
      ),
    );
  }
}

class GoalInput extends StatelessWidget {
  const GoalInput({
    required this.controller,
    required this.label,
    required this.unit,
    required this.readOnly,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: readOnly ? _surfaceColor(context) : _panelColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: readOnly ? _lineColor(context) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    readOnly: readOnly,
                    enableInteractiveSelection: !readOnly,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.repo,
    required this.goals,
    required this.dashboard,
    required this.history,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onReset,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic>? goals;
  final Map<String, dynamic>? dashboard;
  final Map<String, dynamic>? history;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final meals = _list(dashboard?['meals']);
    final series = _list(history?['series']).map(_map).toList();
    final averages = _trackedDayAverages(series);
    final trackedDays = series.where(_historyDayHasEntries).length;
    final streak = _trackingStreak(series);
    final week = _currentTrackingWeek(series);
    final displayName = _userDisplayName(user);
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        ProfileStreakCard(streak: streak, displayName: displayName, week: week),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              const Text(
                'Your Stats',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatBlock(label: 'Days tracked', value: '$trackedDays'),
                  StatBlock(
                    label: 'Meals today',
                    value: meals.length.toString(),
                  ),
                  StatBlock(
                    label: 'Avg calories',
                    value: _num(averages['calories']).round().toString(),
                  ),
                  StatBlock(
                    label: 'Avg protein',
                    value: '${_num(averages['protein']).round()}g',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: repo.weightMetrics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const WeightMetricsLoadingCard();
            }
            return WeightMetricsCard(
              metrics: snapshot.data,
              onEditTarget: (metrics) =>
                  _showTargetWeightDialog(context, initialMetrics: metrics),
              onOpenEntries: () => _openWeightEntries(context),
            );
          },
        ),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: repo.assistantProfile(_map(goals)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const ProfileSettingsLoadingBlock();
                  }
                  final profile = snapshot.data ?? const <String, dynamic>{};
                  return Column(
                    children: [
                      ProfileTextRow(
                        icon: Icons.person_rounded,
                        label: 'Name',
                        value: displayName,
                      ),
                      const Divider(height: 22, color: AppColors.line),
                      ProfileTextRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: user?.email ?? 'Signed in',
                      ),
                      const Divider(height: 22, color: AppColors.line),
                      BodyProfileSettingsSection(
                        profile: profile,
                        loading: false,
                        onEdit: () => _showBodyProfileDialog(context, profile),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 22, color: AppColors.line),
              ProfileActionRow(
                icon: Icons.monitor_weight_rounded,
                label: 'Weight entries',
                description: 'View, edit, or delete logged weights',
                onTap: () => _openWeightEntries(context),
              ),
              const Divider(height: 22, color: AppColors.line),
              ProfileToggleRow(
                icon: Icons.dark_mode_rounded,
                label: 'Dark mode',
                description: themeMode == ThemeMode.dark
                    ? 'Using dark appearance'
                    : 'Using light appearance',
                value: themeMode == ThemeMode.dark,
                onChanged: (enabled) => onThemeModeChanged(
                  enabled ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
              const Divider(height: 22, color: AppColors.line),
              ProfileActionRow(
                icon: Icons.email_rounded,
                label: 'Change email',
                description: 'Use a different sign-in email',
                onTap: () => _showEmailDialog(context),
              ),
              const Divider(height: 22, color: AppColors.line),
              ProfileActionRow(
                icon: Icons.lock_rounded,
                label: 'Change password',
                description: 'Confirm your current password first',
                onTap: () => _showPasswordDialog(context),
              ),
              const Divider(height: 22, color: AppColors.line),
              ProfileActionRow(
                icon: Icons.restart_alt_rounded,
                label: 'Reset all data',
                description: 'Clear meals, history, and goals',
                destructive: true,
                onTap: () => _showResetDataDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Sign out', onPressed: repo.signOut),
      ],
    );
  }

  Future<void> _showEmailDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: Supabase.instance.client.auth.currentUser?.email ?? '',
    );
    final email = await _showProfileInputDialog(
      context: context,
      title: 'Update email',
      action: 'Update',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || email.trim().isEmpty || !context.mounted) return;
    try {
      await repo.updateEmail(email.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your email to confirm the change.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update email: $error')));
    }
  }

  Future<void> _showPasswordDialog(BuildContext context) async {
    final result = await _showPasswordUpdateDialog(context);
    if (result == null || !context.mounted) return;
    if (result.newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }
    if (result.newPassword != result.confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.')),
      );
      return;
    }
    try {
      await repo.updatePasswordWithCurrent(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update password: $error')),
      );
    }
  }

  Future<void> _showBodyProfileDialog(
    BuildContext context,
    Map<String, dynamic> profile,
  ) async {
    final input = await _showBodyProfileUpdateDialog(context, profile);
    if (input == null || !context.mounted) return;
    final age = num.tryParse(input.age);
    final heightInches = num.tryParse(input.heightInches);
    final weightPounds = num.tryParse(input.weightPounds);
    if (age == null || heightInches == null || weightPounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid age, height, and weight.')),
      );
      return;
    }

    final planName = goals?['plan_name'] is String
        ? '${goals?['plan_name']}'
        : 'Maintain weight';
    final recommended = _recommendedTargetsForProfile(
      planName,
      age: age,
      heightInches: heightInches,
      weightPounds: weightPounds,
      gender: input.gender,
      activityLevel: input.activityLevel,
    );

    try {
      await repo.updateAssistantProfile({
        'goal_type': planName,
        'height_cm': heightInches * 2.54,
        'weight_kg': weightPounds * 0.45359237,
        'age': age.round(),
        'gender': input.gender,
        'activity_level': input.activityLevel,
        'calorie_target': recommended['calories'],
        'protein_target': recommended['protein'],
        'carb_target': recommended['carbs'],
        'fat_target': recommended['fat'],
        'fiber_target': recommended['fiber'],
        'sugar_limit': recommended['sugar'],
        'sodium_target': recommended['sodium'],
        'potassium_target': recommended['potassium'],
        'bmr': recommended['bmr'],
        'tdee': recommended['tdee'],
        'calorie_adjustment_percent': recommended['calorie_adjustment_percent'],
        'calculation_method': 'mifflin_st_jeor',
      });
      await repo.updateGoals(_goalTargetsOnly(recommended), planName: planName);
      await onReset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body profile and targets updated.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update body profile: $error')),
      );
    }
  }

  Future<void> _showResetDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This clears your meals, history, nutrition totals, and goals. Your account will stay active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await repo.resetAllData();
      await onReset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data has been reset.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reset data: $error')));
    }
  }

  Future<void> _openWeightEntries(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WeightEntriesScreen(repo: repo)),
    );
    if (changed == true) await onReset();
  }

  Future<void> _showTargetWeightDialog(
    BuildContext context, {
    required Map<String, dynamic>? initialMetrics,
  }) async {
    final metrics = initialMetrics ?? const <String, dynamic>{};
    final profile = _map(metrics['profile']);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TargetWeightScreen(
          repo: repo,
          initialTargetKg: _num(profile['target_weight_kg']),
        ),
      ),
    );
    if (changed == true) {
      await onReset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Target weight updated.')));
    }
  }
}

class TargetWeightScreen extends StatefulWidget {
  const TargetWeightScreen({
    required this.repo,
    required this.initialTargetKg,
    super.key,
  });

  final NutritionRepository repo;
  final num initialTargetKg;

  @override
  State<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends State<TargetWeightScreen> {
  late final TextEditingController _target;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _target = TextEditingController(
      text: widget.initialTargetKg > 0
          ? _formatWeightPounds(widget.initialTargetKg)
          : '',
    );
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Target Weight',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set the weight you are working toward. Daily weigh-ins can be logged separately without changing this target.',
              style: TextStyle(color: _mutedColor(context), height: 1.35),
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Goal weight',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _target,
                    label: 'Target weight lb',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    useHintText: true,
                    hideHintWhenNotEmpty: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your target in pounds.',
                    style: TextStyle(color: _mutedColor(context), fontSize: 12),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    MessageBox(message: _message!),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Save Target',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final target = num.tryParse(_target.text.trim());
    if (target == null || target <= 0) {
      setState(() => _message = 'Enter a valid target weight.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.repo.updateTargetWeight(target);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not save target: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ProfileStreakCard extends StatelessWidget {
  const ProfileStreakCard({
    required this.streak,
    required this.displayName,
    required this.week,
    super.key,
  });

  final int streak;
  final String displayName;
  final List<TrackingWeekDay> week;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orange.withValues(alpha: .1),
              border: Border.all(color: _lineColor(context)),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.orange,
              size: 48,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 54,
              height: .9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Day Streak',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            streak > 0
                ? 'You are doing really great, $displayName!'
                : 'Log a meal today to start your streak.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor(context), fontSize: 14),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in week) TrackingDayBubble(day: day)],
          ),
        ],
      ),
    );
  }
}

class TrackingDayBubble extends StatelessWidget {
  const TrackingDayBubble({required this.day, super.key});

  final TrackingWeekDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          day.label,
          style: TextStyle(
            color: day.isToday ? _textColor(context) : _mutedColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: day.tracked
                ? const LinearGradient(
                    colors: [Color(0xFFFFB15E), Color(0xFFFF735E)],
                  )
                : null,
            color: day.tracked ? null : _panelColor(context),
          ),
          child: day.tracked
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : Text(
                  '${day.date.day}',
                  style: TextStyle(
                    color: day.isToday
                        ? _textColor(context)
                        : _mutedColor(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ],
    );
  }
}

class WeightMetricsLoadingCard extends StatelessWidget {
  const WeightMetricsLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      padding: EdgeInsets.all(18),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class WeightMetricsCard extends StatelessWidget {
  const WeightMetricsCard({
    required this.metrics,
    required this.onEditTarget,
    required this.onOpenEntries,
    super.key,
  });

  final Map<String, dynamic>? metrics;
  final ValueChanged<Map<String, dynamic>?> onEditTarget;
  final VoidCallback onOpenEntries;

  @override
  Widget build(BuildContext context) {
    final profile = _map(metrics?['profile']);
    final entries = _list(metrics?['entries']).map(_map).toList();
    final currentKg = entries.isNotEmpty
        ? _num(entries.last['weight_kg'])
        : _num(profile['weight_kg']);
    final startKg = entries.isNotEmpty ? _num(entries.first['weight_kg']) : 0;
    final targetKg = _num(profile['target_weight_kg']);
    final changeLb = startKg > 0 && currentKg > 0
        ? (currentKg - startKg) / 0.45359237
        : 0;
    final remainingLb = targetKg > 0 && currentKg > 0
        ? (currentKg - targetKg).abs() / 0.45359237
        : 0;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Metrics',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Tooltip(
                message: 'View weight entries',
                child: InkWell(
                  onTap: onOpenEntries,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.monitor_weight_rounded,
                      color: AppColors.green.withValues(alpha: .95),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onEditTarget(metrics),
                child: const Text('Target'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Daily weigh-ins at the same time make this trend more useful.',
            style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: entries.length < 2
                ? Center(
                    child: Text(
                      'Log at least 2 weights to see your trend.',
                      style: TextStyle(color: _mutedColor(context)),
                    ),
                  )
                : CustomPaint(
                    painter: WeightTrendPainter(
                      entries: entries,
                      targetKg: targetKg,
                      lineColor: AppColors.green,
                      targetColor: AppColors.orange,
                      gridColor: _lineColor(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatBlock(
                label: 'Current',
                value: currentKg > 0
                    ? '${_formatWeightPounds(currentKg)} lb'
                    : '--',
              ),
              StatBlock(
                label: 'Target',
                value: targetKg > 0
                    ? '${_formatWeightPounds(targetKg)} lb'
                    : '--',
              ),
              StatBlock(
                label: 'Change',
                value: entries.length >= 2
                    ? '${changeLb >= 0 ? '+' : ''}${_compactNum(changeLb)} lb'
                    : '--',
              ),
              StatBlock(
                label: 'To target',
                value: targetKg > 0 && currentKg > 0
                    ? '${_compactNum(remainingLb)} lb'
                    : '--',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WeightTrendPainter extends CustomPainter {
  const WeightTrendPainter({
    required this.entries,
    required this.targetKg,
    required this.lineColor,
    required this.targetColor,
    required this.gridColor,
  });

  final List<Map<String, dynamic>> entries;
  final num targetKg;
  final Color lineColor;
  final Color targetColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final weights = entries.map((entry) => _num(entry['weight_kg'])).toList();
    final values = [...weights, if (targetKg > 0) targetKg];
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final range = math.max(0.1, maxValue - minValue);
    final padding = math.max(0.3, range * .12);
    final low = minValue - padding;
    final high = maxValue + padding;
    final chartHeight = size.height - 18;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 8 + (chartHeight * i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointFor(int index, num weight) {
      final x = entries.length == 1
          ? size.width / 2
          : size.width * index / (entries.length - 1);
      final ratio = (weight.toDouble() - low) / (high - low);
      final y = 8 + chartHeight - (ratio * chartHeight);
      return Offset(x, y);
    }

    if (targetKg > 0) {
      final ratio = (targetKg.toDouble() - low) / (high - low);
      final y = 8 + chartHeight - (ratio * chartHeight);
      final targetPaint = Paint()
        ..color = targetColor.withValues(alpha: .55)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), targetPaint);
    }

    final path = Path()
      ..moveTo(pointFor(0, weights.first).dx, pointFor(0, weights.first).dy);
    for (var i = 1; i < weights.length; i++) {
      final point = pointFor(i, weights[i]);
      path.lineTo(point.dx, point.dy);
    }
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < weights.length; i++) {
      canvas.drawCircle(pointFor(i, weights[i]), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeightTrendPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.targetKg != targetKg ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class WeightEntriesScreen extends StatefulWidget {
  const WeightEntriesScreen({required this.repo, super.key});

  final NutritionRepository repo;

  @override
  State<WeightEntriesScreen> createState() => _WeightEntriesScreenState();
}

class _WeightEntriesScreenState extends State<WeightEntriesScreen> {
  late Future<Map<String, dynamic>> _metrics;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _metrics = widget.repo.weightMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _metrics,
            builder: (context, snapshot) {
              final entries = _list(
                snapshot.data?['entries'],
              ).map(_map).toList().reversed.toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(_changed),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Weight Entries',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Edit or remove weigh-ins if one was entered incorrectly.',
                    style: TextStyle(color: _mutedColor(context), height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (entries.isEmpty)
                    const EmptyMeals(message: 'No weight entries logged yet.')
                  else
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var index = 0; index < entries.length; index++)
                            WeightEntryTile(
                              entry: entries[index],
                              onEdit: () => _editEntry(entries[index]),
                              onDelete: () => _deleteEntry(entries[index]),
                              showDivider: index != entries.length - 1,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _metrics = widget.repo.weightMetrics();
    });
    await _metrics;
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditWeightEntryScreen(repo: widget.repo, entry: entry),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete weight entry?'),
        content: Text(
          'Remove ${_formatWeightPounds(_num(entry['weight_kg']))} lb?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repo.deleteWeightEntry('${entry['id']}');
    _changed = true;
    await _reload();
  }
}

class WeightEntryTile extends StatelessWidget {
  const WeightEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.showDivider,
    super.key,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final loggedAt = DateTime.tryParse('${entry['logged_at']}')?.toLocal();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_weight_rounded,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatWeightPounds(_num(entry['weight_kg']))} lb',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loggedAt == null
                          ? 'Logged weight'
                          : _formatWeightEntryDateTime(loggedAt),
                      style: TextStyle(
                        color: _mutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: _lineColor(context)),
      ],
    );
  }
}

class EditWeightEntryScreen extends StatefulWidget {
  const EditWeightEntryScreen({
    required this.repo,
    required this.entry,
    super.key,
  });

  final NutritionRepository repo;
  final Map<String, dynamic> entry;

  @override
  State<EditWeightEntryScreen> createState() => _EditWeightEntryScreenState();
}

class _EditWeightEntryScreenState extends State<EditWeightEntryScreen> {
  late final TextEditingController _weight;
  late DateTime _loggedAt;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: _formatWeightPounds(_num(widget.entry['weight_kg'])),
    );
    _loggedAt =
        DateTime.tryParse('${widget.entry['logged_at']}')?.toLocal() ??
        DateTime.now();
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Weight',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update the weight amount or the date and time it was logged.',
              style: TextStyle(color: _mutedColor(context), height: 1.35),
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _weight,
                    label: 'Weight lb',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    useHintText: true,
                    hideHintWhenNotEmpty: true,
                  ),
                  const SizedBox(height: 14),
                  WeightDateTimePickerRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: _formatWeightEntryDate(_loggedAt),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 22, color: AppColors.line),
                  WeightDateTimePickerRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: _formatWeightEntryTime(_loggedAt),
                    onTap: _pickTime,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    MessageBox(message: _message!),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Save Entry',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _loggedAt.hour,
        _loggedAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _loggedAt = DateTime(
        _loggedAt.year,
        _loggedAt.month,
        _loggedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    final pounds = num.tryParse(_weight.text.trim());
    if (pounds == null || pounds <= 0) {
      setState(() => _message = 'Enter a valid weight.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.repo.updateWeightEntry(
        id: '${widget.entry['id']}',
        weightPounds: pounds,
        loggedAt: _loggedAt,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not save entry: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class WeightDateTimePickerRow extends StatelessWidget {
  const WeightDateTimePickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.deepGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: _textColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: _mutedColor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(
            icon,
            color: destructive ? Colors.redAccent : AppColors.muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: destructive ? Colors.redAccent : null,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class BodyProfileSettingsSection extends StatelessWidget {
  const BodyProfileSettingsSection({
    required this.profile,
    required this.loading,
    required this.onEdit,
    super.key,
  });

  final Map<String, dynamic> profile;
  final bool loading;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Row(
        children: [
          Icon(Icons.monitor_weight_rounded, color: AppColors.muted, size: 20),
          SizedBox(width: 10),
          Expanded(child: LinearProgressIndicator(minHeight: 3)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.monitor_weight_rounded,
              color: AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Body Profile',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Column(
            children: [
              _ProfileDetailRow(label: 'Age', value: _ageLabel(profile)),
              _ProfileDetailRow(label: 'Height', value: _heightLabel(profile)),
              _ProfileDetailRow(label: 'Weight', value: _weightLabel(profile)),
              _ProfileDetailRow(
                label: 'Gender',
                value: _genderLabel('${profile['gender'] ?? ''}'),
              ),
              _ProfileDetailRow(
                label: 'Activity level',
                value: _activityLabel(
                  '${profile['activity_level'] ?? 'moderate'}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileSettingsLoadingBlock extends StatelessWidget {
  const ProfileSettingsLoadingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading profile settings...',
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileLoadingRow extends StatelessWidget {
  const ProfileLoadingRow({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _mutedColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class ProfileTextRow extends StatelessWidget {
  const ProfileTextRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileToggleRow extends StatelessWidget {
  const ProfileToggleRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class NutritionFactsScreen extends StatelessWidget {
  const NutritionFactsScreen({
    required this.title,
    required this.subtitle,
    required this.nutrition,
    required this.goals,
    this.items = const [],
    this.meal,
    this.repo,
    this.deleteContext = 'today',
    super.key,
  });

  factory NutritionFactsScreen.forMeal({
    required Map<String, dynamic> meal,
    required Map<String, dynamic> goals,
    required NutritionRepository repo,
    String deleteContext = 'today',
  }) {
    final items = _list(meal['items']).map(_map).toList();
    final nutrition = _nutritionWithItemFallback(meal, items);
    return NutritionFactsScreen(
      title: '${meal['title']}',
      subtitle:
          '${meal['meal_type']} • ${_num(nutrition['calories']).round()} kcal',
      nutrition: nutrition,
      goals: goals,
      items: items,
      meal: meal,
      repo: repo,
      deleteContext: deleteContext,
    );
  }

  final String title;
  final String subtitle;
  final Map<String, dynamic> nutrition;
  final Map<String, dynamic> goals;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? meal;
  final NutritionRepository? repo;
  final String deleteContext;

  bool get _isMealDetail => meal != null && repo != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isMealDetail) ...[
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: Icons.edit_rounded,
                    onTap: () => _editMeal(context),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    iconColor: Colors.redAccent,
                    backgroundColor: const Color(0xFFFFF0F0),
                    onTap: () => _confirmDeleteMeal(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            if (_isMealDetail && items.isNotEmpty) ...[
              MealContentsCard(items: items),
              const SizedBox(height: 16),
            ],
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  NutritionFactRow(
                    label: 'Calories',
                    value: _num(nutrition['calories']),
                    goal: _num(goals['calories'], fallback: 2200),
                    keyName: 'calories',
                    goals: goals,
                    unit: 'kcal',
                    color: AppColors.orange,
                    prominent: true,
                  ),
                  const Divider(height: 24, color: AppColors.line),
                  NutritionFactRow(
                    label: 'Protein',
                    value: _num(nutrition['protein']),
                    goal: _num(goals['protein'], fallback: 150),
                    keyName: 'protein',
                    goals: goals,
                    unit: 'g',
                    color: AppColors.green,
                  ),
                  NutritionFactRow(
                    label: 'Carbs',
                    value: _num(nutrition['carbs']),
                    goal: _num(goals['carbs'], fallback: 250),
                    keyName: 'carbs',
                    goals: goals,
                    unit: 'g',
                    color: AppColors.yellow,
                  ),
                  NutritionFactRow(
                    label: 'Fat',
                    value: _num(nutrition['fat']),
                    goal: _num(goals['fat'], fallback: 70),
                    keyName: 'fat',
                    goals: goals,
                    unit: 'g',
                    color: AppColors.violet,
                  ),
                  NutritionFactRow(
                    label: 'Fiber',
                    value: _num(nutrition['fiber']),
                    goal: _num(goals['fiber'], fallback: 30),
                    keyName: 'fiber',
                    goals: goals,
                    unit: 'g',
                    color: AppColors.green,
                  ),
                  NutritionFactRow(
                    label: 'Sugar',
                    value: _num(nutrition['sugar']),
                    goal: _num(goals['sugar'], fallback: 50),
                    keyName: 'sugar',
                    goals: goals,
                    unit: 'g',
                    color: AppColors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vitamins',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final fact in _vitaminFacts)
                    NutritionFactRow(
                      label: fact.$1,
                      value: _num(nutrition[fact.$2]),
                      goal: _num(goals[fact.$2], fallback: 100),
                      keyName: fact.$2,
                      goals: goals,
                      unit: '%',
                      color: fact.$3,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Minerals',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final fact in _mineralFacts)
                    NutritionFactRow(
                      label: fact.$1,
                      value: _num(nutrition[fact.$2]),
                      goal: _num(goals[fact.$2], fallback: fact.$4),
                      keyName: fact.$2,
                      goals: goals,
                      unit: fact.$5,
                      color: fact.$3,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMeal(BuildContext context) async {
    final targetMeal = meal;
    final targetRepo = repo;
    if (targetMeal == null || targetRepo == null) return;
    final parsed = _parsedFoodFromSavedMeal(targetMeal);
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodReviewScreen(
          repo: targetRepo,
          initialMeal: parsed,
          source: _stringValue(targetMeal['source'], 'manual'),
          rawInput: _stringValue(targetMeal['raw_input'], parsed.mealName),
          existingMeal: targetMeal,
        ),
      ),
    );
    if (edited == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDeleteMeal(BuildContext context) async {
    final targetMeal = meal;
    final targetRepo = repo;
    if (targetMeal == null || targetRepo == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete meal?'),
          content: Text('Remove ${targetMeal['title']} from $deleteContext?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) return;

    try {
      await targetRepo.deleteMeal(targetMeal);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete meal: $error')));
    }
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({required this.index, required this.onTap, super.key});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.restaurant_menu_rounded, 'Nutrition'),
      (Icons.add, ''),
      (Icons.fitness_center_rounded, 'Fitness'),
      (Icons.person_outline_rounded, 'Profile'),
    ];

    final inactiveColor = _mutedColor(context);
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: _isDark(context)
                ? const Color(0x66000000)
                : const Color(0x12000000),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: i == 2
                        ? Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.lime, AppColors.deepGreen],
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  items[i].$1,
                                  size: 22,
                                  color: index == i
                                      ? AppColors.lime
                                      : inactiveColor,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  items[i].$2,
                                  style: TextStyle(
                                    color: index == i
                                        ? AppColors.lime
                                        : inactiveColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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

class CalorieRing extends StatelessWidget {
  const CalorieRing({
    required this.value,
    required this.goal,
    required this.goals,
    super.key,
  });

  final num value;
  final num goal;
  final Map<String, dynamic> goals;

  @override
  Widget build(BuildContext context) {
    final definition = _goalDefinition('calories', goals);
    final statusColor = _goalStatusColor('calories', value, goal, goals);
    return SizedBox(
      width: 142,
      height: 142,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(142),
            painter: RingPainter(
              progress: _goalProgress(value, goal),
              color: statusColor,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '/ ${goal.round()} kcal',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  definition.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  RingPainter({required this.progress, required this.color});

  final num progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final base = Paint()
      ..color = const Color(0xFFEFEFF1)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class MacroRow extends StatelessWidget {
  const MacroRow({
    required this.name,
    required this.keyName,
    required this.value,
    required this.goal,
    required this.goals,
    required this.color,
    required this.unit,
    super.key,
  });

  factory MacroRow.fromValues(
    String name,
    Map<String, dynamic> totals,
    Map<String, dynamic> goals,
    String key,
    Color color,
    String unit,
  ) {
    return MacroRow(
      name: name,
      keyName: key,
      value: _num(totals[key]),
      goal: _num(goals[key], fallback: 1),
      goals: goals,
      color: color,
      unit: unit,
    );
  }

  final String name;
  final String keyName;
  final num value;
  final num goal;
  final Map<String, dynamic> goals;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final definition = _goalDefinition(keyName, goals);
    final statusColor = _goalStatusColor(keyName, value, goal, goals);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${value.round()} / ${goal.round()}$unit ${definition.shortLabel}',
              style: TextStyle(color: _mutedColor(context), fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _goalProgress(value, goal),
            minHeight: 8,
            color: statusColor == AppColors.muted ? color : statusColor,
            backgroundColor: _panelColor(context),
          ),
        ),
      ],
    );
  }
}

class MicroProgress extends StatelessWidget {
  const MicroProgress({
    required this.label,
    required this.keyName,
    required this.totals,
    required this.goals,
    required this.color,
    super.key,
  });

  final String label;
  final String keyName;
  final Map<String, dynamic> totals;
  final Map<String, dynamic> goals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = _num(totals[keyName]);
    final goal = _num(goals[keyName], fallback: 100);
    final definition = _goalDefinition(keyName, goals);
    final statusColor = _goalStatusColor(keyName, value, goal, goals);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _goalProgress(value, goal),
                minHeight: 8,
                color: statusColor == AppColors.muted ? color : statusColor,
                backgroundColor: _panelColor(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${value.round()} / ${goal.round()}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: _mutedColor(context), fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  definition.shortLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: _mutedColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionFactRow extends StatelessWidget {
  const NutritionFactRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.keyName,
    required this.goals,
    required this.unit,
    required this.color,
    this.prominent = false,
    super.key,
  });

  final String label;
  final num value;
  final num goal;
  final String keyName;
  final Map<String, dynamic> goals;
  final String unit;
  final Color color;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final definition = _goalDefinition(keyName, goals);
    final progress = _goalProgress(value, goal);
    final statusColor = _goalStatusColor(keyName, value, goal, goals);
    return Padding(
      padding: EdgeInsets.only(bottom: prominent ? 0 : 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: prominent ? 16 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_formatFactValue(value)}$unit',
                style: TextStyle(
                  fontSize: prominent ? 18 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${_formatFactValue(goal)}$unit ${definition.shortLabel}',
                style: TextStyle(color: _mutedColor(context), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: prominent ? 10 : 7,
              color: statusColor == AppColors.muted ? color : statusColor,
              backgroundColor: _panelColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class MealContentsCard extends StatelessWidget {
  const MealContentsCard({required this.items, super.key});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.deepGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  color: _mutedColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            MealContentItem(item: items[index]),
            if (index != items.length - 1)
              Divider(height: 22, color: _lineColor(context)),
          ],
        ],
      ),
    );
  }
}

class MealContentItem extends StatelessWidget {
  const MealContentItem({required this.item, super.key});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = _stringValue(item['name'], 'Food item');
    final portion = _mealItemPortionLabel(item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: .85),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                portion,
                style: TextStyle(color: _mutedColor(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MealTile extends StatelessWidget {
  const MealTile({required this.meal, required this.onTap, super.key});

  final Map<String, dynamic> meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _panelColor(context),
              child: Text(
                _emoji('${meal['source']}'),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meal['meal_type']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meal['title']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P ${_num(meal['protein']).round()}g   C ${_num(meal['carbs']).round()}g   F ${_num(meal['fat']).round()}g',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_num(meal['calories']).round()} kcal',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class AddModeCard extends StatelessWidget {
  const AddModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 142,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: _panelColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 39),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AddEntryCard extends StatelessWidget {
  const AddEntryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  const FoodCard({
    required this.emoji,
    required this.title,
    required this.calories,
    super.key,
  });

  final String emoji;
  final String title;
  final String calories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEAF5E0), Color(0xFFCBEAC4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 47)),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(calories, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({required this.child, required this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _lineColor(context)),
        boxShadow: [
          BoxShadow(
            color: _isDark(context)
                ? const Color(0x33000000)
                : const Color(0x09000000),
            blurRadius: _isDark(context) ? 20 : 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    required this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              action,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor ?? _panelColor(context),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 21, color: iconColor ?? _textColor(context)),
      ),
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.useHintText = false,
    this.hideHintOnFocus = false,
    this.hideHintWhenNotEmpty = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool useHintText;
  final bool hideHintOnFocus;
  final bool hideHintWhenNotEmpty;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.hideHintOnFocus) setState(() {});
  }

  void _onTextChanged() {
    if (widget.hideHintWhenNotEmpty) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shouldHideHint =
        widget.hideHintWhenNotEmpty && widget.controller.text.isNotEmpty ||
        widget.hideHintOnFocus && _focusNode.hasFocus;
    final visibleHint = shouldHideHint ? null : widget.label;
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        labelText: widget.useHintText ? null : widget.label,
        hintText: widget.useHintText ? visibleHint : null,
        filled: true,
        fillColor: _panelColor(context),
        hintStyle: TextStyle(color: _mutedColor(context)),
        labelStyle: TextStyle(color: _mutedColor(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading || onPressed == null ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(compact ? 48 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class MessageBox extends StatelessWidget {
  const MessageBox({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark(context)
            ? const Color(0xFF2C2418)
            : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: TextStyle(color: _textColor(context))),
    );
  }
}

class EmptyMeals extends StatelessWidget {
  const EmptyMeals({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, required this.onRetry, super.key});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class StatBlock extends StatelessWidget {
  const StatBlock({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

ParsedFood _parsedFoodFromSavedMeal(Map<String, dynamic> meal) {
  final itemRows = _list(meal['items']).map(_map).toList();
  final items = [
    for (final item in itemRows) FoodMatch.fromJson(_savedMealItemJson(item)),
  ];
  return ParsedFood(
    mealName: _stringValue(meal['title'], 'Reviewed Meal'),
    mealType: _stringValue(meal['meal_type'], 'snack'),
    confidence: _num(meal['confidence'], fallback: .9).toDouble(),
    needsReview: false,
    items: items,
  );
}

Map<String, dynamic> _savedMealItemJson(Map<String, dynamic> item) {
  final raw = _map(item['raw_provider_payload']);
  final amount = item['amount'] ?? raw['amount'] ?? 1;
  final unit = _stringValue(
    item['unit'] ?? raw['unit'],
    _unitFromReviewPortion(_stringValue(item['portion_label'], '1 serving')),
  );
  return {
    ...item,
    'amount': amount,
    'unit': unit,
    'normalized_query': _stringValue(
      item['normalized_query'],
      _stringValue(item['name'], 'food').toLowerCase(),
    ),
    'confidence_level': _confidenceTextFromScore(_num(item['confidence'])),
    'raw_provider_payload': raw,
  };
}

String _unitFromReviewPortion(String portion) {
  final parts = portion.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && _supportedUnits.contains(parts[1])) {
    return parts[1];
  }
  return 'serving';
}

String _confidenceTextFromScore(num score) {
  if (score >= .8) return 'high';
  if (score >= .6) return 'medium';
  return 'low';
}

Map<String, dynamic> _normalizeRegeneratedMeal(
  Map<String, dynamic> replacement,
  Map<String, dynamic> original,
) {
  final nutrition = _map(replacement['nutrition']);
  final mealName = _stringValue(
    replacement['name'],
    _stringValue(
      replacement['mealName'],
      _stringValue(original['name'], 'Meal'),
    ),
  );
  final normalized = {
    ...original,
    ...replacement,
    'meal_type': _stringValue(
      replacement['meal_type'],
      _stringValue(
        replacement['mealType'],
        _stringValue(original['meal_type'], 'meal'),
      ),
    ),
    'name': mealName,
    'description': _stringValue(replacement['description'], ''),
    'ingredients': replacement['ingredients'] ?? original['ingredients'] ?? [],
    'instructions':
        replacement['instructions'] ?? original['instructions'] ?? [],
    'calories': _num(
      replacement['calories'],
      fallback: _num(
        nutrition['calories'],
        fallback: _num(original['calories']),
      ),
    ),
    'protein': _num(
      replacement['protein'],
      fallback: _num(nutrition['protein'], fallback: _num(original['protein'])),
    ),
    'carbs': _num(
      replacement['carbs'],
      fallback: _num(nutrition['carbs'], fallback: _num(original['carbs'])),
    ),
    'fat': _num(
      replacement['fat'],
      fallback: _num(nutrition['fat'], fallback: _num(original['fat'])),
    ),
    'fiber': _num(
      replacement['fiber'],
      fallback: _num(nutrition['fiber'], fallback: _num(original['fiber'])),
    ),
    'sugar': _num(
      replacement['sugar'],
      fallback: _num(nutrition['sugar'], fallback: _num(original['sugar'])),
    ),
    'sodium': _num(
      replacement['sodium'],
      fallback: _num(nutrition['sodium'], fallback: _num(original['sodium'])),
    ),
    'potassium': _num(
      replacement['potassium'],
      fallback: _num(
        nutrition['potassium'],
        fallback: _num(original['potassium']),
      ),
    ),
    'why_this_fits': _stringValue(
      replacement['why_this_fits'],
      _stringValue(
        replacement['whyThisMealFits'],
        _stringValue(original['why_this_fits'], ''),
      ),
    ),
  };
  return {...normalized, 'instructions': _instructionsForMeal(normalized)};
}

List<String> _instructionsForMeal(Map<String, dynamic> meal) {
  final direct = _list(
    meal['instructions'],
  ).map((item) => '$item'.trim()).where((item) => item.isNotEmpty).toList();
  if (direct.isNotEmpty) return direct;

  final prep = _stringValue(meal['prep'], '').trim();
  if (prep.isNotEmpty) {
    final split = prep
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return split.isEmpty ? [prep] : split;
  }

  final name = _stringValue(meal['name'] ?? meal['mealName'], 'this meal');
  final ingredients = _list(meal['ingredients']).map(_map).toList();
  final hasProtein = ingredients.any((ingredient) {
    final label = _stringValue(
      ingredient['name'] ?? ingredient['ingredient'],
      '',
    ).toLowerCase();
    return label.contains('chicken') ||
        label.contains('beef') ||
        label.contains('turkey') ||
        label.contains('fish') ||
        label.contains('salmon') ||
        label.contains('egg') ||
        label.contains('tofu');
  });
  final hasGrain = ingredients.any((ingredient) {
    final label = _stringValue(
      ingredient['name'] ?? ingredient['ingredient'],
      '',
    ).toLowerCase();
    return label.contains('rice') ||
        label.contains('oat') ||
        label.contains('pasta') ||
        label.contains('quinoa') ||
        label.contains('toast') ||
        label.contains('bread');
  });

  return [
    'Gather and measure the listed ingredients.',
    if (hasGrain)
      'Cook grains, oats, pasta, or bread components according to package directions.',
    if (hasProtein) 'Cook any raw protein fully, then season to taste.',
    'Prep vegetables, fruit, sauces, or toppings while the main components cook.',
    'Assemble $name and serve warm or chilled as preferred.',
  ];
}

String _formatIngredientLine(Map<String, dynamic> ingredient) {
  final rawAmount = ingredient['amount'] ?? ingredient['quantity'];
  final amount = rawAmount == null
      ? ''
      : rawAmount is num
      ? _formatFactValue(rawAmount)
      : '$rawAmount'.trim();
  final unit = _stringValue(ingredient['unit'], '').trim();
  final name = _stringValue(
    ingredient['name'],
    _stringValue(ingredient['ingredient'], ''),
  ).trim();
  final quantity = [amount, unit].where((part) => part.isNotEmpty).join(' ');
  if (quantity.isEmpty) return name.isEmpty ? 'Ingredient' : name;
  if (name.isEmpty) return quantity;
  return '$quantity $name';
}

num _averageDailyPlanValue(Map<String, dynamic> plan, String key) {
  final totals = _list(plan['daily_totals']).map(_map).toList();
  if (totals.isNotEmpty) {
    final sum = totals.fold<num>(0, (total, day) => total + _num(day[key]));
    return sum / totals.length;
  }
  final days = _list(plan['days_plan']).map(_map).toList();
  if (days.isEmpty) return 0;
  final sum = days.fold<num>(0, (dayTotal, day) {
    final meals = _list(day['meals']).map(_map);
    return dayTotal +
        meals.fold<num>(0, (mealTotal, meal) => mealTotal + _num(meal[key]));
  });
  return sum / days.length;
}

Map<String, dynamic> _normalizeMealPlanCalendar(
  Map<String, dynamic> plan, {
  bool fillMissingMeals = true,
}) {
  final startDate = _parsePlanDate(plan['plan_start_date']) ?? DateTime.now();
  final days = _list(plan['days_plan']).map(_map).toList();
  final templateDays = days
      .where((day) => _list(day['meals']).isNotEmpty)
      .map(_map)
      .toList();
  final requestedDays = math.max(
    _num(plan['days'], fallback: days.length).round(),
    days.length,
  );
  final normalizedDays = <Map<String, dynamic>>[];
  for (var dayIndex = 0; dayIndex < requestedDays; dayIndex++) {
    final existing = dayIndex < days.length ? days[dayIndex] : null;
    final day = existing ?? <String, dynamic>{'day': dayIndex + 1, 'meals': []};
    final dayNumber = _num(day['day'], fallback: dayIndex + 1).round();
    final dayDate =
        _parsePlanDate(day['day_date']) ??
        DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        ).add(Duration(days: dayNumber - 1));
    final meals = _list(day['meals']).map(_map).toList();
    final resolvedMeals = meals.isNotEmpty || !fillMissingMeals
        ? meals
        : _fallbackMealsForPlanDay(dayNumber, templateDays, plan);
    normalizedDays.add({
      ...day,
      'day': dayNumber,
      'day_date': _date(dayDate),
      'meals': [
        for (var mealIndex = 0; mealIndex < resolvedMeals.length; mealIndex++)
          _normalizePlanMeal(dayNumber, resolvedMeals[mealIndex], mealIndex),
      ],
    });
  }
  return {
    ...plan,
    'plan_start_date': _date(startDate),
    'days_plan': normalizedDays,
  };
}

bool _planNeedsUniqueRetry(
  Map<String, dynamic> plan, {
  required String varietyMode,
  required String repeatPreference,
}) {
  final uniqueRequested =
      repeatPreference == 'Mostly unique' || varietyMode == 'More variety';
  if (!uniqueRequested) return false;
  final meals = <String>[];
  for (final day in _list(plan['days_plan']).map(_map)) {
    final dayMeals = _list(day['meals']).map(_map).toList();
    if (dayMeals.isEmpty) return true;
    for (final meal in dayMeals) {
      final name = _stringValue(meal['name'], '').toLowerCase().trim();
      if (name.isNotEmpty) meals.add(name);
      if (meal['generated_from_template'] == true) return true;
    }
  }
  if (meals.length < 4) return true;
  final uniqueCount = meals.toSet().length;
  final uniqueRatio = uniqueCount / meals.length;
  return uniqueRatio < .72;
}

bool _planHasBlankDays(Map<String, dynamic> plan) {
  final days = _list(plan['days_plan']).map(_map).toList();
  if (days.isEmpty) return true;
  return days.any((day) => _list(day['meals']).isEmpty);
}

List<String> _mealNamesForPlan(Map<String, dynamic> plan) {
  final names = <String>{};
  for (final day in _list(plan['days_plan']).map(_map)) {
    for (final meal in _list(day['meals']).map(_map)) {
      final name = _stringValue(meal['name'], '');
      if (name.isNotEmpty) names.add(name);
    }
  }
  return names.toList()..sort();
}

List<Map<String, dynamic>> _fallbackMealsForPlanDay(
  int dayNumber,
  List<Map<String, dynamic>> templateDays,
  Map<String, dynamic> plan,
) {
  if (templateDays.isEmpty) return const [];
  final repeatPreference = _stringValue(plan['repeat_preference'], '');
  final varietyMode = _stringValue(plan['variety_mode'], '');
  final templateDay = templateDays[(dayNumber - 1) % templateDays.length];
  final meals = _list(templateDay['meals']).map(_map).toList();
  final mostlyUnique =
      repeatPreference == 'Mostly unique' || varietyMode == 'More variety';
  return [
    for (var i = 0; i < meals.length; i++)
      {
        ...meals[i],
        if (mostlyUnique && dayNumber > 1)
          'name':
              '${_stringValue(meals[i]['name'], 'Meal')} - Day $dayNumber variation',
        'meal_id':
            'day${dayNumber}_${_stringValue(meals[i]['meal_type'], 'meal')}_${i + 1}',
        'is_eaten': false,
        'eaten_at': null,
        'generated_from_template': true,
      },
  ];
}

Map<String, dynamic> _normalizePlanMeal(
  int dayNumber,
  Map<String, dynamic> meal,
  int mealIndex,
) {
  final mealType = _stringValue(
    meal['meal_type'] ?? meal['mealType'],
    'meal${mealIndex + 1}',
  );
  final name = _stringValue(meal['name'] ?? meal['mealName'], 'Meal');
  final normalized = {
    ...meal,
    'meal_id': _stringValue(
      meal['meal_id'] ?? meal['mealId'],
      'day${dayNumber}_${mealType}_${mealIndex + 1}',
    ),
    'meal_type': mealType,
    'name': name,
    'is_eaten': meal['is_eaten'] == true || meal['isEaten'] == true,
    'eaten_at': meal['eaten_at'] ?? meal['eatenAt'],
  };
  return {...normalized, 'instructions': _instructionsForMeal(normalized)};
}

int _nextUneatenDayIndex(List<Map<String, dynamic>> days) {
  for (var index = 0; index < days.length; index++) {
    final meals = _list(days[index]['meals']).map(_map).toList();
    if (meals.isEmpty) return index;
    if (meals.any((meal) => meal['is_eaten'] != true)) return index;
  }
  return math.max(0, days.length - 1);
}

DateTime _dateForPlanDay(Map<String, dynamic> day) {
  return _parsePlanDate(day['day_date'] ?? day['dayDate']) ?? DateTime.now();
}

DateTime? _parsePlanDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

String _date(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatPlanDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]} ${months[date.month - 1]} ${date.day}';
}

String _mealIdFor(
  Map<String, dynamic> day,
  Map<String, dynamic> meal, {
  Map<String, dynamic>? fallback,
}) {
  final existing = _stringValue(
    meal['meal_id'] ?? meal['mealId'],
    _stringValue(fallback?['meal_id'] ?? fallback?['mealId'], ''),
  );
  if (existing.isNotEmpty) return existing;
  final dayNumber = _stringValue(day['day'], '1');
  final type = _stringValue(meal['meal_type'] ?? meal['mealType'], 'meal');
  final name = _stringValue(meal['name'] ?? meal['mealName'], 'meal')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'day${dayNumber}_${type}_$name';
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  return const [];
}

String _stringValue(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

List<String> _splitText(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _groceryText(Map<String, dynamic> list) {
  final buffer = StringBuffer(_stringValue(list['title'], 'Grocery List'));
  final categories = <String, List<Map<String, dynamic>>>{};
  for (final item in _list(list['items']).map(_map)) {
    categories
        .putIfAbsent(_stringValue(item['category'], 'Other'), () => [])
        .add(item);
  }
  for (final entry in categories.entries) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln(entry.key);
    for (final item in entry.value) {
      buffer.writeln(
        '- ${item['name']} ${_formatFactValue(_num(item['quantity']))} ${item['unit'] ?? ''}',
      );
    }
  }
  return buffer.toString();
}

String _groceryItemKey(Map<String, dynamic> item) {
  return '${item['category']}|${item['name']}|${item['unit']}';
}

List<Map<String, dynamic>> _sortMealsNewestFirst(
  Iterable<Map<String, dynamic>> meals,
) {
  final sorted = meals.toList();
  sorted.sort((a, b) {
    final aDate = DateTime.tryParse('${a['created_at']}');
    final bDate = DateTime.tryParse('${b['created_at']}');
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return sorted;
}

Map<String, dynamic>? _dashboardWithSortedMeals(
  Map<String, dynamic>? dashboard,
) {
  if (dashboard == null) return null;
  return {
    ...dashboard,
    'meals': _sortMealsNewestFirst(_list(dashboard['meals']).map(_map)),
  };
}

num _num(Object? value, {num fallback = 0}) {
  if (value is num) return value;
  return num.tryParse('$value') ?? fallback;
}

Map<String, dynamic> _nutritionWithItemFallback(
  Map<String, dynamic> meal,
  List<Map<String, dynamic>> items,
) {
  final nutrition = Map<String, dynamic>.from(meal);
  if (items.isEmpty) return nutrition;

  for (final key in _nutritionFactKeys) {
    final current = _num(nutrition[key]);
    if (current != 0) continue;
    nutrition[key] = items.fold<num>(0, (sum, item) => sum + _num(item[key]));
  }

  return nutrition;
}

String _mealItemPortionLabel(Map<String, dynamic> item) {
  final portion = _stringValue(item['portion_label'], '');
  if (portion.isNotEmpty) return portion;
  final raw = _map(item['raw_provider_payload']);
  final amount = item['amount'] ?? raw['amount'];
  final unit = _stringValue(item['unit'] ?? raw['unit'], '');
  if (amount != null && unit.isNotEmpty) {
    return '${_compactNum(amount)} $unit';
  }
  if (amount != null) return '${_compactNum(amount)} serving';
  return '1 serving';
}

String _emoji(String source) {
  return switch (source) {
    'photo' => '📷',
    'restaurant' => '🍔',
    'barcode' => '🏷️',
    _ => '🥗',
  };
}

String _formatFactValue(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _formatHistoryDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _formatWeightEntryDateTime(DateTime date) {
  return '${_formatWeightEntryDate(date)} at ${_formatWeightEntryTime(date)}';
}

String _formatWeightEntryDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatWeightEntryTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatHistoryMonth(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _userDisplayName(User? user) {
  final metadataName = user?.userMetadata?['display_name'];
  if (metadataName is String && metadataName.trim().isNotEmpty) {
    return metadataName.trim();
  }
  final emailName = user?.email?.split('@').first.trim();
  if (emailName != null && emailName.isNotEmpty) return emailName;
  return 'Nutrition User';
}

String _timeOfDayGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

Color _historyStatusColor(
  Map<String, dynamic> day,
  Map<String, dynamic> goals,
  HistoryMetric? metric,
) {
  if (metric == null) {
    return _historyDayHasEntries(day) ? AppColors.green : AppColors.line;
  }

  final value = _num(day[metric.key]);
  final goal = _num(goals[metric.key], fallback: metric.fallbackGoal);
  return _goalStatusColor(metric.key, value, goal, goals);
}

List<_HistoryLegendItem> _historyLegendItems(HistoryMetric metric) {
  final definition = _goalDefinition(metric.key, const {});
  switch (definition.direction) {
    case GoalDirection.minimum:
      return [
        _HistoryLegendItem(
          color: AppColors.green,
          label: 'Met ${metric.label}',
        ),
        const _HistoryLegendItem(color: AppColors.yellow, label: 'Close'),
        const _HistoryLegendItem(color: Colors.redAccent, label: 'Below'),
      ];
    case GoalDirection.maximum:
      return [
        _HistoryLegendItem(
          color: AppColors.green,
          label: 'Under ${metric.label}',
        ),
        const _HistoryLegendItem(color: AppColors.yellow, label: 'Near limit'),
        const _HistoryLegendItem(color: Colors.redAccent, label: 'Over'),
      ];
    case GoalDirection.target:
      return const [
        _HistoryLegendItem(color: AppColors.green, label: 'On target'),
        _HistoryLegendItem(color: AppColors.yellow, label: 'Close'),
        _HistoryLegendItem(color: Colors.redAccent, label: 'Off target'),
      ];
  }
}

double _goalProgress(num value, num goal) {
  if (goal <= 0) return 0;
  return (value / goal).clamp(0, 1).toDouble();
}

Color _goalStatusColor(
  String key,
  num value,
  num goal,
  Map<String, dynamic> goals,
) {
  if (goal <= 0) return AppColors.muted;
  final definition = _goalDefinition(key, goals);
  final tolerance = _goalTolerance(key, goal);
  switch (definition.direction) {
    case GoalDirection.minimum:
      if (value >= goal) return AppColors.green;
      if (goal - value <= tolerance) return AppColors.yellow;
      return Colors.redAccent;
    case GoalDirection.maximum:
      if (value <= goal) return AppColors.green;
      if (value - goal <= tolerance) return AppColors.yellow;
      return Colors.redAccent;
    case GoalDirection.target:
      final difference = (value - goal).abs();
      if (difference <= tolerance) return AppColors.green;
      if (difference <= tolerance * 2) return AppColors.yellow;
      return Colors.redAccent;
  }
}

GoalDefinition _goalDefinition(String key, Map<String, dynamic> goals) {
  if (key == 'calories') {
    final planName = goals['plan_name'];
    if (planName == 'Lose body fat') {
      return const GoalDefinition(GoalDirection.maximum, 'max');
    }
    if (planName == 'Gain muscle mass') {
      return const GoalDefinition(GoalDirection.minimum, 'min');
    }
    return const GoalDefinition(GoalDirection.target, 'target');
  }
  if (key == 'sugar' || key == 'sodium') {
    return const GoalDefinition(GoalDirection.maximum, 'max');
  }
  if (key == 'carbs' || key == 'fat') {
    return const GoalDefinition(GoalDirection.target, 'target');
  }
  return const GoalDefinition(GoalDirection.minimum, 'min');
}

num _goalTolerance(String key, num goal) {
  if (key == 'calories') return 100;
  if (key == 'sodium' || key == 'potassium') return 100;
  if (key.startsWith('vitamin_')) return 5;
  return 5;
}

String _goalInputLabel(String label, String key, Map<String, dynamic> goals) {
  return '$label (${_goalDefinition(key, goals).shortLabel})';
}

Map<String, num> _goalTargetsOnly(Map<String, num> values) {
  return {
    for (final key in [
      'calories',
      'protein',
      'carbs',
      'fat',
      'fiber',
      'sugar',
      'sodium',
      'potassium',
    ])
      if (values[key] != null) key: values[key]!,
  };
}

Map<String, num> _recommendedTargetsForProfile(
  String planName, {
  required num age,
  required num heightInches,
  required num weightPounds,
  required String gender,
  required String activityLevel,
  num? sevenDayWeightTrendPounds,
}) {
  final weightKg = weightPounds * 0.45359237;
  final heightCm = heightInches * 2.54;
  final bmrBase = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
  final genderKey = gender.toLowerCase();
  final bmr = genderKey == 'male'
      ? bmrBase + 5
      : genderKey == 'female'
      ? bmrBase - 161
      : bmrBase - 78;
  final tdee = bmr * _activityFactor(activityLevel);
  final calorieAdjustment = _goalCalorieAdjustmentPercent(planName);
  var calories = tdee * (1 + calorieAdjustment);
  calories = _adjustCaloriesForWeightTrend(
    calories,
    planName: planName,
    sevenDayTrendPounds: sevenDayWeightTrendPounds,
  ).clamp(1200, 5000).toDouble();

  final proteinPerPound = _goalProteinPerPound(planName);
  final protein = (weightPounds * proteinPerPound).clamp(60, 300);
  final fatPercent = _goalFatPercent(planName);
  final fat = ((calories * fatPercent) / 9).clamp(35, 140);
  final carbs = ((calories - (protein * 4) - (fat * 9)) / 4).clamp(75, 500);
  final fiber = ((calories / 1000) * 14).clamp(18, 70);
  final sugar = ((calories * .10) / 4).clamp(20, 90);
  final potassiumTarget = genderKey == 'male' ? 3400 : 2600;

  return {
    'calories': calories.round(),
    'protein': protein.round(),
    'carbs': carbs.round(),
    'fat': fat.round(),
    'fiber': fiber.round(),
    'sugar': sugar.round(),
    'sodium': 2300,
    'potassium': potassiumTarget,
    'bmr': bmr.round(),
    'tdee': tdee.round(),
    'calorie_adjustment_percent': (calorieAdjustment * 100).round(),
  };
}

num _goalCalorieAdjustmentPercent(String planName) {
  switch (planName) {
    case 'Lose body fat':
      return -.18;
    case 'Gain muscle mass':
      return .10;
    case 'Recomp':
    case 'Body recomposition':
      return -.05;
    case 'Maintain weight':
    case 'General health':
    default:
      return 0;
  }
}

num _goalProteinPerPound(String planName) {
  switch (planName) {
    case 'Lose body fat':
      return .9;
    case 'Gain muscle mass':
      return 1.0;
    case 'Maintain weight':
    case 'General health':
    default:
      return .8;
  }
}

num _goalFatPercent(String planName) {
  switch (planName) {
    case 'Lose body fat':
      return .25;
    case 'Gain muscle mass':
      return .22;
    case 'Recomp':
    case 'Body recomposition':
      return .25;
    case 'Maintain weight':
    case 'General health':
    default:
      return .28;
  }
}

num _adjustCaloriesForWeightTrend(
  num calories, {
  required String planName,
  num? sevenDayTrendPounds,
}) {
  if (sevenDayTrendPounds == null) return calories;
  if (planName == 'Lose body fat' && sevenDayTrendPounds >= -.25) {
    return calories - 100;
  }
  if (planName == 'Lose body fat' && sevenDayTrendPounds <= -2) {
    return calories + 100;
  }
  if (planName == 'Gain muscle mass' && sevenDayTrendPounds < .25) {
    return calories + 100;
  }
  if (planName == 'Gain muscle mass' && sevenDayTrendPounds > 1.25) {
    return calories - 100;
  }
  return calories;
}

num _activityFactor(String activityLevel) {
  switch (activityLevel) {
    case 'sedentary':
      return 1.2;
    case 'light':
      return 1.375;
    case 'active':
      return 1.725;
    case 'very_active':
    case 'very active':
      return 1.9;
    case 'moderate':
    default:
      return 1.55;
  }
}

String _activityLabel(String activityLevel) {
  switch (activityLevel) {
    case 'sedentary':
      return 'Low activity';
    case 'light':
      return 'Light activity';
    case 'active':
      return 'Active';
    case 'very_active':
    case 'very active':
      return 'Very active';
    case 'moderate':
    default:
      return 'Moderate activity';
  }
}

bool _historyDayHasEntries(Map<String, dynamic> day) {
  return _num(day['calories']) > 0 ||
      _num(day['protein']) > 0 ||
      _num(day['carbs']) > 0 ||
      _num(day['fat']) > 0 ||
      _num(day['fiber']) > 0 ||
      _num(day['sugar']) > 0;
}

int _trackingStreak(List<Map<String, dynamic>> series) {
  final daysByDate = {
    for (final day in series)
      if (DateTime.tryParse('${day['log_date']}') case final date?)
        _dateKey(date): day,
  };
  var date = DateTime.now();
  var streak = 0;
  while (true) {
    final day = daysByDate[_dateKey(date)];
    if (day == null || !_historyDayHasEntries(day)) return streak;
    streak++;
    date = date.subtract(const Duration(days: 1));
  }
}

List<TrackingWeekDay> _currentTrackingWeek(List<Map<String, dynamic>> series) {
  final daysByDate = {
    for (final day in series)
      if (DateTime.tryParse('${day['log_date']}') case final date?)
        _dateKey(date): day,
  };
  final today = DateTime.now();
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return [
    for (int i = 0; i < 7; i++)
      TrackingWeekDay(
        label: labels[i],
        date: weekStart.add(Duration(days: i)),
        tracked: _historyDayHasEntries(
          daysByDate[_dateKey(weekStart.add(Duration(days: i)))] ?? {},
        ),
        isToday: _dateKey(weekStart.add(Duration(days: i))) == _dateKey(today),
      ),
  ];
}

Map<String, num> _trackedDayAverages(List<Map<String, dynamic>> series) {
  final trackedDays = series.where(_historyDayHasEntries).toList();
  if (trackedDays.isEmpty) {
    return const {'calories': 0, 'protein': 0, 'carbs': 0};
  }

  num average(String key) {
    final total = trackedDays.fold<num>(0, (sum, day) => sum + _num(day[key]));
    return total / trackedDays.length;
  }

  return {
    'calories': average('calories'),
    'protein': average('protein'),
    'carbs': average('carbs'),
  };
}

Future<String?> _showProfileInputDialog({
  required BuildContext context,
  required String title,
  required String action,
  required TextEditingController controller,
  TextInputType? keyboardType,
  bool obscureText = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(labelText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(action),
          ),
        ],
      );
    },
  );
}

Future<PasswordUpdateInput?> _showPasswordUpdateDialog(BuildContext context) {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  return showDialog<PasswordUpdateInput>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Update password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              PasswordUpdateInput(
                currentPassword: current.text,
                newPassword: next.text,
                confirmPassword: confirm.text,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

Future<BodyProfileInput?> _showBodyProfileUpdateDialog(
  BuildContext context,
  Map<String, dynamic> profile,
) {
  final age = TextEditingController(
    text: _num(profile['age']) > 0
        ? _num(profile['age']).round().toString()
        : '',
  );
  final heightInches = TextEditingController(
    text: _num(profile['height_cm']) > 0
        ? (_num(profile['height_cm']) / 2.54).round().toString()
        : '',
  );
  final weightPounds = TextEditingController(
    text: _num(profile['weight_kg']) > 0
        ? (_num(profile['weight_kg']) / 0.45359237).round().toString()
        : '',
  );
  var gender = '${profile['gender'] ?? 'female'}';
  var activityLevel = '${profile['activity_level'] ?? 'moderate'}';

  return showDialog<BodyProfileInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Body profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: age,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: heightInches,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (in)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightPounds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (lb)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _profileOptionValue(gender, const [
                      'female',
                      'male',
                      'other',
                    ], 'female'),
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => gender = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _profileOptionValue(activityLevel, const [
                      'sedentary',
                      'light',
                      'moderate',
                      'active',
                      'very_active',
                    ], 'moderate'),
                    decoration: const InputDecoration(labelText: 'Activity'),
                    items: const [
                      DropdownMenuItem(value: 'sedentary', child: Text('Low')),
                      DropdownMenuItem(value: 'light', child: Text('Light')),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'very_active',
                        child: Text('Very active'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => activityLevel = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  BodyProfileInput(
                    age: age.text,
                    heightInches: heightInches.text,
                    weightPounds: weightPounds.text,
                    gender: gender,
                    activityLevel: activityLevel,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _ageLabel(Map<String, dynamic> profile) {
  final age = _num(profile['age']);
  return age > 0 ? '${age.round()}' : 'Not set';
}

String _heightLabel(Map<String, dynamic> profile) {
  final heightCm = _num(profile['height_cm']);
  if (heightCm <= 0) return 'Not set';
  final heightInches = (heightCm / 2.54).round();
  final feet = heightInches ~/ 12;
  final inches = heightInches % 12;
  return '$feet ft $inches in';
}

String _weightLabel(Map<String, dynamic> profile) {
  final weightKg = _num(profile['weight_kg']);
  if (weightKg <= 0) return 'Not set';
  return '${(weightKg / 0.45359237).round()} lb';
}

String _formatWeightPounds(num weightKg) {
  final pounds = weightKg / 0.45359237;
  return _compactNum(pounds);
}

String _genderLabel(String gender) {
  switch (gender) {
    case 'female':
      return 'Female';
    case 'male':
      return 'Male';
    case 'other':
      return 'Other';
    default:
      return 'Not set';
  }
}

String _profileOptionValue(
  String value,
  List<String> options,
  String fallback,
) {
  return options.contains(value) ? value : fallback;
}

HistoryMetric _historyMetric(String key) {
  return _historyMetrics.firstWhere(
    (metric) => metric.key == key,
    orElse: () => _historyMetrics.first,
  );
}

GoalPlan? _selectedGoalPlan(String? name) {
  if (name == null) return null;
  for (final plan in _goalPlans) {
    if (plan.name == name) return plan;
  }
  return null;
}

class HistoryMetric {
  const HistoryMetric({
    required this.key,
    required this.label,
    required this.unit,
    required this.color,
    required this.fallbackGoal,
  });

  final String key;
  final String label;
  final String unit;
  final Color color;
  final num fallbackGoal;
}

class GoalPlan {
  const GoalPlan({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.values,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Map<String, num> values;
}

class TrackingWeekDay {
  const TrackingWeekDay({
    required this.label,
    required this.date,
    required this.tracked,
    required this.isToday,
  });

  final String label;
  final DateTime date;
  final bool tracked;
  final bool isToday;
}

class PasswordUpdateInput {
  const PasswordUpdateInput({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
}

class BodyProfileInput {
  const BodyProfileInput({
    required this.age,
    required this.heightInches,
    required this.weightPounds,
    required this.gender,
    required this.activityLevel,
  });

  final String age;
  final String heightInches;
  final String weightPounds;
  final String gender;
  final String activityLevel;
}

enum GoalDirection { minimum, maximum, target }

class GoalDefinition {
  const GoalDefinition(this.direction, this.shortLabel);

  final GoalDirection direction;
  final String shortLabel;
}

const _historyMetrics = [
  HistoryMetric(
    key: 'protein',
    label: 'Protein',
    unit: 'g',
    color: AppColors.green,
    fallbackGoal: 150,
  ),
  HistoryMetric(
    key: 'carbs',
    label: 'Carbs',
    unit: 'g',
    color: AppColors.yellow,
    fallbackGoal: 250,
  ),
  HistoryMetric(
    key: 'fat',
    label: 'Fat',
    unit: 'g',
    color: AppColors.violet,
    fallbackGoal: 70,
  ),
  HistoryMetric(
    key: 'fiber',
    label: 'Fiber',
    unit: 'g',
    color: AppColors.green,
    fallbackGoal: 30,
  ),
  HistoryMetric(
    key: 'sugar',
    label: 'Sugar',
    unit: 'g',
    color: AppColors.orange,
    fallbackGoal: 50,
  ),
];

const _goalPlans = [
  GoalPlan(
    name: 'Lose body fat',
    description: 'Higher protein, controlled calories, steady fiber.',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.orange,
    values: {
      'calories': 1800,
      'protein': 160,
      'carbs': 150,
      'fat': 55,
      'fiber': 35,
      'sugar': 35,
      'sodium': 2200,
      'potassium': 3400,
    },
  ),
  GoalPlan(
    name: 'Gain muscle mass',
    description: 'Calorie surplus with more carbs and high protein.',
    icon: Icons.fitness_center_rounded,
    color: AppColors.violet,
    values: {
      'calories': 2800,
      'protein': 180,
      'carbs': 340,
      'fat': 85,
      'fiber': 30,
      'sugar': 60,
      'sodium': 2300,
      'potassium': 3600,
    },
  ),
  GoalPlan(
    name: 'Maintain weight',
    description: 'Balanced macros for consistent day-to-day tracking.',
    icon: Icons.balance_rounded,
    color: AppColors.green,
    values: {
      'calories': 2200,
      'protein': 150,
      'carbs': 250,
      'fat': 70,
      'fiber': 30,
      'sugar': 50,
      'sodium': 2300,
      'potassium': 3400,
    },
  ),
];

const _nutritionFactKeys = [
  'calories',
  'protein',
  'carbs',
  'fat',
  'fiber',
  'sugar',
  'vitamin_a',
  'vitamin_b_complex',
  'vitamin_c',
  'vitamin_d',
  'vitamin_e',
  'vitamin_k',
  'iron',
  'calcium',
  'magnesium',
  'sodium',
  'potassium',
  'zinc',
];

const _vitaminFacts = [
  ('Vitamin A', 'vitamin_a', AppColors.orange),
  ('B Complex', 'vitamin_b_complex', AppColors.violet),
  ('Vitamin C', 'vitamin_c', AppColors.yellow),
  ('Vitamin D', 'vitamin_d', AppColors.green),
  ('Vitamin E', 'vitamin_e', Colors.teal),
  ('Vitamin K', 'vitamin_k', Colors.lightGreen),
];

const _mineralFacts = [
  ('Iron', 'iron', AppColors.violet, 100, '%'),
  ('Calcium', 'calcium', Colors.cyan, 100, '%'),
  ('Magnesium', 'magnesium', Colors.indigo, 100, '%'),
  ('Sodium', 'sodium', Colors.redAccent, 2300, 'mg'),
  ('Potassium', 'potassium', AppColors.green, 3400, 'mg'),
  ('Zinc', 'zinc', Colors.blueGrey, 100, '%'),
];
