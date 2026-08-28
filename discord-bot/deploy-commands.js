import { REST, Routes, SlashCommandBuilder } from 'discord.js';
import 'dotenv/config';
import { VOICES } from './voices.js';

const commands = [
  new SlashCommandBuilder()
    .setName('frag')
    .setDescription('Stelle JARVIS eine Frage — die Antwort wird im Sprachkanal vorgelesen')
    .addStringOption((opt) => opt.setName('text').setDescription('Deine Frage').setRequired(true))
    .addStringOption((opt) =>
      opt
        .setName('stimme')
        .setDescription('Welche Stimme JARVIS benutzen soll (Standard: Thorsten)')
        .setRequired(false)
        .addChoices(...Object.entries(VOICES).map(([key, v]) => ({ name: v.label, value: key }))),
    ),
  new SlashCommandBuilder().setName('verlasse').setDescription('JARVIS verlässt den Sprachkanal'),
].map((c) => c.toJSON());

const rest = new REST().setToken(process.env.DISCORD_BOT_TOKEN);
await rest.put(Routes.applicationCommands(process.env.DISCORD_CLIENT_ID), { body: commands });
console.log('Slash-Commands registriert.');
