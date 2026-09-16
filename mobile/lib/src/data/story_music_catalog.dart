import 'package:flutter/material.dart';

import '../models.dart';

/// Pistas propias de HallyuHub disponibles para Historias.
///
/// El catálogo no incluye canciones comerciales ni promete música oficial de
/// artistas. Cada archivo vive dentro de la aplicación y puede reemplazarse por
/// otro audio autorizado manteniendo el mismo id.
const storyMusicLibrary = <StoryMusic>[
  StoryMusic(
    id: 'neon-dream',
    title: 'Neon Dream',
    artist: 'HallyuHub Studio',
    assetPath: 'demo-audio/neon-dream.wav',
    color: Color(0xFFEF4F7A),
    mood: 'Dream pop',
  ),
  StoryMusic(
    id: 'idol-sparkle',
    title: 'Idol Spark',
    artist: 'HallyuHub Studio',
    assetPath: 'demo-audio/idol-sparkle.wav',
    color: Color(0xFF65E4FF),
    mood: 'Brillante',
  ),
  StoryMusic(
    id: 'seoul-night',
    title: 'Seoul Night',
    artist: 'HallyuHub Studio',
    assetPath: 'demo-audio/seoul-night.wav',
    color: Color(0xFFA855F7),
    mood: 'Nocturno',
  ),
  StoryMusic(
    id: 'purple-stage',
    title: 'Purple Stage',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/purple-stage.wav',
    color: Color(0xFF9B5DE5),
    mood: 'Escenario',
  ),
  StoryMusic(
    id: 'soft-glow',
    title: 'Soft Glow',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/soft-glow.wav',
    color: Color(0xFFFF9BCB),
    mood: 'Suave',
  ),
  StoryMusic(
    id: 'dance-intro',
    title: 'Dance Intro',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/dance-intro.wav',
    color: Color(0xFF4DE7FF),
    mood: 'Dance',
  ),
  StoryMusic(
    id: 'comeback-beat',
    title: 'Comeback Beat',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/comeback-beat.wav',
    color: Color(0xFFFF4D8D),
    mood: 'Energético',
  ),
  StoryMusic(
    id: 'lightstick-pop',
    title: 'Lightstick Pop',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/lightstick-pop.wav',
    color: Color(0xFFFFD166),
    mood: 'Celebración',
  ),
  StoryMusic(
    id: 'midnight-seoul',
    title: 'Midnight Seoul',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/midnight-seoul.wav',
    color: Color(0xFF6C63FF),
    mood: 'Chill',
  ),
  StoryMusic(
    id: 'starry-loop',
    title: 'Starry Loop',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/starry-loop.wav',
    color: Color(0xFFE0AAFF),
    mood: 'Etéreo',
  ),
  StoryMusic(
    id: 'hallyu-pulse',
    title: 'Hallyu Pulse',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/hallyu-pulse.wav',
    color: Color(0xFF00D6C9),
    mood: 'Electro pop',
  ),
  StoryMusic(
    id: 'fan-chant',
    title: 'Fan Chant',
    artist: 'HallyuHub Studio',
    assetPath: 'story-audio/fan-chant.wav',
    color: Color(0xFFFF7A59),
    mood: 'Fandom',
  ),
];
