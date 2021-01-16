import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'activity_feed.dart';
import 'profile.dart';
import 'timeline.dart';
import 'search.dart';
import 'create_account.dart';
import 'upload.dart';
import 'package:fluttershare/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final usersRef = FirebaseFirestore.instance.collection('users');
final postsRef = FirebaseFirestore.instance.collection('posts');
final commentsRef = FirebaseFirestore.instance.collection('comments');
final activityFeedRef = FirebaseFirestore.instance.collection('feed');
final followersRef = FirebaseFirestore.instance.collection('followers');
final followingRef = FirebaseFirestore.instance.collection('following');
final timelineRef = FirebaseFirestore.instance.collection('timeline');
final storageRef = FirebaseStorage.instance.ref();
final DateTime timestamp = DateTime.now();
User currentUser;

final GoogleSignIn googleSignIn = GoogleSignIn();
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isAuth = false;
  PageController pageController;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
    pageController = PageController(
      initialPage: 0
    );

    // detects when user signed in
    googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount account) {
      handleSignIN(account);
    }, onError: (err) {
      print('Error Sign In : $err');
    });

    // re authenticate user when app is open/reopen
    googleSignIn.signInSilently(suppressErrors: false)
      .then((account) {
        handleSignIN(account);
      }) .catchError((err) {
        print('Error Sign In : $err');
      });
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  // handles state after signing in
  handleSignIN(GoogleSignInAccount account) async{
    if(account != null){
      await createUserInFireStore();
      setState(() {
        isAuth = true;
      });
    } else {
      setState(() {
        isAuth = false;
      });
    }
  }

  createUserInFireStore() async{
    //1)check if user exists in users collection in database(according to their id)
    final GoogleSignInAccount user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.document(user.id).get();

    //2)if user doesn't exist, then take it to create account page
    if(!doc.exists){
      final username = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CreateAccount())
      );

      //3)get username from create account, use it to make new user document in users collection
      usersRef.document(user.id).setData({
        'id': user.id,
        'username': username,
        'photoUrl': user.photoUrl,
        'email': user.email,
        'displayName': user.displayName,
        'bio': '',
        'timestamp': timestamp
      });

      //making user their own followers
      await followersRef
          .document(user.id)
          .collection('userFollowers')
          .document(user.id)
          .setData({});

      //updating timeline(trigger)
      QuerySnapshot snapshot = await postsRef
          .document(user.id)
          .collection('userPosts')
          .getDocuments();

      snapshot.documents.forEach((doc) {
        if(doc.exists){
          timelineRef
              .document(user.id)
              .collection('timelinePosts')
              .document(doc.data()['postId'])
              .set(doc.data());
        }
      });

      doc = await usersRef.document(user.id).get();
    }
    currentUser = User.fromDocument(doc);
  }

  Future<void> login() async{
    try {
      await googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  void logout() {
    googleSignIn.signOut();
  }

  onPageChanged(int pageIndex) {
    setState(() {
      this.pageIndex = pageIndex;
    });
  }

  onTapBottomNavigator(int pageIndex) {
    pageController.animateToPage(
      pageIndex,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut
    );
  }

  Scaffold buildAuthScreen() {
    return Scaffold(
      body: PageView(
        children: [
          Timeline(currentUser: currentUser),
          ActivityFeed(),
          Upload(currentUser: currentUser),
          Search(),
          Profile(profileId: currentUser?.id)
        ],
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: pageIndex,
        onTap: onTapBottomNavigator,
        activeColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.whatshot)),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active)),
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera, size: 35.0,)),
          BottomNavigationBarItem(icon: Icon(Icons.search)),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle))
        ],
      ),
    );
  }

  Scaffold buildUnAuthScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).accentColor,
              Theme.of(context).primaryColor
            ]
          )
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:  CrossAxisAlignment.center,
          children: [
            Text(
              'Fire Share',
              style: TextStyle(
                fontFamily: 'Signatra',
                fontSize: 90.0,
                color: Colors.white
              ),
            ),
            GestureDetector(
              onTap: login,
              child: Container(
                width: 260.0,
                height: 60.0,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/google_signin_button.png'),
                    fit: BoxFit.cover
                  )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isAuth ? buildAuthScreen() : buildUnAuthScreen();
  }
}
