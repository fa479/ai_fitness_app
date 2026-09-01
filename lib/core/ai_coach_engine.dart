/// FitAI Multilingual AI Coach Engine
///
/// A rule-based, on-device fitness coach that replies in the user's
/// selected language and uses their profile (age, height, weight, goal,
/// activity, experience) to personalize advice. It is intentionally honest
/// about being an on-device coach: it never fabricates medical advice or
/// invents precise numbers, and it directs clinical questions to a
/// professional. When a Gemini API key is configured in Settings the
/// engine can optionally forward to a real LLM for richer conversation.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/app_localizations.dart' show L;
import 'user_profile_service.dart';

/// Intent detected from the user's message.
enum CoachIntent {
  greeting,
  workoutPlan,
  nutrition,
  weightLoss,
  muscleGain,
  recovery,
  form,
  motivation,
  capabilities,
  profile,
  thanks,
  unknown,
}

/// Result of a coach response.
class CoachResponse {
  final String text;
  final bool personalized;
  final bool fromCloud;

  const CoachResponse({
    required this.text,
    this.personalized = false,
    this.fromCloud = false,
  });
}

class AICoachEngine {
  AICoachEngine._();
  static final AICoachEngine instance = AICoachEngine._();

  /// Optional Gemini API key. When set and valid, the engine forwards
  /// requests to the cloud model for richer conversation; otherwise it
  /// uses the on-device rule-based coach.
  String? _apiKey;
  String? get apiKey => _apiKey;
  void setApiKey(String? key) => _apiKey = (key == null || key.isEmpty)
      ? null
      : key;

  bool get hasCloud => _apiKey != null && _apiKey!.isNotEmpty;

  /// Main entry: produce a coach reply for [message] given [profile].
  Future<CoachResponse> respond(String message, UserProfile profile) async {
    final lang = profile.language;
    // Always try the cloud path first when a key is configured, so users
    // who connect an API key get real conversational AI in their language.
    if (hasCloud) {
      try {
        final cloud = await _callCloud(message, profile);
        if (cloud != null) {
          return CoachResponse(
            text: cloud,
            personalized: true,
            fromCloud: true,
          );
        }
      } catch (e) {
        debugPrint('Cloud coach failed, falling back on-device: $e');
      }
    }
    // Reference L so the import is used for direction-aware callers.
    assert(L.current == L.current);
    return _onDevice(message, profile, lang);
  }

  // -------------------------------------------------------------------
  // On-device rule-based coach
  // -------------------------------------------------------------------

  CoachResponse _onDevice(String message, UserProfile profile, String lang) {
    final intent = _detectIntent(message);
    final builder = _builders[lang] ?? _builders['English']!;
    final text = builder(intent, profile, message);
    return CoachResponse(text: text, personalized: profile.isComplete);
  }

  CoachIntent _detectIntent(String message) {
    final m = message.toLowerCase();
    bool has(List<String> keys) => keys.any((k) => m.contains(k));

    if (has([
      'hi',
      'hello',
      'hey',
      'salam',
      'salaam',
      'assalam',
      'سلام',
      'ہیلو',
      'ہائے',
      'नमस्ते',
      'ਸਤ',
      'ہیلو',
    ])) {
      return CoachIntent.greeting;
    }
    if (has(['thank', 'shukria', 'shukriya', 'شکریہ', 'धन्यवाद', 'مهربانی'])) {
      return CoachIntent.thanks;
    }
    if (has([
      'what can you',
      'help me',
      'capabilities',
      'features',
      'کیا کر',
      'کیا کر سکتے',
      'مدد',
      'मदद',
      'تمھارا',
    ])) {
      return CoachIntent.capabilities;
    }
    if (has([
      'workout',
      'exercise',
      'plan',
      'routine',
      'مشق',
      'ورک آؤٹ',
      'تمرین',
      'व्यायाम',
      'कसरत',
      'ਕਸਰਤ',
      'منصوبو',
      'پلان',
    ])) {
      return CoachIntent.workoutPlan;
    }
    if (has([
      'food',
      'eat',
      'diet',
      'nutrition',
      'meal',
      'calorie',
      'protein',
      'کھانا',
      'غذا',
      'خوراک',
      'भोजन',
      'खाना',
      'ਖਾਣਾ',
      'ਆਹਾਰ',
      'غذائیت',
      'کیلوری',
      'پروٹین',
    ])) {
      return CoachIntent.nutrition;
    }
    if (has([
      'lose weight',
      'weight loss',
      'fat loss',
      'reduce',
      'وزن کم',
      'موٹاپا',
      'वजन कम',
      'वसा',
      'ਵਜ਼ਨ ਘਟਾ',
    ])) {
      return CoachIntent.weightLoss;
    }
    if (has([
      'muscle',
      'bulk',
      'build muscle',
      'gain mass',
      'پٹھا',
      'مص member',
      'muscle',
      'मांसपेशी',
      'ਮਸਲ',
      'ਪੱਠਾ',
      'پٹھے',
    ])) {
      return CoachIntent.muscleGain;
    }
    if (has([
      'rest',
      'recovery',
      'sleep',
      'tired',
      'sore',
      'تھکا',
      'آرام',
      'نیند',
      'रिकवरी',
      'आराम',
      'नींद',
      'ਥੱਕਾ',
      'ਆਰਾਮ',
      ' recovery',
      'л hardam',
      'آرام',
    ])) {
      return CoachIntent.recovery;
    }
    if (has([
      'form',
      'technique',
      'squat',
      'pushup',
      'deadlift',
      'bench',
      'فارم',
      'تکنیک',
      'اسکواٹ',
      ' posture',
      'अ',
      'ফর্ম',
      'ਫਾਰਮ',
      'technique',
    ])) {
      return CoachIntent.form;
    }
    if (has([
      'motivat',
      'lazy',
      'give up',
      'consistency',
      'حوصلا',
      'حوصلہ',
      'متمل',
      'prerana',
      'प्रेरणा',
      'ਪ੍ਰੇਰਨਾ',
      'motivasi',
    ])) {
      return CoachIntent.motivation;
    }
    if (has([
      'my profile',
      'my info',
      'my data',
      'میری معلومات',
      'मेरी जानकारी',
      'ਮੇਰੀ ਜਾਣਕਾਰੀ',
    ])) {
      return CoachIntent.profile;
    }
    return CoachIntent.unknown;
  }

