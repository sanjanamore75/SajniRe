class CallLog {
  final String name;
  final String timeText;
  final String duration;
  final String cost;
  final String avatarUrl; // We'll use initial letters or a local asset/placeholder

  CallLog({
    required this.name,
    required this.timeText,
    required this.duration,
    required this.cost,
    required this.avatarUrl,
  });
}

class ChatFriend {
  final String name;
  final String lastMessage;
  final String dayText;
  final bool isPinned;
  final bool isMuted;

  ChatFriend({
    required this.name,
    required this.lastMessage,
    required this.dayText,
    this.isPinned = false,
    this.isMuted = false,
  });
}

final List<CallLog> mockCallLogs = [
  CallLog(name: 'nJsVw', timeText: 'Today 09:10 AM', duration: '54 sec', cost: '₹1', avatarUrl: 'https://i.pravatar.cc/150?img=11'),
  CallLog(name: 'MkKumar', timeText: 'Today 08:48 AM', duration: '9 sec', cost: '₹0', avatarUrl: 'https://i.pravatar.cc/150?img=12'),
  CallLog(name: 'explore', timeText: 'Yesterday 03:53 PM', duration: '13 sec', cost: '₹3', avatarUrl: 'https://i.pravatar.cc/150?img=13'),
  CallLog(name: 'tTKmW', timeText: 'Yesterday 01:13 PM', duration: '5 min 39 sec', cost: '₹6', avatarUrl: 'https://i.pravatar.cc/150?img=14'),
  CallLog(name: 'abcdRam', timeText: '05 Jun 05:19 PM', duration: '3 sec', cost: '₹0', avatarUrl: 'https://i.pravatar.cc/150?img=15'),
  CallLog(name: 'ak', timeText: '03 Jun 04:11 AM', duration: '4 sec', cost: '₹0', avatarUrl: 'https://i.pravatar.cc/150?img=16'),
  CallLog(name: 'Akhil', timeText: '02 Jun 06:04 AM', duration: '6 sec', cost: '₹0', avatarUrl: 'https://i.pravatar.cc/150?img=17'),
];

final List<ChatFriend> mockChatFriends = [
  ChatFriend(name: 'oaTnQ698', lastMessage: 'Whatsap par aaayo', dayText: 'Wed', isPinned: true, isMuted: true),
  ChatFriend(name: 'VFIMf835', lastMessage: 'aap kha se ho', dayText: 'Yesterday', isPinned: true, isMuted: true),
  ChatFriend(name: 'QGNje721', lastMessage: 'Baby', dayText: 'Yesterday', isPinned: true, isMuted: true),
  ChatFriend(name: 'JFpQa865', lastMessage: 'Bolo', dayText: 'Thu', isPinned: true, isMuted: true),
  ChatFriend(name: 'sohel31', lastMessage: 'NUMBER dijiye', dayText: 'Thu', isPinned: true, isMuted: true),
  ChatFriend(name: 'vpsFU712', lastMessage: 'Call me baby', dayText: 'Thu', isPinned: true, isMuted: true),
];
