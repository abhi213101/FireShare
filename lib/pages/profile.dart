import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/widgets/post_tile.dart';
import 'home.dart';
import 'edit_profile.dart';

class Profile extends StatefulWidget {
  final String profileId;

  Profile({this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  bool isFollowing = false;
  final String currentUserId = currentUser?.id;
  String postOrientation = 'grid';
  bool isLoading = false;
  int postCount = 0;
  int followerCount = 0;
  int followingCount = 0;
  List<Post> posts = [];

  @override
  void initState(){
    super.initState();
    getProfilePosts();
    getFollowers();
    getFollowing();
    checkIfFollowing();
  }

  checkIfFollowing() async{
    DocumentSnapshot doc = await followersRef
                                  .document(widget.profileId)
                                  .collection('userFollowers')
                                  .document(currentUserId)
                                  .get();
    setState(() {
      isFollowing = doc.exists;
    });
  }

  getFollowers() async{
    QuerySnapshot snapshot = await followersRef
                                    .document(widget.profileId)
                                    .collection('userFollowers')
                                    .getDocuments();
    setState(() {
      followerCount = snapshot.documents.length;
    });
  }

  getFollowing() async{
    QuerySnapshot snapshot = await followingRef
                                      .document(widget.profileId)
                                      .collection('userFollowing')
                                      .getDocuments();
    setState(() {
      followingCount = snapshot.documents.length;
    });
  }

  getProfilePosts() async{
    setState(() {
      isLoading = true;
    });
    QuerySnapshot snapshot = await postsRef
                                .document(widget.profileId)
                                .collection('userPosts')
                                .orderBy('timestamp', descending: true)
                                .getDocuments();
    setState(() {
      isLoading = false;
      postCount = snapshot.documents.length;
      posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
      postCount = snapshot.documents.length;
    });
  }

  buildProfilePost() {
    if(isLoading) {
      return circularProgress();
    }
    else if(posts.isEmpty) {
      return Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/no_content.jpg',
              height: 260.0,
            ),
            Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Text(
                'No Posts',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.bold
                ),
              )
            )
          ],
        ),
      );
    }
    else if(postOrientation == 'grid'){
      List<GridTile> gridTiles = [];
      posts.forEach((post) {
        gridTiles.add(GridTile(child: PostTile(post)));
      });
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    }
    else if(postOrientation == 'list'){
      return Column(
        children: posts,
      );
    }
  }

  setPostOrientation(String postOrientation) {
    setState(() {
      this.postOrientation = postOrientation;
    });
  }

  buildTogglePostOrientation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.grid_on),
          color: postOrientation=='grid' ? Theme.of(context).primaryColor : Colors.grey,
          onPressed: () => setPostOrientation('grid')
        ),
        IconButton(
          icon: Icon(Icons.list),
          color: postOrientation=='list' ? Theme.of(context).primaryColor : Colors.grey,
          onPressed: () => setPostOrientation('list')
        )
      ],
    );
  }

  Column buildCountColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w400
            ),
          ),
        )
      ],
    );
  }

  editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfile(currentUserId: currentUserId))
    );
  }

  Container buildButton({String text, Function function}) {
    return Container(
      padding: EdgeInsets.only(top: 2),
      child: FlatButton(
        onPressed: function,
        child: Container(
          width: 250,
          height: 27,
          child: Text(
            text,
            style: TextStyle(
              color: isFollowing ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold
            ),
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFollowing ? Colors.white : Colors.blue,
            border: Border.all(
              color: isFollowing ? Colors.grey : Colors.blue
            ),
            borderRadius: BorderRadius.circular(5)
          ),
        ),
      ),
    );
  }

  handleUnfollowUser() async{
    setState(() {
      isFollowing = false;
    });

    //remove follower
    followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId)
        .get().then((doc) {
          if(doc.exists){
            doc.reference.delete();
          }
        });

    //remove following
    followingRef
        .document(currentUserId)
        .collection('userFollowing')
        .document(widget.profileId)
        .get().then((doc) {
          if(doc.exists){
            doc.reference.delete();
          }
        });

    //deleting activity feed
    activityFeedRef
        .document(widget.profileId)
        .collection('feedItems')
        .document(currentUserId)
        .get().then((doc) {
          if(doc.exists){
            doc.reference.delete();
          }
        });

    QuerySnapshot timelinePosts = await timelineRef
                                          .document(currentUserId)
                                          .collection('timelinePosts')
                                          .where('ownerId', isEqualTo: widget.profileId)
                                          .get();

    timelinePosts.documents.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });
  }

  handleFollowUser() async{
    setState(() {
      isFollowing = true;
    });

    //make auth user follower of another user and update their followers collection
    followersRef
      .document(widget.profileId)
      .collection('userFollowers')
      .document(currentUserId)
      .setData({});

    //put that user on your following collection
    followingRef
      .document(currentUserId)
      .collection('userFollowing')
      .document(widget.profileId)
      .setData({});

    //add activity feed item for that user to notify about new follower
    activityFeedRef
      .document(widget.profileId)
      .collection('feedItems')
      .document(currentUserId)
      .setData({
        'type': 'follow',
        'ownerId': widget.profileId,
        'username': currentUser.username,
        'userId': currentUserId,
        'userProfileImage': currentUser.photoUrl,
        'timestamp': timestamp
      });

    // update timeline of user(trigger)
    QuerySnapshot snapshot = await postsRef
        .document(widget.profileId)
        .collection('userPosts')
        .getDocuments();

    snapshot.documents.forEach((doc) {
      if(doc.exists){
        timelineRef
            .document(currentUserId)
            .collection('timelinePosts')
            .document(doc.data()['postId'])
            .set(doc.data());
      }
    });
  }

  buildProfileButton() {
    //viewing own profile => show edit profile button
    bool isProfileOwner = currentUserId == widget.profileId;

    if(isProfileOwner) {
      return buildButton(
        text: 'Edit Profile',
        function: editProfile
      );
    }
    else if(isFollowing) {
      return buildButton(text: 'Unfollow', function:  handleUnfollowUser);
    }
    else if(!isFollowing) {
      return buildButton(text: 'Follow', function:  handleFollowUser);
    }
  }

  buildProfileHeader() {
    return FutureBuilder(
      future: usersRef.document(widget.profileId).get(),
      builder: (context, snapshot) {
        if(!snapshot.hasData){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    backgroundImage: CachedNetworkImageProvider(user.photoUrl),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildCountColumn("posts", postCount),
                            buildCountColumn("followers", followerCount),
                            buildCountColumn("following", followingCount),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildProfileButton()
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  user.displayName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  user.bio,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, titleText: 'Profile'),
      body: ListView(
        children: [
          buildProfileHeader(),
          Divider(),
          buildTogglePostOrientation(),
          Divider(
            height: 0.0,
          ),
          buildProfilePost()
        ],
      )
    );
  }
}
