/// Gemini API Configuration
/// 
/// IMPORTANT: Add your Gemini API key here
/// Get your API key from: https://aistudio.google.com/app/apikey
class GeminiConfig {
  // TODO: Replace with your actual API key from Google AI Studio
  static const String apiKey = 'AIzaSyAhEss817EEsRVng-MCUPnNrhVb5nJiBdE';
  
  // Check if API key is configured
  static bool get isConfigured => apiKey != 'YOUR_API_KEY_HERE' && apiKey.isNotEmpty;
}
