import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String photoUrl;
  final String displayName;
  final String bio;

  User({
    this.id,
    this.username,
    this.email,
    this.photoUrl,
    this.displayName,
    this.bio
  });

  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
      id: doc['id'],
      displayName: doc['displayName'],
      email: doc['email'],
      bio: doc['bio'],
      photoUrl: doc['photoUrl'],
      username: doc['username']
    );
  }
}
