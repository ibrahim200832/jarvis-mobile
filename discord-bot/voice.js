import {
  AudioPlayerStatus,
  StreamType,
  VoiceConnectionStatus,
  createAudioPlayer,
  createAudioResource,
  entersState,
  joinVoiceChannel,
} from '@discordjs/voice';
import { synthesize } from './tts.js';

// guildId -> { connection, player, idleTimer }
const sessions = new Map();
const IDLE_MS = 5 * 60 * 1000;

function getOrCreateSession(voiceChannel) {
  let session = sessions.get(voiceChannel.guild.id);
  if (session) return session;

  const connection = joinVoiceChannel({
    channelId: voiceChannel.id,
    guildId: voiceChannel.guild.id,
    adapterCreator: voiceChannel.guild.voiceAdapterCreator,
  });
  const player = createAudioPlayer();
  connection.subscribe(player);
  session = { connection, player, idleTimer: null };
  sessions.set(voiceChannel.guild.id, session);
  return session;
}

function resetIdleTimer(guildId, session) {
  clearTimeout(session.idleTimer);
  session.idleTimer = setTimeout(() => {
    session.connection.destroy();
    sessions.delete(guildId);
  }, IDLE_MS);
}

/** Joins `voiceChannel` if not already connected there, and speaks `text`. */
export async function speakInChannel(voiceChannel, text) {
  const session = getOrCreateSession(voiceChannel);
  await entersState(session.connection, VoiceConnectionStatus.Ready, 10_000);
  const resource = createAudioResource(synthesize(text), { inputType: StreamType.Raw });
  session.player.play(resource);
  await entersState(session.player, AudioPlayerStatus.Playing, 10_000);
  resetIdleTimer(voiceChannel.guild.id, session);
}

/** Disconnects from the given guild's voice channel, if connected. Returns
 * whether there was an active session to leave. */
export function leaveChannel(guildId) {
  const session = sessions.get(guildId);
  if (!session) return false;
  clearTimeout(session.idleTimer);
  session.connection.destroy();
  sessions.delete(guildId);
  return true;
}
