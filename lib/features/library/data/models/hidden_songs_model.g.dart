// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hidden_songs_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiddenSongsModelAdapter extends TypeAdapter<HiddenSongsModel> {
  @override
  final int typeId = 3;

  @override
  HiddenSongsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiddenSongsModel(
      songIds: (fields[0] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiddenSongsModel obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.songIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiddenSongsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
