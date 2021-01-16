import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/search.dart';
import 'home.dart';

final FirebaseFirestore firestore = FirebaseFirestore.instance;

class Timeline extends StatefulWidget {
  final User currentUser;

  Timeline({this.currentUser});
  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  List<Post> posts;
  List<String> followingList;

  @override
  void initState() {
    super.initState();
    getTimeline();
    getFollowing();
  }

  getFollowing() async{
    QuerySnapshot snapshot =  await followingRef
                                      .document(currentUser.id)
                                      .collection('userFollowing')
                                      .getDocuments();
    setState(() {
      followingList = snapshot.documents.map((doc) => doc.documentID).toList();
    });
  }

  getTimeline() async{
    QuerySnapshot snapshot = await timelineRef
                                    .document(widget.currentUser.id)
                                    .collection('timelinePosts')
                                    .orderBy('timestamp', descending: true)
                                    .getDocuments();

    List<Post> posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    setState(() {
      this.posts = posts;
    });
  }

  buildUsersToFollow() {
    return StreamBuilder(
      stream: usersRef.orderBy('timestamp', descending: true).limit(30).snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return circularProgress();
        }
        List<UserResult> userResults = [];
        snapshot.data.documents.forEach((doc){
          User user  = User.fromDocument(doc);
          final bool isAuthUser = currentUser.id == user.id;
          final bool isFollowingUser = followingList.contains(user.id);
          if(isAuthUser) {
            return;
          }
          else if(isFollowingUser){
            return;
          }
          else{
            UserResult userResult = UserResult(user);
            userResults.add(userResult);
          }
        });
        return Container(
          color: Theme.of(context).accentColor.withOpacity(0.2),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(
                       Icons.person_add,
                       color: Theme.of(context).primaryColor,
                       size: 30,
                     ),
                     SizedBox(width: 8),
                     Text(
                       'Users to Follow',
                       style: TextStyle(
                         color: Theme.of(context).primaryColor,
                         fontSize: 30
                       ),
                     )
                   ],
                 ),
              ),
              Column(
                children: userResults,
              )
            ],
          ),
        );
      },
    );
  }

  buildTimeline() {
    if(posts == null) {
      return circularProgress();
    }
    else if(posts.isEmpty){
      return buildUsersToFollow();
    }
    return ListView(
      children: posts,
    );
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: header(context, isAppTitle: true),
      body: RefreshIndicator(
        onRefresh: () => getTimeline(),
        child: buildTimeline(),
      ),
    );
  }
}