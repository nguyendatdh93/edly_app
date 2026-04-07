import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/default_room_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/hsa_room/hsa_room_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/literature_room_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/tsa_room_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/vact_room/vact_room_view.dart';
import 'package:flutter/material.dart';

Widget buildQuizRoomByVariant(QuizRoomData room) {
  final variant = room.variant.toLowerCase().trim();

  switch (variant) {
    case 'tsa':
      return TsaRoomView(room: room);
    case 'hsa':
      return HsaRoomView(room: room);
    case 'vact':
      return VactRoomView(room: room);
    case 'literature':
      return LiteratureRoomView(room: room);
    default:
      return DefaultRoomView(room: room);
  }
}
