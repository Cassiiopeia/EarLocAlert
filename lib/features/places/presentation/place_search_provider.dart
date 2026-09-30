import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/google_place_search_service.dart';
import '../domain/place_search.dart';

part 'place_search_provider.g.dart';

@Riverpod(keepAlive: true)
PlaceSearchService placeSearchService(Ref ref) => GooglePlaceSearchService();
