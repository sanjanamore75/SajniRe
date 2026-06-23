import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalChatDatabase {
  static final LocalChatDatabase instance = LocalChatDatabase._init();
  static Database? _database;

  // We use a StreamController to broadcast changes to listeners (like the ChatListScreen)
  final StreamController<void> _updateController = StreamController<void>.broadcast();

  Stream<void> get updates => _updateController.stream;

  LocalChatDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        msgId TEXT PRIMARY KEY,
        roomId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status INTEGER NOT NULL
      )
    ''');
    // Index to speed up roomId queries
    await db.execute('CREATE INDEX idx_roomId ON messages (roomId)');
  }

  // Generate a deterministic room ID
  static String generateRoomId(String uid1, String uid2) {
    final users = [uid1, uid2];
    users.sort();
    return users.join('_');
  }

  // Extract other user ID from room ID
  static String getOtherUserIdFromRoomId(String roomId, String myUid) {
    final parts = roomId.split('_');
    for (var p in parts) {
      if (p != myUid && p.isNotEmpty) return p;
    }
    return '';
  }

  Future<void> saveMessageLocally(Map<String, dynamic> message) async {
    final db = await instance.database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _updateController.add(null);
  }

  Future<void> updateMessageStatus(String msgId, int newStatus) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {'status': newStatus},
      where: 'msgId = ?',
      whereArgs: [msgId],
    );
    _updateController.add(null);
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory(String roomId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'roomId = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnreadMessages(String roomId, String senderId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'roomId = ? AND senderId = ? AND status < 3',
      whereArgs: [roomId, senderId],
    );
  }

  // getRecentChats for ChatListScreen
  Future<List<Map<String, dynamic>>> getRecentChats(String myUid) async {
    final db = await instance.database;
    
    // Query to get the latest message for each room, plus count unread messages from the OTHER person
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        m1.roomId,
        m1.text as lastMessage,
        m1.timestamp,
        m1.senderId as lastSenderId,
        (
          SELECT COUNT(*) 
          FROM messages m2 
          WHERE m2.roomId = m1.roomId 
            AND m2.senderId != ? 
            AND m2.status < 3
        ) as unreadCount
      FROM messages m1
      INNER JOIN (
          SELECT roomId, MAX(timestamp) as maxTime
          FROM messages
          GROUP BY roomId
      ) grouped_m ON m1.roomId = grouped_m.roomId AND m1.timestamp = grouped_m.maxTime
      ORDER BY m1.timestamp DESC
    ''', [myUid]);

    // Enhance the result with otherUserId
    return result.map((row) {
      final mutableRow = Map<String, dynamic>.from(row);
      mutableRow['otherUserId'] = getOtherUserIdFromRoomId(row['roomId'] as String, myUid);
      return mutableRow;
    }).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
