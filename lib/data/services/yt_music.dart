import 'package:streamify/data/services/endpoints/recommended.dart';
import 'package:streamify/data/services/endpoints/yt_playlist.dart';
import 'package:streamify/data/services/endpoints/yt_search.dart';

class YTMusic {
  static search(query,
          {String? filter, String? scope, ignoreSpelling = false}) =>
      Search().search(query,
          filter: filter, scope: scope, ignoreSpelling: ignoreSpelling);

  static Future suggestions(query) =>
      Recommendations().getSearchSuggestions(query: query);

  static Future getPlaylistDetails(playlistId) =>
      Playlist().getPlaylistDetails(playlistId);
}
