import 'package:hive_flutter/hive_flutter.dart';
import 'package:streamify/data/services/yt_api_service.dart';

Box box = Hive.box('settings');

class Search extends YoutubeService {
  String? getParam2(String filter) {
    final filterParams = {
      'songs': 'I',
      'videos': 'Q',
      'albums': 'Y',
      'artists': 'g',
      'playlists': 'o'
    };
    return filterParams[filter];
  }

  String? getSearchParams({
    String? filter,
    String? scope,
    bool ignoreSpelling = false,
  }) {
    String? params;
    String? param1;
    String? param2;
    String? param3;
    if (!ignoreSpelling && filter == null && scope == null) {
      return params;
    }

    if (scope == 'uploads') {
      params = 'agIYAw%3D%3D';
    }

    if (scope == 'library') {
      if (filter != null) {
        param1 = 'EgWKAQI';
        param2 = getParam2(filter);
        param3 = 'AWoKEAUQCRADEAoYBA%3D%3D';
      } else {
        params = 'agIYBA%3D%3D';
      }
    }

    if (scope == null && filter != null) {
      if (filter == 'playlist') {
        params = 'Eg-KAQwIABAAGAAgACgB';
        if (!ignoreSpelling) {
          params += 'MABqChAEEAMQCRAFEAo%3D';
        } else {
          params += 'MABCAggBagoQBBADEAkQBRAK';
        }
      } else {
        if (filter.contains('playlist')) {
          param1 = 'EgeKAQQoA';
          if (filter == 'featured_playlist') {
            param2 = 'Dg';
          } else {
            param2 = 'EA';
          }

          if (!ignoreSpelling) {
            param3 = 'BagwQDhAKEAMQBBAJEAU%3D';
          } else {
            param3 = 'BQgIIAWoMEA4QChADEAQQCRAF';
          }
        } else {
          param1 = 'EgWKAQI';
          param2 = getParam2(filter);
          if (!ignoreSpelling) {
            param3 = 'AWoMEA4QChADEAQQCRAF';
          } else {
            param3 = 'AUICCAFqDBAOEAoQAxAEEAkQBQ%3D%3D';
          }
        }
      }
    }

    if (scope == null && filter == null && ignoreSpelling) {
      params = 'EhGKAQ4IARABGAEgASgAOAFAAUICCAE%3D';
    }

    if (params != null) {
      return params;
    } else {
      return '$param1$param2$param3';
    }
  }

