import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const nutrientKeys = [
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

class NutritionRepository {
  NutritionRepository(this.client);

  final SupabaseClient client;

  String get userId => client.auth.currentUser!.id;

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => client.auth.signOut();

  Future<void> updateEmail(String email) async {
    await client.auth.updateUser(UserAttributes(email: email));
  }

  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> updatePasswordWithCurrent({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw StateError('No signed-in email found.');
    }
    await client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Map<String, dynamic>> dashboard([DateTime? date]) async {
    final result = await client.rpc(
      'get_dashboard',
      params: {'target_date': _date(date ?? DateTime.now())},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> history({int days = 7}) async {
    final result = await client.rpc('get_history', params: {'day_count': days});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> goals() async {
    final rows = await client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) {
      final inserted = await client
          .from('goals')
          .insert({'user_id': userId})
          .select()
          .single();
      return Map<String, dynamic>.from(inserted);
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> updateGoals(Map<String, num> values, {String? planName}) async {
    await client.from('goals').upsert({
      'user_id': userId,
      ...values,
      'plan_name': planName,
      'setup_completed': true,
    }, onConflict: 'user_id');
  }

  Future<void> resetAllData() async {
    final photoRows = await client
        .from('meals')
        .select('image_path')
        .eq('user_id', userId)
        .not('image_path', 'is', null);
    final imagePaths = photoRows
        .map((row) => row['image_path'])
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();

    await client.from('daily_logs').delete().eq('user_id', userId);
    await client.from('user_weight_entries').delete().eq('user_id', userId);
    await client.from('goals').delete().eq('user_id', userId);

    if (imagePaths.isNotEmpty) {
      try {
        await client.storage.from('meal-photos').remove(imagePaths);
      } catch (_) {
        // The database reset should still succeed if old photo files are gone.
      }
    }
  }

  Future<void> logWeight({required num weightPounds}) async {
    final weightKg = weightPounds * 0.45359237;
    await client.from('user_weight_entries').insert({
      'user_id': userId,
      'weight_kg': weightKg,
    });
    await updateAssistantProfile({'weight_kg': weightKg});
  }

  Future<void> updateTargetWeight(num targetWeightPounds) async {
    await updateAssistantProfile({
      'target_weight_kg': targetWeightPounds * 0.45359237,
    });
  }

  Future<void> updateWeightEntry({
    required String id,
    required num weightPounds,
    DateTime? loggedAt,
  }) async {
    final weightKg = weightPounds * 0.45359237;
    final updates = <String, dynamic>{'weight_kg': weightKg};
    if (loggedAt != null) {
      updates['logged_at'] = loggedAt.toUtc().toIso8601String();
    }
    await client
        .from('user_weight_entries')
        .update(updates)
        .eq('user_id', userId)
        .eq('id', id);
    await _syncCurrentWeightFromLatestEntry();
  }

  Future<void> deleteWeightEntry(String id) async {
    await client
        .from('user_weight_entries')
        .delete()
        .eq('user_id', userId)
        .eq('id', id);
    await _syncCurrentWeightFromLatestEntry();
  }

  Future<Map<String, dynamic>> weightMetrics() async {
    final profileRows = await client
        .from('user_nutrition_profiles')
        .select('weight_kg,target_weight_kg')
        .eq('user_id', userId)
        .limit(1);
    final rows = await client
        .from('user_weight_entries')
        .select()
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .limit(90);
    final entries = [
      for (final row in rows.reversed) Map<String, dynamic>.from(row),
    ];
    return {
      'profile': profileRows.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(profileRows.first),
      'entries': entries,
    };
  }

  Future<void> _syncCurrentWeightFromLatestEntry() async {
    final rows = await client
        .from('user_weight_entries')
        .select('weight_kg')
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .limit(1);
    await updateAssistantProfile({
      'weight_kg': rows.isEmpty ? null : rows.first['weight_kg'],
    });
  }

  Future<void> deleteMeal(Map<String, dynamic> meal) async {
    final mealId = '${meal['id']}';
    final dailyLogId = '${meal['daily_log_id']}';
    final imagePath = meal['image_path'];

    await client
        .from('meal_items')
        .delete()
        .eq('user_id', userId)
        .eq('meal_id', mealId);
    await client.from('meals').delete().eq('user_id', userId).eq('id', mealId);
    await client.rpc(
      'recalculate_daily_totals',
      params: {'target_daily_log_id': dailyLogId},
    );

    if (imagePath is String && imagePath.isNotEmpty) {
      await client.storage.from('meal-photos').remove([imagePath]);
    }
  }

  Future<void> logTextFood(String description, {DateTime? date}) async {
    await _logFood(
      source: 'text',
      rawInput: description,
      date: date,
      parsed: await analyzeTextFood(description),
    );
  }

  Future<void> logRestaurantFood(String description, {DateTime? date}) async {
    await _logFood(
      source: 'restaurant',
      rawInput: description,
      date: date,
      parsed: await analyzeRestaurantFood(description),
    );
  }

  Future<ParsedFood> analyzeTextFood(String description) {
    return _parseFoodWithAi(source: 'text', description: description);
  }

  Future<ParsedFood> analyzeRestaurantFood(String description) {
    return _parseFoodWithAi(source: 'restaurant', description: description);
  }

  Future<ParsedFood> analyzeBarcodeFood(String code) {
    return _parseFoodWithAi(
      source: 'barcode',
      description: code,
      barcode: code,
    );
  }

  Future<ParsedFood> analyzePhotoFood({
    required Uint8List bytes,
    required String extension,
    String? caption,
  }) {
    return _parseFoodWithAi(
      source: 'photo',
      description: caption?.trim().isEmpty ?? true ? 'Food photo' : caption!,
      imageBase64: base64Encode(bytes),
      imageMimeType: 'image/$extension',
    );
  }

  Future<void> logPhotoFood({
    required Uint8List bytes,
    required String extension,
    DateTime? date,
    String? caption,
  }) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('meal-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: false,
          ),
        );
    await _logFood(
      source: 'photo',
      rawInput: caption?.trim().isEmpty ?? true
          ? 'Food photo'
          : caption!.trim(),
      imagePath: path,
      date: date,
      parsed: await analyzePhotoFood(
        bytes: bytes,
        extension: extension,
        caption: caption,
      ),
    );
  }

  Future<void> saveReviewedMeal({
    required ParsedFood parsed,
    required String source,
    required String rawInput,
    DateTime? date,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    String? imagePath;
    if (imageBytes != null && imageExtension != null) {
      imagePath =
          '$userId/${DateTime.now().microsecondsSinceEpoch}.$imageExtension';
      await client.storage
          .from('meal-photos')
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: 'image/$imageExtension',
              upsert: false,
            ),
          );
    }
    await _logFood(
      source: source,
      rawInput: rawInput,
      imagePath: imagePath,
      date: date,
      parsed: parsed,
    );
  }

  Future<void> updateReviewedMeal({
    required Map<String, dynamic> meal,
    required ParsedFood parsed,
    required String source,
    required String rawInput,
  }) async {
    final mealId = '${meal['id']}';
    final dailyLogId = '${meal['daily_log_id']}';
    await client
        .from('meals')
        .update({
          'meal_type': parsed.mealType,
          'source': source,
          'title': parsed.mealName,
          'raw_input': rawInput,
          'confidence': parsed.confidence,
        })
        .eq('user_id', userId)
        .eq('id', mealId);

    await client
        .from('meal_items')
        .delete()
        .eq('user_id', userId)
        .eq('meal_id', mealId);
    await client.from('meal_items').insert([
      for (final item in parsed.items)
        {
          'user_id': userId,
          'meal_id': mealId,
          'name': item.name,
          'normalized_query': item.query,
          'portion_label': item.portionLabel,
          'serving_grams': item.servingGrams,
          'provider': item.provider,
          'provider_food_id': item.providerFoodId,
          'confidence': item.confidence,
          ...item.nutrition,
          'raw_provider_payload': item.rawProviderPayload,
        },
    ]);
    await client.rpc(
      'recalculate_daily_totals',
      params: {'target_daily_log_id': dailyLogId},
    );
  }

  Future<String> logMealPlanMeal(
    Map<String, dynamic> plannedMeal, {
    required DateTime date,
  }) async {
    final log = await _dailyLog(date);
    final mealName = _string(
      plannedMeal['name'] ?? plannedMeal['mealName'],
      fallback: 'Planned meal',
    );
    final mealType = _mealTypeForDb(
      _string(
        plannedMeal['meal_type'] ?? plannedMeal['mealType'],
        fallback: 'snack',
      ),
    );
    final meal = await client
        .from('meals')
        .insert({
          'user_id': userId,
          'daily_log_id': log['id'],
          'meal_type': mealType,
          'source': 'manual',
          'title': mealName,
          'raw_input': 'Meal plan: $mealName',
          'confidence': 1,
        })
        .select()
        .single();

    final nutrition = {
      for (final key in nutrientKeys) key: _number(plannedMeal[key]),
    };
    await client.from('meal_items').insert({
      'user_id': userId,
      'meal_id': meal['id'],
      'name': mealName,
      'normalized_query': mealName.toLowerCase(),
      'portion_label': _string(
        plannedMeal['serving_size'] ?? plannedMeal['servingSize'],
        fallback: '1 serving',
      ),
      'serving_grams': _number(
        plannedMeal['serving_grams'] ?? plannedMeal['servingGrams'],
        fallback: 100,
      ),
      'provider': 'meal_plan',
      'provider_food_id': _string(
        plannedMeal['meal_id'] ?? plannedMeal['mealId'],
        fallback: 'planned-meal',
      ),
      'confidence': 1,
      ...nutrition,
      'raw_provider_payload': {
        'source': 'meal_plan',
        'was_ai_estimated': true,
        'meal_plan_meal': plannedMeal,
      },
    });
    return '${meal['id']}';
  }

  Future<Map<String, dynamic>> assistantProfile(
    Map<String, dynamic> goals,
  ) async {
    final rows = await client
        .from('user_nutrition_profiles')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
    final inserted = await client
        .from('user_nutrition_profiles')
        .insert({
          'user_id': userId,
          'goal_type': goals['plan_name'] ?? 'Maintain weight',
          'calorie_target': goals['calories'],
          'protein_target': goals['protein'],
          'carb_target': goals['carbs'],
          'fat_target': goals['fat'],
          'fiber_target': goals['fiber'],
          'sugar_limit': goals['sugar'],
          'sodium_target': goals['sodium'],
          'potassium_target': goals['potassium'],
        })
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> updateAssistantProfile(Map<String, dynamic> values) async {
    await client.from('user_nutrition_profiles').upsert({
      'user_id': userId,
      ...values,
    }, onConflict: 'user_id');
  }

  Future<Map<String, dynamic>> foodPreferences() async {
    final rows = await client
        .from('user_food_preferences')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
    final inserted = await client
        .from('user_food_preferences')
        .insert({'user_id': userId})
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> saveFoodPreference({
    required String food,
    required String preference,
  }) async {
    final current = await foodPreferences();
    final liked = _stringList(current['liked_foods']).toSet();
    final disliked = _stringList(current['disliked_foods']).toSet();
    final neutral = _stringList(current['neutral_foods']).toSet();
    liked.remove(food);
    disliked.remove(food);
    neutral.remove(food);
    if (preference == 'liked') {
      liked.add(food);
    } else if (preference == 'disliked') {
      disliked.add(food);
    } else {
      neutral.add(food);
    }
    await client.from('user_food_preferences').upsert({
      'user_id': userId,
      'liked_foods': liked.toList()..sort(),
      'disliked_foods': disliked.toList()..sort(),
      'neutral_foods': neutral.toList()..sort(),
    }, onConflict: 'user_id');
  }

  Future<List<Map<String, dynamic>>> chatMessages() async {
    final rows = await client
        .from('ai_chat_messages')
        .select()
        .eq('user_id', userId)
        .eq('context_type', 'general_chat')
        .order('created_at', ascending: true)
        .limit(60);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  Future<Map<String, dynamic>> askAssistant({
    required String action,
    String? message,
    Map<String, dynamic>? request,
    Map<String, dynamic>? food,
    Map<String, dynamic>? mealPlan,
    Map<String, dynamic>? dashboard,
    Map<String, dynamic>? goals,
  }) async {
    final resolvedGoals = goals ?? await this.goals();
    final context = {
      'goals': resolvedGoals,
      'dashboard': dashboard ?? await this.dashboard(),
      'profile': await assistantProfile(resolvedGoals),
      'preferences': await foodPreferences(),
      'chat_history': action == 'general_chat' ? await chatMessages() : [],
    };

    if (action == 'general_chat' &&
        message != null &&
        message.trim().isNotEmpty) {
      await _saveChatMessage('user', message.trim(), action);
    }

    final response = await client.functions.invoke(
      'ai-assistant',
      body: {
        'action': action,
        'message': message,
        'request': request,
        'food': food,
        'meal_plan': mealPlan,
        'context': context,
      },
    );
    if (response.status >= 400) {
      throw StateError('AI assistant failed: ${response.data}');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final assistantText = data['message'];
    if (action == 'general_chat' && assistantText is String) {
      await _saveChatMessage('assistant', assistantText, action);
    }
    return data;
  }

  Future<Map<String, dynamic>> saveMealPlan(Map<String, dynamic> plan) async {
    final inserted = await client
        .from('meal_plans')
        .insert({
          'user_id': userId,
          'title': plan['title'] ?? 'AI Meal Plan',
          'goal_type': plan['goal_type'],
          'days': plan['days'] ?? 1,
          'meals_per_day': plan['meals_per_day'] ?? 3,
          'household_size': plan['household_size'] ?? 1,
          'total_calories': _sumDaily(plan, 'calories'),
          'total_protein': _sumDaily(plan, 'protein'),
          'total_carbs': _sumDaily(plan, 'carbs'),
          'total_fat': _sumDaily(plan, 'fat'),
          'plan': plan,
        })
        .select()
        .single();
    final mealPlanId = inserted['id'];
    final days = _list(plan['days_plan']);
    if (days.isNotEmpty) {
      await client.from('meal_plan_days').insert([
        for (final day in days)
          {
            'user_id': userId,
            'meal_plan_id': mealPlanId,
            'day_index': _number((day as Map)['day'], fallback: 1),
            'title': 'Day ${(day)['day'] ?? 1}',
            'meals': day['meals'] ?? [],
            'totals': _dailyTotalForPlan(plan, day['day']),
          },
      ]);
    }
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> deleteMealPlan(String id) async {
    await client.from('meal_plans').delete().eq('user_id', userId).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> mealPlans() async {
    final rows = await client
        .from('meal_plans')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  Future<void> updateMealPlan(String id, Map<String, dynamic> plan) async {
    await client
        .from('meal_plan_days')
        .delete()
        .eq('user_id', userId)
        .eq('meal_plan_id', id);
    await client
        .from('meal_plans')
        .update({
          'title': plan['title'] ?? 'AI Meal Plan',
          'goal_type': plan['goal_type'],
          'days': plan['days'] ?? 1,
          'meals_per_day': plan['meals_per_day'] ?? 3,
          'household_size': plan['household_size'] ?? 1,
          'total_calories': _sumDaily(plan, 'calories'),
          'total_protein': _sumDaily(plan, 'protein'),
          'total_carbs': _sumDaily(plan, 'carbs'),
          'total_fat': _sumDaily(plan, 'fat'),
          'plan': plan,
        })
        .eq('user_id', userId)
        .eq('id', id);
    final days = _list(plan['days_plan']);
    if (days.isNotEmpty) {
      await client.from('meal_plan_days').insert([
        for (final day in days)
          {
            'user_id': userId,
            'meal_plan_id': id,
            'day_index': _number((day as Map)['day'], fallback: 1),
            'title': 'Day ${(day)['day'] ?? 1}',
            'meals': day['meals'] ?? [],
            'totals': _dailyTotalForPlan(plan, day['day']),
          },
      ]);
    }
  }

  Future<Map<String, dynamic>> generateMealPlan({
    required Map<String, dynamic> request,
    Map<String, dynamic>? dashboard,
    Map<String, dynamic>? goals,
  }) {
    return askAssistant(
      action: 'meal_plan',
      request: request,
      dashboard: dashboard,
      goals: goals,
    );
  }

  Future<Map<String, dynamic>> regenerateMeal({
    required Map<String, dynamic> mealPlan,
    required Map<String, dynamic> meal,
    required Map<String, dynamic> request,
    Map<String, dynamic>? dashboard,
    Map<String, dynamic>? goals,
  }) {
    return askAssistant(
      action: 'regenerate_meal',
      request: request,
      food: meal,
      mealPlan: mealPlan,
      dashboard: dashboard,
      goals: goals,
    );
  }

  Future<Map<String, dynamic>> saveGroceryList(
    Map<String, dynamic> list, {
    String? mealPlanId,
  }) async {
    final inserted = await client
        .from('grocery_lists')
        .insert({
          'user_id': userId,
          'meal_plan_id': mealPlanId,
          'title': list['title'] ?? 'Grocery List',
          'items': list['items'] ?? [],
          'export_payload': list,
        })
        .select()
        .single();
    final items = _list(list['items']);
    if (items.isNotEmpty) {
      await client.from('grocery_list_items').insert([
        for (final item in items)
          {
            'user_id': userId,
            'grocery_list_id': inserted['id'],
            'name': (item as Map)['name'] ?? 'Item',
            'quantity': _number(item['quantity']),
            'unit': item['unit'],
            'category': item['category'] ?? 'Other',
            'linked_meals': _stringList(item['linked_meals']),
          },
      ]);
    }
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> clearChatMessages() async {
    await client
        .from('ai_chat_messages')
        .delete()
        .eq('user_id', userId)
        .eq('context_type', 'general_chat');
  }

  Future<void> _saveChatMessage(
    String role,
    String content,
    String contextType,
  ) async {
    await client.from('ai_chat_messages').insert({
      'user_id': userId,
      'role': role,
      'content': content,
      'context_type': contextType,
    });
  }

  Future<void> _logFood({
    required String source,
    required String rawInput,
    required ParsedFood parsed,
    String? imagePath,
    DateTime? date,
  }) async {
    final log = await _dailyLog(date ?? DateTime.now());
    final meal = await client
        .from('meals')
        .insert({
          'user_id': userId,
          'daily_log_id': log['id'],
          'meal_type': parsed.mealType,
          'source': source,
          'title': parsed.mealName,
          'raw_input': rawInput,
          'image_path': imagePath,
          'confidence': parsed.confidence,
        })
        .select()
        .single();

    await client.from('meal_items').insert([
      for (final item in parsed.items)
        {
          'user_id': userId,
          'meal_id': meal['id'],
          'name': item.name,
          'normalized_query': item.query,
          'portion_label': item.portionLabel,
          'serving_grams': item.servingGrams,
          'provider': item.provider,
          'provider_food_id': item.providerFoodId,
          'confidence': item.confidence,
          ...item.nutrition,
          'raw_provider_payload': item.rawProviderPayload,
        },
    ]);
  }

  Future<ParsedFood> _parseFoodWithAi({
    required String source,
    required String description,
    String? barcode,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final response = await client.functions.invoke(
      'parse-food',
      body: {
        'source': source,
        'description': description,
        'barcode': ?barcode,
        'image_base64': ?imageBase64,
        'image_mime_type': ?imageMimeType,
      },
    );

    if (response.status >= 400) {
      throw StateError('AI food parsing failed: ${response.data}');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    return ParsedFood.fromJson(data);
  }

  Future<Map<String, dynamic>> _dailyLog(DateTime date) async {
    final logDate = _date(date);
    final rows = await client
        .from('daily_logs')
        .select()
        .eq('user_id', userId)
        .eq('log_date', logDate)
        .limit(1);
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
    final inserted = await client
        .from('daily_logs')
        .insert({'user_id': userId, 'log_date': logDate})
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }
}

class ParsedFood {
  const ParsedFood({
    required this.mealName,
    required this.mealType,
    required this.confidence,
    required this.needsReview,
    required this.items,
  });

  final String mealName;
  final String mealType;
  final double confidence;
  final bool needsReview;
  final List<FoodMatch> items;

  factory ParsedFood.fromJson(Map<String, dynamic> json) {
    final items = [
      for (final item in _list(json['items']))
        FoodMatch.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    return ParsedFood(
      mealName: _string(
        json['meal_name'] ?? json['mealName'],
        fallback: items.isEmpty
            ? 'Reviewed Meal'
            : items.map((item) => item.name).join(', '),
      ),
      mealType: _string(json['meal_type'], fallback: 'lunch'),
      confidence: _double(json['confidence'], fallback: .7),
      needsReview: json['needs_review'] == true || json['needsReview'] == true,
      items: items,
    );
  }

  Map<String, num> get totals {
    return {
      for (final key in nutrientKeys)
        key: items.fold<num>(0, (sum, item) => sum + item.nutrition[key]!),
    };
  }

  ParsedFood copyWith({
    String? mealName,
    String? mealType,
    double? confidence,
    bool? needsReview,
    List<FoodMatch>? items,
  }) {
    return ParsedFood(
      mealName: mealName ?? this.mealName,
      mealType: mealType ?? this.mealType,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      items: items ?? this.items,
    );
  }
}

class FoodMatch {
  const FoodMatch({
    required this.name,
    required this.query,
    required this.portionLabel,
    required this.amount,
    required this.unit,
    required this.servingGrams,
    required this.provider,
    required this.providerFoodId,
    required this.confidence,
    required this.confidenceLabel,
    required this.alternatives,
    required this.clarifyingQuestion,
    required this.nutrition,
    required this.rawProviderPayload,
  });

  final String name;
  final String query;
  final String portionLabel;
  final num amount;
  final String unit;
  final num servingGrams;
  final String provider;
  final String providerFoodId;
  final double confidence;
  final String confidenceLabel;
  final List<String> alternatives;
  final String? clarifyingQuestion;
  final Map<String, num> nutrition;
  final Map<String, dynamic> rawProviderPayload;

  factory FoodMatch.fromJson(Map<String, dynamic> json) {
    final amount = _number(json['amount'], fallback: 1);
    final unit = _string(json['unit'], fallback: '');
    final portionLabel = _string(
      json['portion_label'],
      fallback: unit.isEmpty ? '$amount serving' : '$amount $unit',
    );
    final confidence = _double(json['confidence'], fallback: .7);
    return FoodMatch(
      name: _string(json['name'], fallback: 'Unknown Food'),
      query: _string(json['normalized_query'], fallback: 'unknown food'),
      portionLabel: portionLabel,
      amount: amount,
      unit: unit.isEmpty ? _unitFromPortionLabel(portionLabel) : unit,
      servingGrams: _number(json['serving_grams'], fallback: 100),
      provider: _string(json['provider'], fallback: 'gemini'),
      providerFoodId: _string(
        json['provider_food_id'],
        fallback: 'gemini-food',
      ),
      confidence: confidence,
      confidenceLabel: _confidenceLabel(json['confidence_level'], confidence),
      alternatives: _stringList(json['alternatives']),
      clarifyingQuestion: json['clarifying_question'] is String
          ? (json['clarifying_question'] as String).trim()
          : json['clarifyingQuestion'] is String
          ? (json['clarifyingQuestion'] as String).trim()
          : null,
      nutrition: {for (final key in nutrientKeys) key: _number(json[key])},
      rawProviderPayload: {
        'model': 'gemini-3.1-flash-lite',
        'amount': amount,
        'unit': unit,
        'was_ai_estimated': true,
        if (json['alternatives'] is List) 'alternatives': json['alternatives'],
        if (json['clarifying_question'] is String)
          'clarifying_question': json['clarifying_question'],
        if (json['raw_provider_payload'] is Map)
          ...Map<String, dynamic>.from(json['raw_provider_payload'] as Map),
      },
    );
  }

  FoodMatch copyWith({
    String? name,
    String? query,
    String? portionLabel,
    num? amount,
    String? unit,
    num? servingGrams,
    String? provider,
    String? providerFoodId,
    double? confidence,
    String? confidenceLabel,
    List<String>? alternatives,
    String? clarifyingQuestion,
    Map<String, num>? nutrition,
    Map<String, dynamic>? rawProviderPayload,
  }) {
    final resolvedAmount = amount ?? this.amount;
    final resolvedUnit = unit ?? this.unit;
    return FoodMatch(
      name: name ?? this.name,
      query: query ?? this.query,
      portionLabel: portionLabel ?? _portionLabel(resolvedAmount, resolvedUnit),
      amount: resolvedAmount,
      unit: resolvedUnit,
      servingGrams: servingGrams ?? this.servingGrams,
      provider: provider ?? this.provider,
      providerFoodId: providerFoodId ?? this.providerFoodId,
      confidence: confidence ?? this.confidence,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      alternatives: alternatives ?? this.alternatives,
      clarifyingQuestion: clarifyingQuestion ?? this.clarifyingQuestion,
      nutrition: nutrition ?? this.nutrition,
      rawProviderPayload: rawProviderPayload ?? this.rawProviderPayload,
    );
  }
}

String _date(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _mealTypeForDb(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized == 'breakfast' ||
      normalized == 'lunch' ||
      normalized == 'dinner' ||
      normalized == 'snack') {
    return normalized;
  }
  return 'snack';
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  return const [];
}

String _string(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

num _number(Object? value, {num fallback = 0}) {
  if (value is num) return value;
  return num.tryParse('$value') ?? fallback;
}

double _double(Object? value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

String _confidenceLabel(Object? value, double score) {
  final label = '$value'.toLowerCase().trim();
  if (label == 'high' || label == 'medium' || label == 'low') return label;
  if (score >= .8) return 'high';
  if (score >= .6) return 'medium';
  return 'low';
}

String _portionLabel(num amount, String unit) {
  final amountText = amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();
  return unit.trim().isEmpty ? '$amountText serving' : '$amountText $unit';
}

String _unitFromPortionLabel(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return 'serving';
  return parts.skip(1).join(' ');
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }
  return const [];
}

num _sumDaily(Map<String, dynamic> plan, String key) {
  return _list(
    plan['daily_totals'],
  ).fold<num>(0, (sum, item) => sum + _number((item as Map)[key]));
}

Map<String, dynamic> _dailyTotalForPlan(
  Map<String, dynamic> plan,
  Object? day,
) {
  for (final total in _list(plan['daily_totals'])) {
    final mapped = Map<String, dynamic>.from(total as Map);
    if ('${mapped['day']}' == '$day') return mapped;
  }
  return {};
}
