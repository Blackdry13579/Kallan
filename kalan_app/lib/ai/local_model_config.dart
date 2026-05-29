class LocalModelConfig {
  final String id;
  final String displayName;
  final String fileName;
  final String tmpFileName;
  final String downloadUrl;
  final String sizeLabel;
  // 'gguf' = llamadart runtime | 'gemma' = flutter_gemma runtime
  final String runtime;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.tmpFileName,
    required this.downloadUrl,
    required this.sizeLabel,
    required this.runtime,
  });
}

// Modèle cible : Qwen2.5 1.5B Q4_K_M (GGUF, ~986 Mo)
// Source : bartowski/Qwen2.5-1.5B-Instruct-GGUF (repo public, pas d'auth requise)
const qwen25LocalModel = LocalModelConfig(
  id: 'qwen25_15b_q4km',
  displayName: 'Qwen2.5 1.5B',
  fileName: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
  tmpFileName: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf.tmp',
  downloadUrl:
      'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
  sizeLabel: '986 Mo',
  runtime: 'gguf',
);

// Fallback : Gemma 3 1B (ancien modèle, ~350 Mo)
const gemmaLocalModel = LocalModelConfig(
  id: 'gemma3_1b',
  displayName: 'Gemma 3 1B (fallback)',
  fileName: 'gemma3-1b-it-int4.task',
  tmpFileName: 'gemma3-1b-it-int4.task.tmp',
  downloadUrl:
      'https://github.com/Blackdry13579/Gemma3-1B/releases/download/V1.0/gemma3-1b-it-int4.task',
  sizeLabel: '350 Mo',
  runtime: 'gemma',
);
