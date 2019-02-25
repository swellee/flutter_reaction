import 'package:reaction/reaction.dart';

class AddGoodsAction extends Action {
  String module =
      'shop'; // the moduleStore 's name that you given to regModule(name, xxStore)

  AddGoodsAction(payload) : super(payload);

  @override
  Future process(Map moduleStore) async {
    // override this 'async' process method ,
    // and return a Map contains the prop which to be modify

    // the param 'moduleStore'  is a copy of relative moduleStore
    // which this action's module property indicates, so, in this
    // case, it is a copy of shopStore

    // the action instance has a property 'payload' comes from action's constructor
    // and is a dynamic type, in this case, it is a goods info

    moduleStore['goods'].add(this.payload);
    int count = moduleStore['goods'].length;

    // shopStore's two property will be modified
    return {'goods': moduleStore['goods'], 'count': count};
  }
}