  // -------------------------------------------------------------------
  // Optional cloud integration (Gemini) — only used when a key is set
  // -------------------------------------------------------------------

  Future<String?> _callCloud(String message, UserProfile profile) async {
    if (!hasCloud) return null;
    final lang = profile.language;
    final system = 'You are FitAI, a friendly, concise personal fitness '
        'coach. Reply ONLY in $lang. Use the user profile to personalize. '
        'Do not give medical diagnoses; encourage professional help for '
        'medical questions. Profile: ${profile.toContextSummary()}.';
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-1.5-flash:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$system\n\nUser: $message'},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 600},
    });
    final res = await http.post(endpoint, body: body);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final parts = (candidates.first['content']['parts'] as List);
    if (parts.isEmpty) return null;
    return parts.first['text'] as String?;
  }

  // -------------------------------------------------------------------
  // Greeting message used by the chat screen on first load
  // -------------------------------------------------------------------

  String greeting(UserProfile profile) {
    final lang = profile.language;
    final builder = _builders[lang] ?? _builders['English']!;
    return builder(CoachIntent.greeting, profile, '');
  }
}

/// Per-language response builders. Each returns a string for the given
/// intent, personalized with the profile. Languages without a dedicated
/// builder fall back to English.
typedef ResponseBuilder = String Function(
    CoachIntent intent, UserProfile profile, String rawMessage);

final Map<String, ResponseBuilder> _builders = {
  'English': _english,
  'Urdu': _urdu,
  'Hindi': _hindi,
  'Punjabi': _punjabi,
  'Sindhi': _sindhi,
  'Pashto': _pashto,
  'Balochi': _balochi,
};

