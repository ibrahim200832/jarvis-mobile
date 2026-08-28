import { spawn } from 'node:child_process';
import ffmpegPath from 'ffmpeg-static';

/**
 * Synthesizes `text` with the Piper voice at `modelPath` and returns a
 * Readable stream of 48kHz/stereo/S16LE PCM, ready for @discordjs/voice's
 * StreamType.Raw.
 *
 * Piper's --output-raw gives headerless S16LE PCM at the voice model's own
 * native rate (`sampleRate`, from voices.js) — Discord requires 48000 Hz
 * stereo, so ffmpeg resamples explicitly in between rather than relying on
 * automatic format detection, which wouldn't work on headerless raw PCM
 * anyway.
 */
export function synthesize(text, modelPath, sampleRate) {
  const piper = spawn(process.env.PIPER_BIN ?? 'piper', ['--model', modelPath, '--output-raw']);
  piper.stdin.write(text);
  piper.stdin.end();
  piper.stderr.on('data', () => {}); // Piper logs progress to stderr

  const ffmpeg = spawn(ffmpegPath, [
    '-f', 's16le', '-ar', String(sampleRate), '-ac', '1', '-i', 'pipe:0',
    '-f', 's16le', '-ar', '48000', '-ac', '2', 'pipe:1',
  ]);
  piper.stdout.pipe(ffmpeg.stdin);
  ffmpeg.stderr.on('data', () => {});

  return ffmpeg.stdout;
}