  Future<List<Map>> search(
    String query, {
    String? scope,
    bool ignoreSpelling = false,
    String? filter,
  }) async {
    if (headers == null) {
      await init();
    }
    String lang = box.get('language_code', defaultValue: 'en');
    String country = box.get(' countryCode', defaultValue: 'IN');
    context!['context']['client']['hl'] = lang;
    context!['context']['client']['gl'] = country;
    final body = Map.from(context!);
    body['query'] = query;
    final params = getSearchParams(
      filter: filter,
      scope: scope,
      ignoreSpelling: ignoreSpelling,
    );
    if (params != null) {
      body['params'] = params;
    }
    if (filter?.trim() == "") {
      filter = null;
    }
    final List<Map> searchResults = [];
    final res = await sendRequest(endpoints['search']!, body, headers);
    if (!res.containsKey('contents')) {
      return List.empty();
    }

    List contents = [];
    if ((res['contents'] as Map).containsKey('tabbedSearchResultsRenderer')) {
      final tabIndex =
          (scope == null || filter != null) ? 0 : scopes.indexOf(scope) + 1;
      contents = nav(res, [
        'contents',
        'tabbedSearchResultsRenderer',
        'tabs',
        tabIndex,
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ]);
    } else {
      contents = res['contents'];
    }
    if (contents[0]?['messageRenderer'] != null) return [];

    for (var e in contents) {
      if (e['itemSectionRenderer'] != null) {
        continue;
      }

      Map ctx = e['musicShelfRenderer'];

      ctx['contents'].forEach((a) {
        a = a['musicResponsiveListItemRenderer'];
        String type = "";

        if (filter != null) {
          type = filter;
        } else {
          type = ctx['title']['runs'][0]['text'].toLowerCase();
        }
        type = type.substring(0, type.length - 1);
        if (type == 'top resul') {
          type = a['flexColumns']?[1]
                      ['musicResponsiveListItemFlexColumnRenderer']['text']
                  ['runs'][0]['text']
              .toLowerCase();
        }
        if (!['artist', 'playlist', 'song', 'video', 'station']
            .contains(type)) {
          type = 'album';
        }
        List data = a['flexColumns'][1]
            ['musicResponsiveListItemFlexColumnRenderer']['text']['runs'];
        Map res = {
          'type': type,
          'artists': [],
          'album': {},
        };
        if (type != 'artist') {
          res['title'] = a['flexColumns'][0]
                  ['musicResponsiveListItemFlexColumnRenderer']['text']['runs']
              [0]['text'];
        }
        if (type == 'artist') {
          res['artist'] = a['flexColumns'][0]
                  ['musicResponsiveListItemFlexColumnRenderer']['text']['runs']
              [0]['text'];
          res['subscribers'] = data.last['text'];
        } else if (type == 'album') {
          res['type'] = a['flexColumns'][1]
                  ['musicResponsiveListItemFlexColumnRenderer']['text']['runs']
              [0]['text'];
        } else if (type == 'playlist') {
          res['itemCount'] = data.last['text'];
        } else if (type == 'song' || type == 'video') {
          res['artists'] = [];
          res['album'] = {};
        }

        if (['song', 'video'].contains(type)) {
          res['videoId'] = nav(a, [
            'overlay',
            'musicItemThumbnailOverlayRenderer',
            'content',
            'musicPlayButtonRenderer',
            'playNavigationEndpoint',
            'watchEndpoint',
            'videoId'
          ]);
          res['videoType'] = nav(a, [
            'overlay',
            'musicItemThumbnailOverlayRenderer',
            'content',
            'musicPlayButtonRenderer',
            'playNavigationEndpoint',
            'watchEndpoint',
            'watchEndpointMusicSupportedConfigs',
            'watchEndpointMusicConfig',
            'musicVideoType'
          ]);
          res['duration'] = data.last['text'];
          res['radioId'] = 'RDAMVM${res['videoId']}';
        }
        res['thumbnails'] =
            a['thumbnail']['musicThumbnailRenderer']['thumbnail']['thumbnails'];

        for (Map run in data) {
          if (['song', 'video', 'album'].contains(type)) {
            if (run['navigationEndpoint']?['browseEndpoint']
                        ?['browseEndpointContextSupportedConfigs']
                    ?['browseEndpointContextMusicConfig']?['pageType'] ==
                'MUSIC_PAGE_TYPE_ARTIST') {
              res['artists'].add({
                'name': run['text'],
                'browseId': run['navigationEndpoint']?['browseEndpoint']
                    ?['browseId'],
              });
            }
            if (run['navigationEndpoint']?['browseEndpoint']
                        ?['browseEndpointContextSupportedConfigs']
                    ?['browseEndpointContextMusicConfig']?['pageType'] ==
                'MUSIC_PAGE_TYPE_ALBUM') {
              res['album'] = {
                'name': run['text'],
                'browseId': run['navigationEndpoint']?['browseEndpoint']
                    ?['browseId'],
              };
            }
          }
          if (['artist', 'album', 'playlist'].contains(type)) {
            if (res['browseId'] == null &&
                a['navigationEndpoint']['browseEndpoint']['browseId'] != null) {
              res['browseId'] =
                  a['navigationEndpoint']['browseEndpoint']['browseId'];
            }
          }
        }
        if ((res['type'] == 'album' ||
                res['type'] == 'song' ||
                res['type'] == 'video') &&
            res['artists'].isEmpty) {
        } else {
          searchResults.add(res);
        }
      });
    }
    return searchResults;
  }
}