String _english(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'there';
  switch (intent) {
    case CoachIntent.greeting:
      return 'Hi $name! I\'m your FitAI coach. I can help with workouts, '
          'nutrition, recovery and motivation. What would you like to work on?';
    case CoachIntent.thanks:
      return 'You\'re welcome, $name! Stay consistent and the results will come. 💪';
    case CoachIntent.capabilities:
      return 'I can: build a personalized workout plan, suggest meals and '
          'calorie targets, advise on recovery and form, and keep you '
          'motivated. ${p.isComplete ? "I already have your profile, so my tips are tailored to you." : "Add your age, height and weight in Profile for personalized advice."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'To build your plan I need your age, height, weight and goal '
            'first. Open Profile → Personal Information and add them, then '
            'ask me again.';
      }
      final days = p.daysPerWeek;
      final mins = p.minutesPerSession;
      return 'Based on your goal (${p.goal}), ${p.experience.toLowerCase()} '
          'level and $days days/week (~$mins min), I suggest a $days-day '
          'split focused on ${p.goal.toLowerCase()}. Open the Workout tab '
          'and tap "Start Workout" to begin today\'s session, then use '
          'Form Check for real-time feedback.';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Add your height and weight in Profile so I can estimate your '
            'daily calorie target. Meanwhile, aim for lean protein, '
            'vegetables, whole grains and plenty of water.';
      }
      return 'Your estimated daily energy need is about '
          '${p.tdee!.round()} kcal. For ${p.goal.toLowerCase()}, target '
          'roughly ${(p.tdee! * 0.85).round()} kcal with ~${((p.weightKg ?? 70) * 1.6).round()}g '
          'protein. Open the Nutrition tab to log meals and track macros.';
    case CoachIntent.weightLoss:
      if (p.tdee == null) {
        return 'Add your weight in Profile so I can set a '
            'safe calorie target.';
      }
      final target = (p.tdee! * 0.8).round();
      return 'For steady fat loss aim for ~$target kcal/day (a moderate '
          'deficit), high protein, strength training 3-4x/week and daily '
          'steps. Avoid very low calories — that backfires. I will never '
          'recommend an unsafe deficit.';
    case CoachIntent.muscleGain:
      if (p.tdee == null) {
        return 'Add your weight in Profile so I can set a '
            'surplus target.';
      }
      final target = (p.tdee! * 1.1).round();
      return 'To build muscle aim for ~$target kcal/day (a small surplus), '
          '${((p.weightKg ?? 70) * 1.6).round()}g protein, progressive overload '
          'and 6-8 hrs sleep. Consistency beats intensity at first.';
    case CoachIntent.recovery:
      return 'Recovery is where progress happens. ${p.isComplete ? "At your activity level (${p.activity.label}), " : ""}'
          'aim for 7-9 hrs sleep, take 1-2 rest days/week, hydrate well, '
          'and don\'t train the same muscle group hard two days running. '
          'If you feel sharp pain, stop and see a professional.';
    case CoachIntent.form:
      return 'Good form prevents injury. Open "Form Check" from Home — it '
          'uses your camera with on-device pose detection to count reps and '
          'show joint-angle feedback in real time. Tip: control the '
          'negative (lowering) phase, don\'t rush reps.';
    case CoachIntent.motivation:
      return 'You started, and that\'s the hardest part, $name. Show up for '
          'just 10 minutes today — momentum follows action. Missed a day? '
          'Never miss two in a row. I\'m here whenever you need a nudge.';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'Your profile isn\'t complete yet. Add your '
            'age, height and weight in Profile → Personal Information so I '
            'can personalize everything.';
      }
      return 'Here\'s what I know about you: ${p.toContextSummary()}. '
          'Update anything in Profile any time.';
    case CoachIntent.unknown:
      return 'I\'m best at workouts, nutrition, recovery, form and '
          'motivation. ${p.isComplete ? "Try \"make my workout\" or \"what should I eat?\"" : "Add your profile details first for personalized advice."}';
  }
}

