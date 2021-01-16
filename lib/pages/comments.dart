import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'home.dart';
import 'package:timeago/timeago.dart' as timeago;

class Comments extends StatefulWidget {

  final String postId;
  final String postOwnerId;
  final String postMediaUrl;

  Comments({
    this.postId,
    this.postMediaUrl,
    this.postOwnerId
  });

  @override
  CommentsState createState() => CommentsState(
    postId: this.postId,
    postMediaUrl: this.postMediaUrl,
    postOwnerId: this.postOwnerId
  );
}

class CommentsState extends State<Comments> {
  TextEditingController commentController = TextEditingController();

  final String postId;
  final String postOwnerId;
  final String postMediaUrl;

  CommentsState({
    this.postId,
    this.postMediaUrl,
    this.postOwnerId
  });

  buildComment() {
    return StreamBuilder(
      stream: commentsRef.document(postId).collection('comments').orderBy('timestamp', descending: false).snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return circularProgress();
        }
        List<Comment> comments = [];
        snapshot.data.documents.forEach((doc) {
          comments.add(Comment.fromDocument(doc));
        });
        return ListView(
          children: comments,
        );
      }
    );
  }

  addComment() {
    commentsRef
      .document(postId)
      .collection('comments')
      .add({
        'username': currentUser.username,
        'comment': commentController.text,
        'timestamp': timestamp,
        'avatarUrl': currentUser.photoUrl,
        'userId': currentUser.id
      });
    bool isNotPostOwner = postOwnerId != currentUser.id;
    if(isNotPostOwner){
      activityFeedRef
          .document(postOwnerId)
          .collection('feedItems')
          .add({
        'type': 'comment',
        'commentData': commentController.text,
        'username': currentUser.username,
        'userId': currentUser.id,
        'userProfileImage': currentUser.photoUrl,
        'postId': postId,
        'mediaUrl': postMediaUrl,
        'timestamp': timestamp
      });
    }
    commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, titleText: 'Comments'),
      body: Column(
        children: [
          Expanded(
            child: buildComment(),
          ),
          Divider(),
          ListTile(
            title: TextFormField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: 'Write a comment...'
              ),
            ),
            trailing: OutlineButton(
              onPressed: addComment,
              borderSide: BorderSide.none,
              child: Text('Post'),
            ),
          )
        ],
      ),
    );
  }
}

class Comment extends StatelessWidget {
  final String username;
  final String userId;
  final String avatarUrl;
  final String comment;
  final Timestamp timestamp;
  
  Comment({
    this.username,
    this.userId,
    this.avatarUrl,
    this.comment,
    this.timestamp
  });
  
  factory Comment.fromDocument(DocumentSnapshot doc) {
    return Comment(
      userId: doc['userId'],
      username: doc['username'],
      comment: doc['comment'],
      avatarUrl: doc['avatarUrl'],
      timestamp: doc['timestamp'],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(comment),
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          ),
          subtitle: Text(timeago.format(timestamp.toDate())),
        ),
        Divider()
      ],
    );
  }
}
