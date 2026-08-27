import { REST, Routes, SlashCommandBuilder } from 'discord.js';
import 'dotenv/config';

const commands = [
  new SlashCommandBuilder()
    .setName('frag')
    .setDescription('Stelle JARVIS eine Frage — die Antwort wird im Sprachkanal vorgelesen')
    .addStringOption((opt) => opt.setName('text').setDescription('Deine Frage').setRequired(true)),
  new SlashCommandBuilder().setName('verlasse').setDescription('JARVIS verlässt den Sprachkanal'),
].map((c) => c.toJSON());

const rest = new REST().setToken(process.env.DISCORD_BOT_TOKEN);
await rest.put(Routes.applicationCommands(process.env.DISCORD_CLIENT_ID), { body: commands });
console.log('Slash-Commands registriert.');