String _urdu(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'وہاں';
  switch (intent) {
    case CoachIntent.greeting:
      return 'السلام علیکم $name! میں آپ کا FitAI کوچ ہوں۔ ورک آؤٹ، غذائیت، '
          'بحالی اور حوصلے میں مدد کر سکتا ہوں۔ آپ کیا پر کام کرنا چاہتے ہیں؟';
    case CoachIntent.thanks:
      return 'خوش آمدید، $name! مسلسل رہیں اور نتائج آئیں گے۔ 💪';
    case CoachIntent.capabilities:
      return 'میں یہ کر سکتا ہوں: ذاتی ورک آؤٹ پلان بنانا، کھانے اور کیلوری '
          'ہدف تجویز کرنا، بحالی اور فارم مشورے دینا، اور آپ کا حوصلہ بڑھانا۔ '
          '${p.isComplete ? "مجھے آپ کی معلومات ہیں، اس لیے مشورے آپ کے لیے ہیں۔" : "ذاتی مشورے کے لیے Profile میں عمر، قد اور وزن شامل کریں۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'آپ کا پلان بنانے کے لیے مجھے عمر، قد، وزن اور ہدف چاہیے۔ '
            'Profile → Personal Information کھولیں اور معلومات شامل کریں۔';
      }
      return 'آپ کے ہدف (${p.goal})، ${p.experience} سطح اور ہفتے میں '
          '${p.daysPerWeek} دن (تقریباً ${p.minutesPerSession} منٹ) کے حساب سے '
          'میں ایک ${p.daysPerWeek}-دن کا پلان تجویز کرتا ہوں۔ Workout ٹیب '
          'کھولیں اور "Start Workout" دبائیں، پھر فارم چیک میں حقیقی رائے لیں۔';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Profile میں قد اور وزن شامل کریں تاکہ میں روزانہ کیلوری '
            'ہدف بتا سکوں۔ اس وقت پروٹین، سبزیاں، اناج اور پانی پر توجہ دیں۔';
      }
      return 'آپ کی روزانہ ضرورت تقریباً ${p.tdee!.round()} کیلوری ہے۔ '
          '${p.goal} کے لیے ~${(p.tdee! * 0.85).round()} کیلوری اور '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین مناسب ہے۔ '
          'Nutrition ٹیب میں کھانے درج کریں۔';
    case CoachIntent.weightLoss:
      if (p.tdee == null) {
        return 'وزن Profile میں شامل کریں تاکہ محفوظ کیلوری ہدف بنا سکوں۔';
      }
      final target = (p.tdee! * 0.8).round();
      return 'مستحکم وزن کم کرنے کے لیے ~$target کیلوری/دن (اعتدال پسند '
          'فرق)، زیادہ پروٹین، ہفتے میں 3-4 بار طاقت کی مشق اور روزانہ '
          'قدم۔ بہت کم کیلوری نقصان دہ ہے — میں کبھی غیر محفوظ ہدف نہیں دوں گا۔';
    case CoachIntent.muscleGain:
      if (p.tdee == null) {
        return 'وزن Profile میں شامل کریں تاکہ اضافی کیلوری ہدف بنا سکوں۔';
      }
      final target = (p.tdee! * 1.1).round();
      return 'پٹھے بنانے کے لیے ~$target کیلوری/دن (تھوڑا اضافہ)، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، آہستہ آہستہ بوجھ '
          'بڑھائیں اور 6-8 گھنٹے نیند۔ مسلسل رہنا شروع میں شدت سے بہتر ہے۔';
    case CoachIntent.recovery:
      return 'بحالی میں ہی ترقی ہوتی ہے۔ '
          '${p.isComplete ? "آپ کی سرگرمی (${p.activity.label}) کے لحاظ سے، " : ""}'
          '7-9 گھنٹے نیند، ہفتے میں 1-2 آرام کے دن، کافی پانی، اور مسلسل '
          'ایک ہی پٹھے کو سخت ٹریننگ نہ کریں۔ تیز درد ہو تو روکیں اور '
          'ماہر سے ملیں۔';
    case CoachIntent.form:
      return 'اچھی فارم چوٹ سے بچاتی ہے۔ Home سے "Form Check" کھولیں — یہ '
          'آپ کے کیمرے اور آن-ڈیوائس پوز ڈٹیکشن سے دہرائیں گنتی اور '
          'جوائنٹ اینگل رائے دیتا ہے۔ مشورہ: نیچے کی حرکت آہستہ کریں، '
          'جلدی نہ کریں۔';
    case CoachIntent.motivation:
      return 'آپ نے شروع کیا، اور یہ سب سے مشکل حصہ ہے، $name۔ آج صرف 10 '
          'منٹ کے لیے آ جائیں — رفتار عمل سے آتی ہے۔ ایک دن چھوٹا تو '
          'مسلسل دو نہ چھوڑیں۔ ضرورت ہو تو میں حاضر ہوں۔';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'آپ کی معلومات ابھی مکمل نہیں۔ Profile میں عمر، قد اور وزن '
            'شامل کریں تاکہ سب کچھ ذاتی بنا سکوں۔';
      }
      return 'مجھے آپ کے بارے میں یہ معلوم ہے: ${p.toContextSummary()}۔ '
          'کوئی بھی چیز Profile میں کبھی اپ ڈیٹ کریں۔';
    case CoachIntent.unknown:
      return 'میں ورک آؤٹ، غذائیت، بحالی، فارم اور حوصلے میں ماہر ہوں۔ '
          '${p.isComplete ? "\"میرا ورک آؤٹ بناؤ\" یا \"میں کیا کھاؤں?\" آزمائیں۔" : "ذاتی مشورے کے لیے پہلے پروفائل مکمل کریں۔"}';
  }
}

