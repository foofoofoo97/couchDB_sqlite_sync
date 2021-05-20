import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:couchdb_sqlite_sync/dish.dart';
import 'package:couchdb_sqlite_sync/dish_publisher.dart';
import 'package:couchdb_sqlite_sync/todo_bloc.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DishBloc dishBloc = DishBloc();
  final DismissDirection _dismissDirection = DismissDirection.horizontal;
  final nameController = TextEditingController();
  final searchController = TextEditingController();
  StreamSubscription subscription;

  @override
  void dispose() {
    subscription.cancel();
    dishBloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    buildStreamSubscription();
  }

  void buildStreamSubscription() {
    subscription = DishPublisher.onChanges().asStream().listen((event) {
      print('Data received');
      event.listen((event) {
        print(event.result);
        DishPublisher.listen(event, dishBloc);
      });
    }, onDone: () {
      print("Task Done");
      subscription.cancel();
      buildStreamSubscription();
    }, onError: (error) {
      print("Some Error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Local Database')),
        body: SafeArea(
            child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.only(left: 2.0, right: 2.0, bottom: 2.0),
                child: Container(child: getData()))),
        bottomNavigationBar: BottomAppBar(
            color: Colors.white,
            child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: new Container(
                    color: Colors.transparent,
                    child: new Container(
                        height: 80,
                        decoration: new BoxDecoration(
                            color: Colors.white,
                            borderRadius: new BorderRadius.only(
                                topLeft: const Radius.circular(10.0),
                                topRight: const Radius.circular(10.0))),
                        child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Row(children: <Widget>[
                              Expanded(
                                  child: TextFormField(
                                      controller: nameController,
                                      textInputAction: TextInputAction.newline,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w400),
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                          hintText: 'Add your subject',
                                          hintStyle: TextStyle(fontSize: 15),
                                          labelText: 'Subject name',
                                          labelStyle: TextStyle(
                                              fontSize: 15,
                                              color: Colors.blue)),
                                      validator: (String value) {
                                        if (value.isEmpty) {
                                          return 'Empty description!';
                                        }
                                        return value.contains('')
                                            ? 'Do not use the @ char.'
                                            : null;
                                      })),
                              CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  radius: 18,
                                  child: IconButton(
                                      icon: Icon(
                                        Icons.save,
                                        size: 22,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        final newSubject = Dish(
                                            name: nameController.value.text,
                                            no: 0);
                                        if (newSubject.name.isNotEmpty) {
                                          dishBloc.addSubject(newSubject);
                                        }
                                      }))
                            ])))))));
  }

  getData() {
    return StreamBuilder(
      stream: dishBloc.subjectList,
      builder: (BuildContext context, AsyncSnapshot<List<Dish>> snapshot) {
        return getSubjectCardWidget(snapshot);
      },
    );
  }

  getSubjectCardWidget(AsyncSnapshot<List<Dish>> snapshot) {
    if (snapshot.hasData) {
      return snapshot.data.length != 0
          ? ListView.builder(
              itemCount: snapshot.data.length,
              itemBuilder: (context, itemPosition) {
                Dish subject = snapshot.data[itemPosition];
                final Widget dismissibleCard = new Dismissible(
                  background: Container(
                    child: Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Deleting",
                              style: TextStyle(color: Colors.blue),
                            ))),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  onDismissed: (direction) {
                    //DELETE DATA
                    dishBloc.deleteSubjectById(subject);
                  },
                  direction: _dismissDirection,
                  key: new ObjectKey(subject),
                  child: Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey[200], width: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      color: Colors.white,
                      child: ListTile(
                          trailing: IconButton(
                            icon: Icon(Icons.close),
                            color: Colors.red,
                            onPressed: () {
                              dishBloc.deleteSubjectById(subject);
                            },
                          ),
                          leading: InkWell(
                              onTap: () {
                                subject.no++;
                                dishBloc.updateSubject(subject);
                              },
                              child: Container(
                                  //decoration: BoxDecoration(),
                                  child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Text(
                                        subject.no.toString(),
                                      )))),
                          title: Text(
                            subject.name,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontFamily: 'RobotoMono',
                              fontWeight: FontWeight.w500,
                            ),
                          ))),
                );
                return dismissibleCard;
              })
          : Container(
              child: Center(
              child: noData(),
            ));
    } else {
      return Container();
    }
  }

  noData() {
    return Container(
        child: Text(
      "No data",
      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
    ));
  }
}
