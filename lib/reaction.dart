library reaction;

import 'package:flutter/widgets.dart';

class Action {
  String module = 'module_name';
  dynamic payload;

  /// when call doAction,usually you need to pass some data
  /// the data (here called payload) you may use in process method
  Action([this.payload]);

  /// @param moduleStore the [copy] of module store your action's module indicates
  /// you can use this action's payload data, deal with it or fetch api or something else
  /// when finished , you need return a Map that tell me which property was modified of the module store
  /// eg.
  /// // outside you have a module store like this:
  /// {
  /// 'name': 'reaction'
  /// };
  /// // once you wanner rename 'reaction' to 'flutter-reaction'
  /// doAction(RenameAction('flutter-reaction'));
  /// // then in the class RenameAction's process method, code is like:
  /// Future<dynamic> process(Map moduleStore) async {
  /// bool renameOk = await fetch(someApi);
  /// if (renameOk) {
  /// // server said we rename succeed
  /// return {'name': this.payload} // this.payload's value is 'flutter-reaction'
  /// // then the module store's property [name] will be modified to 'flutter-reaction'
  /// // if your widget is inherits ModuleState class, it will fresh render with the new 'name' value which is 'flutter-reaction'
  /// }
  /// return {}; // server fail, so return a blank map to tell me nothing was modified
  /// }
  Future<dynamic> process(Map moduleStore) async {
    return {};
  }

  /**
 * in one action's process method,
 * if you want start another action follow closely,
 * you can call this method. otherwise, [don't !]
 */
  void doChildAction(Action action) => _GlobalStore.actionQueue
      .insert(_GlobalStore.actionQueue.indexOf(this) + 1, action);
}

class _FnAction extends Action {
  Function fn;
  @override
  Future process(Map moduleStore) async {
    if (fn != null) {
      this.fn();
    }
    return {};
  }
}

const String MODULE_COMMON = 'common';

class LoadingShowAction extends Action {
  String module = MODULE_COMMON;
  LoadingShowAction(payload) : super(payload);
}

class _GlobalStore {
  static Map state = new Map();
  static Map<String, Set> listeners = new Map<String, Set>();
  static List<Action> actionQueue = [];

  static regModule(String module, Map store) {
    if (!state.containsKey(module)) {
      state[MODULE_COMMON] = {
        MODULE_COMMON: {'loading': 'none'}
      };
    }
    state[module] = store;
  }

  static listenProps(String module, inst) {
    if (!listeners.containsKey(module)) {
      listeners[module] = new Set();
    }
    listeners[module].add(inst);
  }

  static unListenProps(String module, inst) {
    if (!listeners.containsKey(module)) {
      return;
    }
    listeners[module].remove(inst);
  }

  static doAction(Action action, [String loading = 'none']) {
    int canStartCnt = 1;
    if (loading != null && loading != 'none') {
      actionQueue.addAll([
        new LoadingShowAction({'loading': loading}),
        action,
        new LoadingShowAction({'loading': 'none'})
      ]);
      canStartCnt = 3;
    } else {
      actionQueue.add(action);
    }

    if (actionQueue.length == canStartCnt) {
      _nextAction();
    }
  }

  static _nextAction() async {
    if (actionQueue.length == 0) {
      return;
    }

    Action act = actionQueue[0];
    Map mst = state[act.module];
    // make a copy of mst to avoid action's process modify directly
    Map mstCopy = mst == null ? null : Map.fromEntries(mst.entries);
    // run process even if mst is null
    Map data = await act.process(mstCopy);
    if (mst != null) {
      // modify msg
      data.forEach((k, v) => mst[k] = v);
      _notifyChg(act.module);
    }

    await new Future.delayed(new Duration());
    actionQueue.removeAt(0);

    _nextAction();
  }

  static _notifyChg(String module) {
    Set ms = listeners[module];
    if (ms != null) {
      ms.forEach((f) => f.hear(module));
    }
  }
}