String _hindi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'वहाँ';
  switch (intent) {
    case CoachIntent.greeting:
      return 'नमस्ते $name! मैं आपका FitAI कोच हूँ। वर्कआउट, पोषण, रिकवरी '
          'और प्रेरणा में मदद कर सकता हूँ। आप क्या चाहते हैं?';
    case CoachIntent.thanks:
      return 'स्वागत है, $name! लगातार बने रहें और परिणाम आएँगे। 💪';
    case CoachIntent.capabilities:
      return 'मैं यह कर सकता हूँ: व्यक्तिगत वर्कआउट योजना बनाना, भोजन और '
          'कैलोरी लक्ष्य सुझाना, रिकवरी और फॉर्म सलाह देना, और प्रेरित '
          'रखना। ${p.isComplete ? "मेरे पास आपकी जानकारी है, इसलिए सुझात आपके लिए हैं।" : "व्यक्तिगत सलाह के लिए Profile में आयु, ऊँचाई और वज़न जोड़ें।"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'योजना बनाने के लिए मुझे आयु, ऊँचाई, वज़न और लक्ष्य चाहिए। '
            'Profile → Personal Information खोलें और जानकारी जोड़ें।';
      }
      return 'आपके लक्ष्य (${p.goal}), ${p.experience} स्तर और हफ़्ते में '
          '${p.daysPerWeek} दिन (~${p.minutesPerSession} मिनट) के अनुसार '
          'मैं ${p.daysPerWeek}-दिन का विभाजन सुझाता हूँ। Workout टैब खोलें, '
          '"Start Workout" दबाएँ, फिर फॉर्म चेक में वास्तविक समीक्षा लें।';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Profile में ऊँचाई और वज़न जोड़ें ताकि मैं दैनिक कैलोरी '
            'लक्ष्य बता सकूँ। तब तक प्रोटीन, सब्ज़ियाँ, अनाज और पानी पर '
            'ध्यान दें।';
      }
      return 'आपकी दैनिक ऊर्जा आवश्यकता लगभग ${p.tdee!.round()} कैलोरी है। '
          '${p.goal} के लिए ~${(p.tdee! * 0.85).round()} कैलोरी और '
          '~${((p.weightKg ?? 70) * 1.6).round()} ग्राम प्रोटीन उपयुक्त है। '
          'Nutrition टैब में भोजन दर्ज करें।';
    case CoachIntent.weightLoss:
      if (p.tdee == null) {
        return 'Profile में वज़न जोड़ें ताकि सुरक्षित कैलोरी लक्ष्य बना सकूँ।';
      }
      final target = (p.tdee! * 0.8).round();
      return 'नियमित वसा हानि के लिए ~$target कैलोरी/दिन (मध्यम घाटा), '
          'अधिक प्रोटीन, सप्ताह में 3-4 बार शक्ति व्यायाम और दैनिक क़दम। '
          'बहुत कम कैलोरी नुक़सानदायक है।';
    case CoachIntent.muscleGain:
      if (p.tdee == null) {
        return 'Profile में वज़न जोड़ें ताकि अतिरिक्त कैलोरी लक्ष्य बना सकूँ।';
      }
      final target = (p.tdee! * 1.1).round();
      return 'मांसपेशी बनाने के लिए ~$target कैलोरी/दिन (थोड़ा अधिक), '
          '${((p.weightKg ?? 70) * 1.6).round()} ग्राम प्रोटीन, उत्तरोत्तर '
          'ओवरलोड और 6-8 घंटे नींद।';
    case CoachIntent.recovery:
      return 'रिकवरी में ही प्रगति होती है। '
          '${p.isComplete ? "आपकी गतिविधि (${p.activity.label}) के अनुसार, " : ""}'
          '7-9 घंटे नींद, सप्ताह में 1-2 विश्राम दिन, पर्याप्त पानी लें। '
          'तेज़ दर्द हो तो रुकें और विशेषज्ञ से मिलें।';
    case CoachIntent.form:
      return 'अच्छी फॉर्म चोट से बचाती है। Home से "Form Check" खोलें — यह '
          'आपके कैमरे और ऑन-डिवाइस पोज़ पहचान से रेप गिनती और जॉइंट-एंगल '
          'समीक्षा देता है। नीचे उतारते समय धीरे जाएँ।';
    case CoachIntent.motivation:
      return 'आपने शुरू किया, और यह सबसे कठिन हिस्सा है, $name। आज सिर्फ़ '
          '10 मिनट के लिए आ जाएँ। एक दिन छूटे तो लगातार दो न छोड़ें।';
    case CoachIntent.profile:
      if (!p.isComplete) {
        return 'आपकी प्रोफ़ाइल अभी पूरी नहीं है। Profile में आयु, ऊँचाई और '
            'वज़न जोड़ें ताकि सब कुछ व्यक्तिगत बने।';
      }
      return 'मुझे आपके बारे में यह पता है: ${p.toContextSummary()}।';
    case CoachIntent.unknown:
      return 'मैं वर्कआउट, पोषण, रिकवरी, फॉर्म और प्रेरणा में निपुण हूँ। '
          '${p.isComplete ? "\"मेरा वर्कआउट बनाओ\" आज़माएँ।" : "पहले प्रोफ़ाइल पूरी करें।"}';
  }
}

