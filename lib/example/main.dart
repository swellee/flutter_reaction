import 'package:flutter/material.dart';
import 'package:flutter_reaction/example/add_goods_action.dart';
import 'package:flutter_reaction/example/shop_store.dart';
import 'package:flutter_reaction/example/user_store.dart';

import '../reaction.dart';

const String Module_User = 'user';
const String Module_shop = 'shop';
void main() {
  // reg module store first of all
  regModule(Module_User, userStore);
  regModule(Module_shop, shopStore);

  // start app
  runApp(OrderPage());
}

class OrderPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _OrderState();
  }
}

// in order to inject the module store data,
// you state class should extends 'ModuleState',
class _OrderState extends ModuleState<OrderPage> {
  // ! important, give this property called 'cares'
  // to tell ModuleState which moduleStore you wanner inject here
  Map<String, List<String>> cares = {
    Module_User: [
      'name:buyer',
      'coin',
      'addr'
    ], // inject userStore's ['name','coin','addr'], and rename 'name' to 'buyer'
    Module_shop: [
      'goods',
      'count:num'
    ] // inject shopStore's ['goods','count'], and rename 'count' to 'num' here
  };

  @override
  Widget build(BuildContext context) {
    String buyer = this.props['buyer'];
    String buyerAddress = this.props['addr'];
    int buyerCoint = this.props['coin'];
    int buyCount = this.props['num'];
    return Scaffold(
      body: Text(
          'welcome $buyer, you have $buyerCoint coins. today you bought $buyCount s' +
              this.props['goods'].toString() +
              'and your goods will be send to $buyerAddress'),
      floatingActionButton: FloatingActionButton(
        child: Text('buy'),
        onPressed: () =>
            doAction(AddGoodsAction({'name': 'Beer', 'price': 10})),
      ),
    );
  }
}
