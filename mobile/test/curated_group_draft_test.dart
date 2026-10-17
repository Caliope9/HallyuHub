import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/services/local_artist_tag_service.dart';

void main() {
  const complete = CuratedGroupDraft(
    bio:
        'Grupo surcoreano de crossover vocal formado por cuatro integrantes activos.',
    sourceUrl: 'https://www.universal-music.co.jp/forestella/biography/',
    members: ['Bae Doo-hoon', 'Kang Hyung-ho', 'Cho Min-kyu', 'Ko Woo-rim'],
    discography: ['Evolution', 'Mystique'],
  );

  test('grupo completo se puede enviar a revisión', () {
    expect(complete.isComplete, isTrue);
  });

  test('rechaza grupo sin fuente HTTPS, integrantes o discografía', () {
    expect(
      CuratedGroupDraft(
        bio: complete.bio,
        sourceUrl: 'http://example.com',
        members: complete.members,
        discography: complete.discography,
      ).isComplete,
      isFalse,
    );
    expect(
      CuratedGroupDraft(
        bio: complete.bio,
        sourceUrl: complete.sourceUrl,
        members: ['A', 'a'],
        discography: complete.discography,
      ).isComplete,
      isFalse,
    );
    expect(
      CuratedGroupDraft(
        bio: complete.bio,
        sourceUrl: complete.sourceUrl,
        members: complete.members,
        discography: [],
      ).isComplete,
      isFalse,
    );
  });
}
