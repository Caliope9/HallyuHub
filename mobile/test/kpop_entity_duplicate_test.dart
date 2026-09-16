import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/models.dart';
import 'package:hallyuhub/src/services/local_artist_tag_service.dart';

void main() {
  const bts = KpopEntity(
    id: 'bts-id',
    type: KpopEntityType.group,
    name: 'BTS',
    normalizedName: 'bts',
  );
  const jungkook = KpopEntity(
    id: 'jungkook-id',
    type: KpopEntityType.idol,
    name: 'Jungkook',
    aliases: ['JK'],
  );

  test('duplicate matching ignores casing and repeated whitespace', () {
    expect(
      isExactKpopEntityDuplicate(
        entity: bts,
        requestedName: '  bTs  ',
        requestedType: KpopEntityType.group,
      ),
      isTrue,
    );
    expect(
      isExactKpopEntityDuplicate(
        entity: jungkook,
        requestedName: ' jk ',
        requestedType: KpopEntityType.artist,
      ),
      isTrue,
    );
  });

  test('different entity types are not treated as the same suggestion', () {
    expect(
      isExactKpopEntityDuplicate(
        entity: bts,
        requestedName: 'BTS',
        requestedType: KpopEntityType.artist,
      ),
      isFalse,
    );
  });
}
