import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fluttershare/widgets/progress.dart';
import 'package:fluttershare/models/user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as Im;
import 'package:uuid/uuid.dart';
import 'home.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Upload extends StatefulWidget {
  final User currentUser;

  Upload({this.currentUser});

  @override
  _UploadState createState() => _UploadState();
}

class _UploadState extends State<Upload> with AutomaticKeepAliveClientMixin<Upload>{
  TextEditingController locationController = TextEditingController();
  TextEditingController captionController = TextEditingController();
  File file;
  bool isUploading = false;
  String postId = Uuid().v4();

  compressImage() async{
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    Im.Image imageFile = Im.decodeImage(file.readAsBytesSync());
    final compressedImageFile = File('$path/img_$postId.jpg')..writeAsBytesSync(Im.encodeJpg(imageFile, quality: 85));
    setState(() {
      file = compressedImageFile;
    });
  }

  Future<String> uploadImage(File imageFile) async{
    UploadTask uploadTask = storageRef.child("post_$postId.jpg").putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  createPostInFireStore({String mediaUrl, String location, String caption}) async{
    postsRef
      .document(widget.currentUser.id)
      .collection('userPosts')
      .document(postId)
      .setData({
      'postId': postId,
      'ownerId': widget.currentUser.id,
      'username': widget.currentUser.username,
      'mediaUrl': mediaUrl,
      'description': caption,
      'location': location,
      'timestamp': timestamp,
      'likes': {},
    });

    // updating timeline of followers(trigger)
    QuerySnapshot followerSnapshot = await followersRef
                                              .document(widget.currentUser.id)
                                              .collection('userFollowers')
                                              .getDocuments();

    followerSnapshot.documents.forEach((doc) {
      timelineRef
        .document(doc.id)
        .collection('timelinePosts')
        .document(postId)
        .setData({
          'postId': postId,
          'ownerId': widget.currentUser.id,
          'username': widget.currentUser.username,
          'mediaUrl': mediaUrl,
          'description': caption,
          'location': location,
          'timestamp': timestamp,
          'likes': {}
          });
    });
  }

  handleSubmit() async{
    setState(() {
      isUploading = true;
    });
    await compressImage();
    String mediaUrl = await uploadImage(file);
    createPostInFireStore(
      mediaUrl: mediaUrl,
      location: locationController.text,
      caption: captionController.text
    );
    captionController.clear();
    locationController.clear();
    setState(() {
      file = null;
      isUploading = false;
    });
    Timer(
      Duration(milliseconds: 1000),
      () {
        setState(() {
          postId = Uuid().v4();
        });
      }
    );
  }

  handleTakePhoto() async{
    Navigator.pop(context);
    File file = await ImagePicker.pickImage(
      source: ImageSource.camera,
      maxHeight: 675,
      maxWidth: 960
    );
    setState(() {
      this.file = file;
    });
  }

  handleChooseImageFromGallery() async{
    Navigator.pop(context);
    File file = await ImagePicker.pickImage(
      source: ImageSource.gallery
    );
    setState(() {
      this.file = file;
    });
  }

  selectImage(BuildContext context){
    return showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Create Post'),
          children: [
            SimpleDialogOption(
              child: Text('Photo with Camera'),
              onPressed: handleTakePhoto,
            ),
            SimpleDialogOption(
              child: Text('Image from Gallery'),
              onPressed: handleChooseImageFromGallery,
            ),
            SimpleDialogOption(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      }
    );
  }

  clearImage() {
    setState(() {
      file = null;
    });
  }

  getUserLocation() async{
    Position position = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    List<Placemark> placemarks = await Geolocator().placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark placemark = placemarks[0];
    String formattedAddress = '${placemark.locality}, ${placemark.country}';
    locationController.text = formattedAddress;
  }

  buildUploadForm() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white70,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: clearImage,
        ),
        title: Text(
          'Caption Post',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          FlatButton(
            onPressed: isUploading ? null : () => handleSubmit(),
            child: Text(
              'Post',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20
              ),
            )
          )
        ],
      ),
      body: ListView(
        children: [
          isUploading ? linearProgress() : Text(""),
          Container(
            height: 220,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(file)
                    )
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(widget.currentUser.photoUrl),
            ),
            title: Container(
              width: 250,
              child: TextField(
                controller: captionController,
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  border: InputBorder.none
                ),
              ),
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.pin_drop, color: Colors.orange, size: 35),
            title: Container(
              width: 250,
              child: TextField(
                controller: locationController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'where was this photo taken?'
                ),
              ),
            ),
          ),
          Container(
            width: 200,
            height: 100,
            alignment: Alignment.center,
            child: RaisedButton.icon(
              color: Colors.blue,
              onPressed: getUserLocation,
              icon: Icon(
                Icons.my_location,
                color: Colors.white
              ),
              label: Text(''
                'Use Current Location',
                style: TextStyle(
                  color: Colors.white
                ),
              ),
              shape:  RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)
              ),
            ),
          )
        ],
      ),
    );
  }

  Container buildSplashScreen() {
    return Container(
      color: Theme.of(context).accentColor.withOpacity(0.6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/upload.jpg',
            height: 260.0,
          ),
          Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: RaisedButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)
              ),
              child: Text(
                'Upload Image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0
                ),
              ),
              color: Colors.deepOrange,
              onPressed: () => selectImage(context),
            ),
          )
        ],
      ),
    );
  }

  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return file == null ? buildSplashScreen() : buildUploadForm();
  }
}
