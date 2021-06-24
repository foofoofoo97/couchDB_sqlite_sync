import 'package:couchdb_sqlite_sync/homepage_manager.dart';
import 'package:couchdb_sqlite_sync/model_class/order.dart';
import 'package:couchdb_sqlite_sync/repository/sort_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  HomePageManager homePageManager;

  bool isSql;
  bool isSync;
  SortOrder sortOrder;

  @override
  void initState() {
    isSql = true;
    isSync = true;
    sortOrder = SortOrder.ASCENDING;
    homePageManager =
        new HomePageManager(isSql: isSql, isSync: isSync, sortOrder: sortOrder);

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
                        child: Text('${isSql == true ? 'SQLITE' : 'COUCHDB'}'),
                        color: Colors.lightGreenAccent,
                        onPressed: () {
                          setState(() {
                            isSql = !isSql;
                            homePageManager.setIsSql(isSql: isSql);
                          });
                        },
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      FlatButton(
                        child:
                            Text('${isSync == true ? 'ON SYNC' : 'OFF SYNC'}'),
                        color: Colors.yellow,
                        onPressed: () {
                          setState(() {
                            isSync = !isSync;
                            homePageManager.updateSync(isSync: isSync);
                          });
                        },
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      FlatButton(
                        child: Text('INSERT'),
                        color: Colors.cyanAccent,
                        onPressed: () async {
                          Order order1 = new Order(name: 'order1', no: 100);
                          Order order2 = new Order(name: 'order2', no: 200);

                          homePageManager.insertDoc(order: order1);
                          homePageManager.insertDoc(order: order2);
                        },
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      FlatButton(
                        child: Text(
                            sortOrder == SortOrder.ASCENDING ? "ASC" : "DESC"),
                        color: Colors.cyanAccent,
                        onPressed: () async {
                          setState(() {
                            sortOrder = sortOrder == SortOrder.ASCENDING
                                ? SortOrder.DESCENDING
                                : SortOrder.ASCENDING;
                          });

                          homePageManager.changeOrder(sortOrder: sortOrder);
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
                                          Order order = new Order(
                                              name: nameController.text
                                                  .toString(),
                                              no: 0);
                                          await homePageManager.insertDoc(
                                              order: order);
                                        }
                                      }))
                            ])))))));
  }

  getData() {
    return new StreamBuilder<List<Order>>(
      stream: homePageManager.stream,
      builder: (BuildContext context, AsyncSnapshot<List<Order>> snapshot) {
        return getSubjectCardWidget(snapshot);
      },
    );
  }

  getSubjectCardWidget(AsyncSnapshot<List<Order>> snapshot) {
    if (snapshot.hasData) {
      return snapshot.data.length != 0
          ? ListView.builder(
              itemCount: snapshot.data.length,
              itemBuilder: (context, itemPosition) {
                Order order = snapshot.data[itemPosition];

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
                    await homePageManager.deleteDoc(order: order);
                  },
                  direction: _dismissDirection,
                  key: new ObjectKey(order),
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
                              await homePageManager.deleteDoc(order: order);
                            },
                          ),
                          leading: InkWell(
                              onTap: () async {
                                order.no++;
                                await homePageManager.updateDoc(order: order);
                              },
                              child: Container(
                                  //decoration: BoxDecoration(),
                                  child: Padding(
                                      padding: const EdgeInsets.all(15.0),
                                      child: Text(
                                        order.no.toString(),
                                      )))),
                          title: Text(
                            order.name,
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
