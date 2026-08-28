// Known German Piper voices, offered as a dropdown on /frag. Add more
// entries here (and the matching .onnx/.onnx.json files to the same folder
// as PIPER_MODEL) to extend the list — see README.md.
//
// sampleRate is the voice model's native output rate, which --output-raw
// doesn't self-describe (no WAV header) — it must match the quality tier:
// x_low/low models are 16000 Hz, medium/high models are 22050 Hz. Getting
// this wrong makes the voice sound pitch-shifted, not just lower quality.
export const VOICES = {
  thorsten: { label: 'Thorsten (männlich)', file: 'de_DE-thorsten-medium.onnx', sampleRate: 22050 },
  kerstin: { label: 'Kerstin (weiblich)', file: 'de_DE-kerstin-low.onnx', sampleRate: 16000 },
  eva_k: { label: 'Eva K (weiblich)', file: 'de_DE-eva_k-x_low.onnx', sampleRate: 16000 },
  ramona: { label: 'Ramona (weiblich)', file: 'de_DE-ramona-low.onnx', sampleRate: 16000 },
};

export const DEFAULT_VOICE = 'thorsten';