/// register a module store
void regModule(String module, Map<String, dynamic> store) {
  _GlobalStore.regModule(module, store);
}

/// get specific module store's prop
dynamic getModuleProp(String module, String propName) {
  if (_GlobalStore.state.containsKey(module)) {
    var prop = _GlobalStore.state[module][propName];
    if (prop is List) {
      return prop.sublist(0);
    } else if (prop is Set) {
      return prop.toSet();
    } else if (prop is Map) {
      return Map.fromEntries(prop.entries);
    } else {
      return prop;
    }
  }
}

/// run a action in queue
/// the actions will run one by one in queue,
/// and action.doChildAction(xx) will insert a action in current queue order
/// eg.
/// doAction(actionA);
/// //in actionA's process Method: if call
/// this.doChildAction(actionC); // this = actionA
/// doAction(actionB);
///
/// then the order to run action is :
/// -actionA
/// -actionC
/// -actionB
void doAction(Action action, [String loading]) {
  _GlobalStore.doAction(action, loading);
}

/// quick way to start a pure function as a action
void doFunction(void Function() fn) {
  _FnAction action = _FnAction();
  action.fn = fn;
  _GlobalStore.doAction(action);
}

///  must init [cares]' value in class property defination
///  like: class _xxState extends ModuleState<SomeUI> {
///  cares = {'moduleA': ['a','b','c'], 'moduleB': ['c:cc', 'd']}
///  }
///  then you xxSate instance will have a props like:
///  this.props.a = globalStore.moduleA.a
///  this.props.b = globalStore.moduleA.b
///  this.props.c = globalStore.moduleA.c
///
///  // 'c:cc' will make sense as bellow:
///  this.props.cc = globalStore.moduleB.c
///  this.props.d = globalStore.moduleB.d
abstract class ModuleState<T extends StatefulWidget> extends State<T> {
  Map<String, dynamic> props = new Map();
  Map<String, List<String>> cares;

  @override
  initState() {
    super.initState();

    if (null == cares) {
      throw Error.safeToString('''
        must init [cares]' value in class property defination
        like: class _xxState extends ModuleState<SomeUI> {
          cares = {'moduleA': ['a','b','c'], 'moduleB': ['c:cc', 'd']}
        } 
        then you xxSate instance will have a props like:
        this.props.a = globalStore.moduleA.a
        this.props.b = globalStore.moduleA.b
        this.props.c = globalStore.moduleA.c

        // 'c:cc' will make sense as bellow:
        this.props.cc = globalStore.moduleB.c
        this.props.d = globalStore.moduleB.d

      ''');
    }
    _injectCares();
    _updateCared();
  }

  _injectCares() {
    if (cares == null) {
      return;
    }
    cares.forEach((module, s) {
      _GlobalStore.listenProps(module, this);
    });
  }

  _ejectCares() {
    if (cares == null) {
      return;
    }
    cares.forEach((module, s) {
      _GlobalStore.unListenProps(module, this);
    });
    cares = null;
  }

  _updateCared() {
    cares.forEach((m, ps) {
      ps.forEach((String p) {
        var o, k;
        o = k = p;
        if (p.contains(':')) {
          var arr = p.split(':');
          o = arr[0];
          k = arr[1];
        }

        // add or set property from modulestore
        Map ms = _GlobalStore.state[m];
        if (ms != null) {
          var v = ms[o];
          var nv;
          if (v is List) {
            nv = v.sublist(0);
          } else if (v is Set) {
            nv = v.toSet();
          } else if (v is Map) {
            nv = Map.fromEntries(v.entries);
          } else {
            nv = v;
          }
          this.props[k] = nv;
        }
      });
    });
  }

  hear(String module) {
    this.setState(this._updateCared);
  }

  @override
  dispose() {
    _ejectCares();
    super.dispose();
  }
}
