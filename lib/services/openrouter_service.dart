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
You are a financial advisor AI. You must respond with ONLY valid JSON.

IMPORTANT: Your response must be EXACTLY this JSON format with NO extra text:
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

Rules:
1. ONLY return JSON - no explanations before/after
2. Create 2-4 realistic goals
3. Target amounts as integers (Indonesian Rupiah)
4. Deadlines in YYYY-MM-DD format
5. Include emergency fund + user's specific goals
6. Summary under 80 words

RESPOND WITH ONLY THE JSON OBJECT - NOTHING ELSE.

''';
  }

    String _createUserMessage(String userPrompt, double monthlyIncome, double monthlyExpenses, String today) {
    final monthlySavings = monthlyIncome - monthlyExpenses;
    
    return '''
Financial situation:
- Monthly income: Rp. ${monthlyIncome.toStringAsFixed(0)}
- Monthly expenses: Rp. ${monthlyExpenses.toStringAsFixed(0)}  
- Available to save: Rp. ${monthlySavings.toStringAsFixed(0)}
- Today: $today

User goals: $userPrompt

Create a realistic savings plan.
''';
  }

  Map<String, dynamic>? _parseJsonResponse(String content) {
    try {
      
      if (content.trim().isEmpty) {
        return _getFallbackResponse();
      }
      
      String jsonString = content.trim();
      jsonString = jsonString.replaceAll(RegExp(r'```json\s*'), '');
      jsonString = jsonString.replaceAll('```', '');
      int firstBrace = jsonString.indexOf('{');
      if (firstBrace >= 0) {
        jsonString = jsonString.substring(firstBrace);
      }

      int braceCount = 0;
      int lastValidPosition = -1;
    
      for (int i = 0; i < jsonString.length; i++) {
        if (jsonString[i] == '{') {
          braceCount++;
        } else if (jsonString[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            lastValidPosition = i;
            break;
          }
        }
      }
    
      if (lastValidPosition > 0) {
        jsonString = jsonString.substring(0, lastValidPosition + 1);
      }

      
      final parsed = jsonDecode(jsonString);
      
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
}