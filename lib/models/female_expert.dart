class FemaleExpert {
  final String id;
  final String nickname;
  final int age;
  final String city;
  final int pricePerMin;
  final String bio;
  final String languages;
  final double rating;
  final bool isOnline;
  final List<String> categories;

  const FemaleExpert({
    required this.id,
    required this.nickname,
    required this.age,
    required this.city,
    required this.pricePerMin,
    required this.bio,
    required this.languages,
    required this.rating,
    required this.isOnline,
    required this.categories,
  });

  static List<FemaleExpert> get mockExperts {
    return const [
      FemaleExpert(
        id: "expert_1",
        nickname: "Seerat",
        age: 23,
        city: "Jalandhar, PB",
        pricePerMin: 5,
        bio: "5 min do mujhe - mood off se mood on ka safar kara dung...",
        languages: "Hindi - Punjabi",
        rating: 4.5,
        isOnline: true,
        categories: ["All", "Confidence", "Star"],
      ),
      FemaleExpert(
        id: "expert_2",
        nickname: "maya",
        age: 23,
        city: "Bengaluru, KA",
        pricePerMin: 5,
        bio: "Meri baatein sun ke neend ud jaati hai logon ki. Tum ready...",
        languages: "Hindi-Kannada",
        rating: 4.8,
        isOnline: true,
        categories: ["All", "Star", "Marriage"],
      ),
      FemaleExpert(
        id: "expert_3",
        nickname: "Archana gupta",
        age: 19,
        city: "Delhi, DL",
        pricePerMin: 5,
        bio: "Bahar chill, andar 1000 cheeje.",
        languages: "Hindi - Punjabi",
        rating: 4.6,
        isOnline: true,
        categories: ["All", "Relationship", "Confidence"],
      ),
      FemaleExpert(
        id: "expert_4",
        nickname: "Simmi",
        age: 20,
        city: "Patna, BR",
        pricePerMin: 5,
        bio: "Late night chai, late night baatein, late night main & tum ☕️",
        languages: "Hindi",
        rating: 4.7,
        isOnline: true,
        categories: ["All", "Relationship", "Marriage"],
      ),
      FemaleExpert(
        id: "expert_5",
        nickname: "divya",
        age: 27,
        city: "Bengaluru, KA",
        pricePerMin: 5,
        bio: "Single ho ya nahi - mujhe matlab nahi. Bas baat acchi honi...",
        languages: "Hindi",
        rating: 4.4,
        isOnline: true,
        categories: ["All", "Star", "Relationship"],
      ),
      FemaleExpert(
        id: "expert_6",
        nickname: "Poonam",
        age: 25,
        city: "Delhi, DL",
        pricePerMin: 5,
        bio: "Dil se baat karte hain, chalo connect karein!",
        languages: "Hindi-Gujarati",
        rating: 4.9,
        isOnline: true,
        categories: ["All", "Confidence", "Relationship"],
      ),
      FemaleExpert(
        id: "expert_7",
        nickname: "Aanya",
        age: 22,
        city: "Mumbai, MH",
        pricePerMin: 6,
        bio: "Listening to your thoughts is my favourite thing to do.",
        languages: "Hindi-English",
        rating: 4.6,
        isOnline: true,
        categories: ["All", "Relationship"],
      ),
      FemaleExpert(
        id: "expert_8",
        nickname: "Sanjuli",
        age: 24,
        city: "Jaipur, RJ",
        pricePerMin: 5,
        bio: "Talk to me about life, love, and everything in between.",
        languages: "Hindi-Rajasthani",
        rating: 4.7,
        isOnline: false,
        categories: ["All", "Confidence", "Marriage"],
      ),
    ];
  }
}
