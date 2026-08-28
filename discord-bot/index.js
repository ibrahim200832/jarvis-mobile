import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { Client, GatewayIntentBits, MessageFlags } from 'discord.js';
import 'dotenv/config';
import { askJarvis } from './ai.js';
import { leaveChannel, speakInChannel } from './voice.js';
import { DEFAULT_VOICE, VOICES } from './voices.js';

const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildVoiceStates] });

client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'verlasse') {
    const left = leaveChannel(interaction.guildId);
    await interaction.reply({
      content: left ? 'Bis gleich.' : 'Ich bin gerade in keinem Sprachkanal.',
      flags: MessageFlags.Ephemeral,
    });
    return;
  }

  if (interaction.commandName === 'frag') {
    const voiceChannel = interaction.member?.voice?.channel;
    if (!voiceChannel) {
      await interaction.reply({
        content: 'Du musst zuerst einem Sprachkanal beitreten.',
        flags: MessageFlags.Ephemeral,
      });
      return;
    }
    const text = interaction.options.getString('text', true);
    const voiceKey = interaction.options.getString('stimme') ?? DEFAULT_VOICE;
    const voice = VOICES[voiceKey];
    const voicesDir = dirname(process.env.PIPER_MODEL);
    const modelPath = join(voicesDir, voice.file);
    if (!existsSync(modelPath)) {
      await interaction.reply({
        content: `Die Stimme "${voice.label}" ist noch nicht heruntergeladen. Lade sie von huggingface.co/rhasspy/piper-voices herunter und leg beide Dateien (.onnx und .onnx.json) in denselben Ordner wie deine anderen Stimmen (${voicesDir}).`,
        flags: MessageFlags.Ephemeral,
      });
      return;
    }

    await interaction.deferReply();
    try {
      const reply = await askJarvis(text);
      await speakInChannel(voiceChannel, reply, modelPath, voice.sampleRate);
      await interaction.editReply(reply);
    } catch (err) {
      console.error(err);
      await interaction.editReply(`Fehler: ${err.message}`);
    }
  }
});

client.login(process.env.DISCORD_BOT_TOKEN);