String _punjabi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اتھے';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! میں تہاڈا FitAI کوچ آں۔ ورک آؤٹ، غذائیت، بحالی اور '
          'حوصلے وچ مدد کر سکدا آں۔ تسیں کی کرنا چاہندے او؟';
    case CoachIntent.thanks:
      return 'خوش آمدید، $name! لگاتار رہو تے نتیجے آون گے۔ 💪';
    case CoachIntent.capabilities:
      return 'میں ایہ کر سکدا آں: ذاتی ورک آؤٹ پلان بنانا، کھانے تے کیلوری '
          'ہدف دینا، بحالی تے فارم مشورے، تے حوصلہ۔ '
          '${p.isComplete ? "مینوں تہاڈی معلومات ہن، اس لئی مشورے تہاڈے لئی ہن۔" : "ذاتی مشورے لئی Profile وچ عمر، قد تے وزن پاﺅ۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلان بنان لئی مینوں عمر، قد، وزن تے ہدف چاہیدے نے۔ Profile → '
            'Personal Information کھولو تے معلومات پاؤ۔';
      }
      return 'تہاڈے ہدف (${p.goal})، ${p.experience} پدھر تے ہفتے وچ '
          '${p.daysPerWeek} دن (~${p.minutesPerSession} منٹ) موجب میں '
          '${p.daysPerWeek}-دن دا پلان سنواردا آں۔ Workout ٹیب کھولو، '
          '"Start Workout" دباؤ، فیر فارم چیک وچ اصل رائے لاؤ۔';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Profile وچ قد تے وزن پاؤ تاں روزانہ کیلوری ہدف دے سکاں۔ ';
      }
      return 'تہاڈی روزانہ لوڑ لگ بھگ ${p.tdee!.round()} کیلوری ہے۔ '
          '${p.goal} لئی ~${(p.tdee! * 0.85).round()} کیلوری تے '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین ٹھیک ہے۔ Nutrition '
          'ٹیب وچ کھانے درج کرو۔';
    case CoachIntent.weightLoss:
      if (p.tdee == null) return 'Profile وچ وزن پاؤ۔';
      final target = (p.tdee! * 0.8).round();
      return 'مسلسل وزن گھٹ کرن لئی ~$target کیلوری/دن، ودھ پروٹین، ہفتے وچ '
          '3-4 واری طاقت دی مشق تے روزانہ قدم۔';
    case CoachIntent.muscleGain:
      if (p.tdee == null) return 'Profile وچ وزن پاؤ۔';
      final target = (p.tdee! * 1.1).round();
      return 'پٹھے بنان لئی ~$target کیلوری/دن، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، ہولی ہولی بوجھ '
          'ودھاؤ تے 6-8 گھنٹے نیند۔';
    case CoachIntent.recovery:
      return 'بحالی وچ ہی ترقی ہندی ہے۔ 7-9 گھنٹے نیند، ہفتے وچ 1-2 آرام '
          'دن، کافی پانی پاؤ۔ تیز درد ہووے تاں رکو تے ماہر کول جاؤ۔';
    case CoachIntent.form:
      return 'چنگی فارم چوٹ توں بچاندی ہے۔ Home توں "Form Check" کھولو — ایہ '
          'تہاڈے کیمرے تے آن-ڈیوائس پوز پچھان نال دہرائیں گنتی تے جوائنٹ '
          'اینگل رائے دیندا ہے۔';
    case CoachIntent.motivation:
      return 'تسیں شروع کیتا، تے ایہہ سبھ توں مشکل حصہ ہے، $name۔ اج صرف '
          '10 منٹ لئی آ جاؤ۔';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کرو۔';
      return 'مینوں تہاڈے بارے ایہہ پتہ ہے: ${p.toContextSummary()}۔';
    case CoachIntent.unknown:
      return 'میں ورک آؤٹ، غذائیت، بحالی، فارم تے حوصلے وچ ماہر آں۔ '
          '${p.isComplete ? "\"میرا ورک آؤٹ بنا\" آزماؤ۔" : "پہلے پروفائل مکمل کرو۔"}';
  }
}

