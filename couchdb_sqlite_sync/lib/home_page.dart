import 'dart:convert';
import 'package:couchdb_sqlite_sync/dish_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:couchdb_sqlite_sync/model_class/dish.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DismissDirection _dismissDirection = DismissDirection.horizontal;
  final nameController = TextEditingController();
  final searchController = TextEditingController();

  bool isSqlite;
  bool isSync;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    isSqlite = true;
    isSync = true;
    DishStream(isSqlite: isSqlite, isSyc: isSync);
    super.initState();
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
                child: Column(children: <Widget>[
                  SizedBox(
                    height: 8.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        child:
                            Text('${isSqlite == true ? 'SQLITE' : 'COUCHDB'}'),
                        color: Colors.lightGreenAccent,
                        onPressed: () {
                          setState(() {
                            isSqlite = !isSqlite;
                            DishStream.setIsSql(isSqlite);
                          });
                        },
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      FlatButton(
                        child:
                            Text('${isSync == true ? 'ON SYNC' : 'OFF SYNC'}'),
                        color: Colors.yellow,
                        onPressed: () {
                          setState(() {
                            isSync = !isSync;
                            DishStream.updateSync(isSync);
                          });
                        },
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      FlatButton(
                        child: Text('SYNC INSERT'),
                        color: Colors.cyanAccent,
                        onPressed: () async {
                          Dish dish1 = new Dish(
                              data: jsonEncode({"name": 'test1', "no": 100}));
                          Dish dish2 = new Dish(
                              data: jsonEncode({"name": 'test2', "no": 200}));
                          DishStream.insertDish(dish: dish1);
                          DishStream.insertDish(dish: dish2);
                        },
                      ),
                    ],
                  ),
                  Expanded(child: getData())
                ]))),
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
                                      onPressed: () async {
                                        //TO BE CHANGE
                                        if (nameController
                                            .value.text.isNotEmpty) {
                                          Dish dish = new Dish(
                                              data: jsonEncode({
                                            "name":
                                                nameController.text.toString(),
                                            "no": 0
                                          }));
                                          await DishStream.insertDish(
                                              dish: dish);
                                        }
                                      }))
                            ])))))));
  }

  getData() {
    return new StreamBuilder<List<Dish>>(
      stream: DishStream.dishStream,
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
                  onDismissed: (direction) async {
                    //DELETE DATA
                    await DishStream.deleteDish(dish: subject);
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
                            onPressed: () async {
                              await DishStream.deleteDish(dish: subject);
                            },
                          ),
                          leading: InkWell(
                              onTap: () async {
                                Map data = jsonDecode(subject.data);
                                data['no']++;
                                subject.data = jsonEncode(data);

                                await DishStream.updateDish(dish: subject);
                              },
                              child: Container(
                                  //decoration: BoxDecoration(),
                                  child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Text(
                                        jsonDecode(subject.data)['no']
                                            .toString(),
                                      )))),
                          title: Text(
                            jsonDecode(subject.data)['name'],
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
