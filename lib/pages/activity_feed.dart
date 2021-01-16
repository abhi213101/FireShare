import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/pages/post_screen.dart';
import 'package:fluttershare/pages/profile.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityFeed extends StatefulWidget {
  @override
  _ActivityFeedState createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {

  getActivityFeed() async{
    QuerySnapshot snapshot = await activityFeedRef
                                    .document(currentUser.id)
                                    .collection('feedItems')
                                    .orderBy("timestamp", descending: true)
                                    .limit(50)
                                    .getDocuments();
    List<ActivityFeedItem> feedItems = [];

    snapshot.documents.forEach((doc) {
      feedItems.add(ActivityFeedItem.fromDocument(doc));
    });
    return feedItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      appBar: header(context, titleText: 'Activity Feed'),
      body: Container(
        child: FutureBuilder(
          future: getActivityFeed(),
          builder: (context, snapshot) {
            if(!snapshot.hasData){
              return circularProgress();
            }
            return ListView(
              children: snapshot.data,
            );
          },
        ),
      ),
    );
  }
}

Widget mediaPreview;
String activityItemText;

class ActivityFeedItem extends StatelessWidget {
  final String username;
  final String userId;
  final String type; // like, comment, follow
  final String mediaUrl;
  final String postId;
  final String userProfileImage;
  final String commentData;
  final Timestamp timestamp;

  ActivityFeedItem({
    this.username,
    this.userId,
    this.type,
    this.timestamp,
    this.mediaUrl,
    this.postId,
    this.commentData,
    this.userProfileImage
  });

  factory ActivityFeedItem.fromDocument(doc) {
    return ActivityFeedItem(
      username: doc.data()['username'],
      userId: doc.data()['userId'],
      type: doc.data()['type'],
      timestamp: doc.data()['timestamp'],
      mediaUrl: doc.data()['mediaUrl'],
      postId: doc.data()['postId'],
      commentData: doc.data()['commentData'],
      userProfileImage: doc.data()['userProfileImage'],
    );
  }

  showPost(context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostScreen(postId: postId, userId: userId))
    );
  }

  configureMediaPreview(context) {
    if(type == 'like' || type == 'comment'){
      mediaPreview = GestureDetector(
        onTap: () => showPost(context),
        child: Container(
          height: 50,
          width: 50,
          child: AspectRatio(
            aspectRatio: 16/9,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: CachedNetworkImageProvider(mediaUrl)
                )
              ),
            ),
          ),
        ),
      );
    }
    else{
      mediaPreview = Text('');
    }

    if(type == 'like'){
      activityItemText = 'liked your post';
    }
    else if(type =='follow'){
      activityItemText = 'is following you';
    }
    else if(type == 'comment'){
      activityItemText = 'replied: $commentData';
    }
    else{
      activityItemText = 'Erroe: Unknown type: $type';
    }
  }

  @override
  Widget build(BuildContext context) {
    configureMediaPreview(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Container(
        color: Colors.white54,
        child: ListTile(
          title: GestureDetector(
            onTap: () => showProfile(context, profileId: userId),
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold
                    )
                  ),
                  TextSpan(
                    text: ' $activityItemText'
                  )
                ]
              ),
            ),
          ),
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(userProfileImage),
          ),
          subtitle: Text(
            timeago.format(timestamp.toDate()),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: mediaPreview,
        ),
      ),
    );
  }
}

showProfile(BuildContext context, {String profileId}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => Profile(profileId: profileId))
  );
}