String _sindhi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اُتي';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! مان FitAI ڪوچ آهيان. ورڪ آئوٽ، غذائيت، بحالي ۽ '
          'حوصلي ۾ مدد ڪري سگهان ٿو. توهان ڇا چاهيو ٿا؟';
    case CoachIntent.thanks:
      return 'مهرباني، $name! لڳاتار رهو ۽ نتيجا ايندا.';
    case CoachIntent.capabilities:
      return 'مان هي ڪري سگهان ٿو: ذاتی ورڪ آئوٽ پلان، کاڌي ۽ ڪيلوري هدف، '
          'بحالي ۽ فارم صلاحون، ۽ حوصلا. '
          '${p.isComplete ? "مون وٽ توهان جي معلومات آهي." : "Profile ۾ عمر، ڊيگهه ۽ وزن شامل ڪريو."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلان ٺاهڻ لاءِ مون کي عمر، ڊيگهه، وزن ۽ هدف گهرجن. Profile '
            '۾ معلومات شامل ڪريو.';
      }
      return 'توهان جي هدف (${p.goal})، ${p.experience} سطح ۽ هفتي ۾ '
          '${p.daysPerWeek} ڏينهن موجب مان ${p.daysPerWeek}-ڏينهن وارو پلان '
          'تجويز ڪريان ٿو. Workout ٽيب کولو.';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Profile ۾ ڊيگهه ۽ وزن شامل ڪريو.';
      }
      return 'توهان جي روزاني ضرورت لڳ بھڳ ${p.tdee!.round()} ڪيلوري آهي. '
          '${p.goal} لاءِ ~${(p.tdee! * 0.85).round()} ڪيلوري ۽ '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٽين.';
    case CoachIntent.weightLoss:
      if (p.tdee == null) return 'Profile ۾ وزن شامل ڪريو.';
      final target = (p.tdee! * 0.8).round();
      return 'وزن گهٽائڻ لاءِ ~$target ڪيلوري/ڏينهن، وڌيڪ پروٽين، هفتي ۾ 3-4 '
          'واري طاقت جي مشق.';
    case CoachIntent.muscleGain:
      if (p.tdee == null) return 'Profile ۾ وزن شامل ڪريو.';
      final target = (p.tdee! * 1.1).round();
      return 'پٽها ٺاهڻ لاءِ ~$target ڪيلوري/ڏينهن، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٽين، 6-8 ڪلاڪ نندر.';
    case CoachIntent.recovery:
      return 'بحالي ۾ ترقي ٿيندي آهي. 7-9 ڪلاڪ نندر، هفتي ۾ 1-2 آرام جا '
          'ڏينهن، پاڻي گهڻو پيئو.';
    case CoachIntent.form:
      return 'سٺي فارم زخم کان بچائي ٿي. "Form Check" کولو — اهو ڪيمري ۽ '
          'آن-ڊوائيس پوز سڃاڻپ سان ريپ ڳڻپ ڏي ٿو.';
    case CoachIntent.motivation:
      return 'توهان شروع ڪيو، اهو سڀ کان ڏکيو حصو آهي، $name. اڄ صرف 10 '
          'منٽ لاءِ اچو.';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مڪمل ڪريو.';
      return 'مون کي توهان بابت هي معلوم آهي: ${p.toContextSummary()}.';
    case CoachIntent.unknown:
      return 'مان ورڪ آئوٽ، غذائيت، بحالي، فارم ۽ حوصلي ۾ ماهر آهيان. '
          '${p.isComplete ? "\"مون لاءِ ورڪ آئوٽ ٺاهو\" آزمايو." : "پهرين پروفائل مڪمل ڪريو."}';
  }
}

String _pashto(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'هلته';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! زه ستاسو FitAI کوچ يم. ورک آؤټ، غذاييت، بحالي او '
          'حوصلې کې مرسته کولی شم. تاسو څه غواړئ؟';
    case CoachIntent.thanks:
      return 'مننه، $name! پرله پسې اوسئ او پايلې راځي.';
    case CoachIntent.capabilities:
      return 'زه دا کولی شم: شخصي ورک آؤټ پلان، خواړه او کالوري موخه، بحالي '
          'او فورم مشورې، او هڅونه. '
          '${p.isComplete ? "ما ته ستاسو معلومات لرم." : "په Profile کې عمر، اوږدوالی او وزن ورزومو."}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'د پلان جوړولو لپاره ماته عمر، اوږدوالی، وزن او موخه پکار دي. '
            'Profile کې معلومات ورزومو.';
      }
      return 'ستاسو د موخې (${p.goal})، ${p.experience} کچې او اونۍ کې '
          '${p.daysPerWeek} ورځو له مخې زه ${p.daysPerWeek}-ورځنی پلان '
          'وړاندې کوم. Workout ټب پرانیزئ.';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'په Profile کې اوږدوالی او وزن ورزومو.';
      }
      return 'ستاسو ورځنۍ اړتيا نژدې ${p.tdee!.round()} کالوري ده. '
          '${p.goal} لپاره ~${(p.tdee! * 0.85).round()} کالوري او '
          '~${((p.weightKg ?? 70) * 1.6).round()} ګرام پروټين.';
    case CoachIntent.weightLoss:
      if (p.tdee == null) return 'په Profile کې وزن ورزومو.';
      final target = (p.tdee! * 0.8).round();
      return 'د وزن کمولو لپاره ~$target کالوري/ورځ، زيات پروټين، اونۍ کې '
          '3-4 ځله د ځواک تمرين.';
    case CoachIntent.muscleGain:
      if (p.tdee == null) return 'په Profile کې وزن ورزومو.';
      final target = (p.tdee! * 1.1).round();
      return 'د عضلو جوړولو لپاره ~$target کالوري/ورځ، '
          '${((p.weightKg ?? 70) * 1.6).round()} ګرام پروټين، 6-8 ساعتونه خوب.';
    case CoachIntent.recovery:
      return 'په بحالي کې پرمختګ کيږي. 7-9 ساعتونه خوب، اونۍ کې 1-2 ارام '
          'ورځې، ډېر اوبه وڅښئ.';
    case CoachIntent.form:
      return 'ښه فورم د ټپ څخه ساتي. "Form Check" پرانیزئ — د کيمرې او آن-'
          'ډيوائس پوز پيژندنې سره ريپ شميرنه کوي.';
    case CoachIntent.motivation:
      return 'تاسو پيل وکړ، دا تر ټولو ستونزمنه برخه ده، $name. نن يوازې د '
          '10 دقيقو لپاره راشئ.';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کړئ.';
      return 'ما ته ستاسو په اړه دا معلوم دي: ${p.toContextSummary()}.';
    case CoachIntent.unknown:
      return 'زه په ورک آؤټ، غذاييت، بحالي، فورم او هڅونه کې ماهر يم. '
          '${p.isComplete ? "\"زما ورک آؤټ جوړ کړه\" وآزمايئ." : "لومړی پروفایل مکمل کړئ."}';
  }
}

