abstract class LocalLlmEngine {
  Future<void> loadModel(String modelPath);
  Future<String> generateText(String prompt, {int maxTokens = 512});
  Future<void> dispose();
}
