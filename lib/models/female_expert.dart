class FemaleExpert {
  final String nickname;
  final int age;
  final String city;
  final int pricePerMin;
  final String bio;
  final String avatarPath;
  final String languages;
  final double rating;
  final bool isOnline;
  final List<String> categories;

  const FemaleExpert({
    required this.nickname,
    required this.age,
    required this.city,
    required this.pricePerMin,
    required this.bio,
    required this.avatarPath,
    required this.languages,
    required this.rating,
    required this.isOnline,
    required this.categories,
  });

  static List<FemaleExpert> get mockExperts {
    return const [
      FemaleExpert(
        nickname: "Seerat",
        age: 23,
        city: "Jalandhar, PB",
        pricePerMin: 5,
        bio: "5 min do mujhe - mood off se mood on ka safar kara dung...",
        avatarPath: "assets/avatars/female_2.png",
        languages: "Hindi - Punjabi",
        rating: 4.5,
        isOnline: true,
        categories: ["All", "Confidence", "Star"],
      ),
      FemaleExpert(
        nickname: "maya",
        age: 23,
        city: "Bengaluru, KA",
        pricePerMin: 5,
        bio: "Meri baatein sun ke neend ud jaati hai logon ki. Tum ready...",
        avatarPath: "assets/avatars/female_1.png",
        languages: "Hindi-Kannada",
        rating: 4.8,
        isOnline: true,
        categories: ["All", "Star", "Marriage"],
      ),
      FemaleExpert(
        nickname: "Archana gupta",
        age: 19,
        city: "Delhi, DL",
        pricePerMin: 5,
        bio: "Bahar chill, andar 1000 cheeje.",
        avatarPath: "assets/avatars/female_3.png",
        languages: "Hindi - Punjabi",
        rating: 4.6,
        isOnline: true,
        categories: ["All", "Relationship", "Confidence"],
      ),
      FemaleExpert(
        nickname: "Simmi",
        age: 20,
        city: "Patna, BR",
        pricePerMin: 5,
        bio: "Late night chai, late night baatein, late night main & tum ☕️",
        avatarPath: "assets/avatars/female_2.png",
        languages: "Hindi",
        rating: 4.7,
        isOnline: true,
        categories: ["All", "Relationship", "Marriage"],
      ),
      FemaleExpert(
        nickname: "divya",
        age: 27,
        city: "Bengaluru, KA",
        pricePerMin: 5,
        bio: "Single ho ya nahi - mujhe matlab nahi. Bas baat acchi honi...",
        avatarPath: "assets/avatars/female_3.png",
        languages: "Hindi",
        rating: 4.4,
        isOnline: true,
        categories: ["All", "Star", "Relationship"],
      ),
      FemaleExpert(
        nickname: "Poonam",
        age: 25,
        city: "Delhi, DL",
        pricePerMin: 5,
        bio: "Dil se baat karte hain, chalo connect karein!",
        avatarPath: "assets/avatars/female_4.png",
        languages: "Hindi-Gujarati",
        rating: 4.9,
        isOnline: true,
        categories: ["All", "Confidence", "Relationship"],
      ),
      FemaleExpert(
        nickname: "Aanya",
        age: 22,
        city: "Mumbai, MH",
        pricePerMin: 6,
        bio: "Listening to your thoughts is my favourite thing to do.",
        avatarPath: "assets/avatars/female_5.png",
        languages: "Hindi-English",
        rating: 4.6,
        isOnline: true,
        categories: ["All", "Relationship"],
      ),
      FemaleExpert(
        nickname: "Sanjuli",
        age: 24,
        city: "Jaipur, RJ",
        pricePerMin: 5,
        bio: "Talk to me about life, love, and everything in between.",
        avatarPath: "assets/avatars/female_6.png",
        languages: "Hindi-Rajasthani",
        rating: 4.7,
        isOnline: false,
        categories: ["All", "Confidence", "Marriage"],
      ),
    ];
  }
}
