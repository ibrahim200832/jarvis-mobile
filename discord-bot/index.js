import { Client, GatewayIntentBits, MessageFlags } from 'discord.js';
import 'dotenv/config';
import { askJarvis } from './ai.js';
import { leaveChannel, speakInChannel } from './voice.js';

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
    await interaction.deferReply();
    try {
      const reply = await askJarvis(text);
      await speakInChannel(voiceChannel, reply);
      await interaction.editReply(reply);
    } catch (err) {
      await interaction.editReply(`Fehler: ${err.message}`);
    }
  }
});

client.login(process.env.DISCORD_BOT_TOKEN);
