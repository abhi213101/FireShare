import 'dart:async';
import 'package:animator/animator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/custom_image.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/comments.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'progress.dart';

class Post extends StatefulWidget {
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final dynamic likes;

  Post({
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }

  int getLikeCount(likes) {
    //if no likes return 0
    if(likes == null) {
      return 0;
    }

    int count = 0;

    //if key is explicitly true add like
    likes.values.forEach((val) {
      if(val == true) {
        count += 1;
      }
    });
    return count;
  }

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    description: this.description,
    mediaUrl: this.mediaUrl,
    likes: this.likes,
    likeCount: getLikeCount(this.likes)
  );
}

class _PostState extends State<Post> {
  final String currentUserId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  Map likes;
  int likeCount;
  bool isLiked;
  bool showHeart = false;

  _PostState({
    this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes,
    this.likeCount
  });

  addLikeToActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;

    if(isNotPostOwner){
      activityFeedRef
          .document(ownerId)
          .collection('feedItems')
          .document(postId)
          .setData({
        'type': 'like',
        'username': currentUser.username,
        'userId': currentUser.id,
        'userProfileImage': currentUser.photoUrl,
        'postId': postId,
        'mediaUrl': mediaUrl,
        'timestamp': timestamp
      });
    }
  }

  removeLikeFromActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;

    if(isNotPostOwner){
      activityFeedRef
          .document(ownerId)
          .collection('feedItems')
          .document(postId)
          .get().then((doc) {
        if(doc.exists) {
          doc.reference.delete();
        }
      });
    }
  }

  handleLikePost() async {
    bool _isLiked = likes[currentUserId] == true;

    if(_isLiked){
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({'likes.$currentUserId': false});
      removeLikeFromActivityFeed();
      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUserId] = false;
      });

      //updating timeline of followers(trigger)
      QuerySnapshot followerSnapshot = await followersRef
          .document(currentUser.id)
          .collection('userFollowers')
          .getDocuments();

      followerSnapshot.documents.forEach((doc) {
        timelineRef
            .document(doc.id)
            .collection('timelinePosts')
            .document(postId)
            .get().then((doc) {
              if(doc.exists){
                doc.reference.updateData({'likes.$currentUserId': false});
              }
            });
      });
    }
    else if(!_isLiked) {
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({'likes.$currentUserId': true});

      addLikeToActivityFeed();

      //updating timeline of followers(trigger)
      QuerySnapshot followerSnapshot = await followersRef
          .document(currentUser.id)
          .collection('userFollowers')
          .getDocuments();

      followerSnapshot.documents.forEach((doc) {
        timelineRef
            .document(doc.id)
            .collection('timelinePosts')
            .document(postId)
            .get().then((doc) {
          if(doc.exists){
            doc.reference.updateData({'likes.$currentUserId': true});
          }
        });
      });

      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUserId] = true;
        showHeart = true;
      });
      Timer(
        Duration(milliseconds: 500),
        () {
          setState(() {
            showHeart = false;
          });
        }
      );
    }

  }

  showComments(BuildContext context, {String postId, String ownerId, String mediaUrl}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        return Comments(
          postId: postId,
          postOwnerId: ownerId,
          postMediaUrl: mediaUrl
        );
      })
    );
  }

  handleDeletePost(BuildContext parentContext){
    return showDialog(
      context: parentContext,
      builder: (context) {
        return SimpleDialog(
          title: Text('Remove this post'),
          children: [
            SimpleDialogOption(
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                deletePost();
              },
            ),
            SimpleDialogOption(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      }
    );
  }

  deletePost() async{
    //delete the post
    postsRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .get().then((doc) {
        if(doc.exists){
          doc.reference.delete();
        }
      });

    //delete uploaded image for the post
    storageRef.child('post_$postId.jpg').delete();

    //delete all activity feed notifications
    QuerySnapshot activityFeedSnapshot = await activityFeedRef
                                                .document(ownerId)
                                                .collection('feedItems')
                                                .where('postId', isEqualTo: postId)
                                                .getDocuments();
    activityFeedSnapshot.documents.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });

    //delete all comments
    QuerySnapshot commentsSnapshot = await commentsRef
                                              .document(postId)
                                              .collection('comments')
                                              .getDocuments();
    commentsSnapshot.documents.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });

    //deleting from timeline of followers(trigger)
    QuerySnapshot followerSnapshot = await followersRef
        .document(currentUser.id)
        .collection('userFollowers')
        .getDocuments();

    followerSnapshot.documents.forEach((doc) {
      timelineRef
          .document(doc.id)
          .collection('timelinePosts')
          .document(postId)
          .get().then((doc) {
        if(doc.exists){
          doc.reference.delete();
        }
      });
    });

  }

  buildHeader() {
    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        bool isPostOwner = currentUserId == ownerId;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.photoUrl),
            backgroundColor: Colors.grey,
          ),
          title: GestureDetector(
            onTap: () => showProfile(context, profileId: user.id),
            child: Text(
              user.username,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          subtitle: Text(location),
          trailing: isPostOwner ? IconButton(
            onPressed: () => handleDeletePost(context),
            icon: Icon(
              Icons.more_vert
            ),
          ) : Text(''),
        );
      },
    );
  }

  buildPostImage() {
    return GestureDetector(
      onDoubleTap: handleLikePost,
      child: Stack(
        alignment: Alignment.center,
        children: [
          cachedNetworkImage(mediaUrl),
          showHeart ? Animator(
            duration: Duration(milliseconds: 300),
            tween: Tween(begin: 0.8, end: 1.4),
            curve: Curves.elasticOut,
            cycles: 0,
            builder: (anim) => Transform.scale(
              scale: anim.value,
              child: Icon(Icons.favorite, size: 80, color: Colors.red),
            ),
          ) : Text('')
        ],
      ),
    );
  }

  buildPostFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 40, right: 20)),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20)),
            GestureDetector(
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl
              ),
              child: Icon(
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              margin: EdgeInsets.only(left: 20),
              child: Text(
                '$likeCount likes',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                ),
              ),
            )
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(left: 20),
              child: Text(
                '$username ',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
            Expanded(
              child: Text(description),
            )
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    isLiked = (likes[currentUserId] == true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildHeader(),
        buildPostImage(),
        buildPostFooter()
      ],
    );
  }
}
