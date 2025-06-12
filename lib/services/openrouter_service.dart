import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  // static const String _apiKey = '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'; 
  static const String _apiKey = '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'; 
  
  static const String _model = 'google/gemini-flash-1.5';

  Future<Map<String, dynamic>?> generateBudgetingPlan({
    required String userPrompt,
    required double monthlyIncome,
    required double monthlyExpenses,
    required String today,
  }) async {
    try {
      final systemPrompt = _createSystemPrompt();
      final userMessage = _createUserMessage(userPrompt, monthlyIncome, monthlyExpenses, today);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'http://localhost:8080', // For local development
          'X-Title': 'Financial Management App',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userMessage,
            }
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        return _parseJsonResponse(content);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate budgeting plan: $e');
    }
  }

  String _createSystemPrompt() {
    return '''
You are a financial advisor AI. Your ONLY job is to create realistic savings goals and respond with JSON.

CRITICAL: Your response must be ONLY a valid JSON object. No explanations, no markdown, no extra text.

Respond with this EXACT format:

{
  "goals": [
    {
      "name": "Goal Name",
      "target": 10000000,
      "deadline": "2025-12-31"
    }
  ],
  "summary": "Brief explanation of the plan"
}

Requirements:
1. Create 3-4 realistic goals
2. Target amounts in Indonesian Rupiah (whole numbers only)
3. Deadlines in YYYY-MM-DD format
4. Goals should be achievable with their monthly savings
5. Focus on the user request, with also including emergency fund and retirement fund
6. Keep summary under 100 words

RESPOND ONLY WITH JSON - NO OTHER TEXT.
''';
  }

  String _createUserMessage(String userPrompt, double monthlyIncome, double monthlyExpenses, String today) {
    final monthlySavings = monthlyIncome - monthlyExpenses;
    
    return '''
My money situation:
- I earn Rp. ${monthlyIncome.toStringAsFixed(0)} per month
- I spend Rp. ${monthlyExpenses.toStringAsFixed(0)} per month  
- I can save Rp. ${monthlySavings.toStringAsFixed(0)} per month
- Current Date: ${today}

My goals: $userPrompt

Please make me a simple savings plan with realistic goals.
''';
  }

  Map<String, dynamic>? _parseJsonResponse(String content) {
    try {
      
      if (content.trim().isEmpty) {
        return _getFallbackResponse();
      }
      
      String jsonString = content.trim();

      

      
      final parsed = jsonDecode(jsonString);
      
      // Validate the structure
      if (parsed is Map<String, dynamic> && 
          parsed.containsKey('goals') && 
          parsed['goals'] is List) {
        return parsed;
      } else {
        return _getFallbackResponse();
      }
    } catch (e) {
      return _getFallbackResponse();
    }
  }

  // Fallback response when AI fails
  Map<String, dynamic> _getFallbackResponse() {
    return {
      "goals": [
        {
          "name": "Emergency Fund",
          "target": 50000000,
          "deadline": "2025-12-31"
        },
        {
          "name": "Investment Fund",
          "target": 100000000,
          "deadline": "2027-06-30"
        },
        {
          "name": "Retirement Savings",
          "target": 500000000,
          "deadline": "2040-01-01"
        }
      ],
      "summary": "A basic savings plan with emergency fund, investments, and retirement planning. Adjust amounts based on your specific financial situation."
    };
  }

  // Test method to check if API key is working
  Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': 'Hello, respond with just "API Working"'
            }
          ],
          'max_tokens': 10,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}