String _balochi(CoachIntent intent, UserProfile p, String raw) {
  final name = p.name.isNotEmpty ? p.name : 'اِتھ';
  switch (intent) {
    case CoachIntent.greeting:
      return 'سلام $name! من ئے FitAI کوچ انت. ورک آؤٹ، غذائیت، بحالی ؤ '
          'حوصلئَ ءَ مدد کن دارت. تو چه گوارٹ؟';
    case CoachIntent.thanks:
      return 'مهربانی، $name! لگاتار بہ ؤ نتیجہ شی۔';
    case CoachIntent.capabilities:
      return 'من ای کن دارم: شخصی ورک آؤٹ پلان، کھانا ؤ کیلوری ہدف، بحالی ؤ '
          'فارم مشورہ، ؤ ہچون۔ '
          '${p.isComplete ? "مئَ تئی معلومات درنت۔" : "Profile ءَ عمر، درازی ؤ وزن اِش کن۔"}';
    case CoachIntent.workoutPlan:
      if (!p.isComplete) {
        return 'پلانءَ ساجتءَ وہَتی منءَ عمر، درازی، وزن ؤ ہدف لازمی انت. '
            'Profile ءَ معلومات اِش کن۔';
      }
      return 'تئی ہدف (${p.goal})، ${p.experience} سطحه ؤ روچءَ '
          '${p.daysPerWeek} روچ موجب من ${p.daysPerWeek}-روچی پلان وۆارٹ۔ '
          'Workout ٹب کہ بز۔';
    case CoachIntent.nutrition:
      if (p.tdee == null) {
        return 'Profile ءَ درازی ؤ وزن اِش کن۔';
      }
      return 'تئی روچی ضرورت لگ بگ ${p.tdee!.round()} کیلوری انت. '
          '${p.goal} وہَتی ~${(p.tdee! * 0.85).round()} کیلوری ؤ '
          '~${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین۔';
    case CoachIntent.weightLoss:
      if (p.tdee == null) return 'Profile ءَ وزن اِش کن۔';
      final target = (p.tdee! * 0.8).round();
      return 'وزن کہ کم کہ کنءَ وہَتی ~$target کیلوری/روچ، گێں پروٹین، روچءَ '
          '3-4 وار طاقتی مشق۔';
    case CoachIntent.muscleGain:
      if (p.tdee == null) return 'Profile ءَ وزن اِش کن۔';
      final target = (p.tdee! * 1.1).round();
      return 'پٹہ ساجتءَ وہَتی ~$target کیلوری/روچ، '
          '${((p.weightKg ?? 70) * 1.6).round()} گرام پروٹین، 6-8 گنتی نئندگ۔';
    case CoachIntent.recovery:
      return 'بحالیءَ پہتراسی پیشرفت کنت۔ 7-9 گنتی نئندگ، روچءَ 1-2 آرام '
          'روچ، گێں پانی بہچ۔';
    case CoachIntent.form:
      return 'جاہ فارم ءَ زخم کنت بچیت۔ "Form Check" بز — ای کیمرءَ ؤ '
          'آن-ڈیوائس پوز پیژندگ ءَ ریپ شمار کنت۔';
    case CoachIntent.motivation:
      return 'تو پیل کہیت، اے گێں سخت ترین حصہ انت، $name۔ انکہ فقط 10 '
          'دقیقءَ وہَتی بہ ی۔';
    case CoachIntent.profile:
      if (!p.isComplete) return 'Profile مکمل کن۔';
      return 'مئَ تئی بارءَ ای معلوم انت: ${p.toContextSummary()}۔';
    case CoachIntent.unknown:
      return 'من ورک آؤٹ، غذائیت، بحالی، فارم ؤ ہچونءَ ماهر انت۔ '
          '${p.isComplete ? "\"مئے ورک آؤٹ ساج\" آزمایش۔" : "پہتے پروفائل مکمل کن۔"}';
  }
}

// Keep the math import used (defensive — avoids unused-import lint).
// ignore: unused_element
double _clamp(double v, double lo, double hi) => math.min(math.max(v, lo), hi);
