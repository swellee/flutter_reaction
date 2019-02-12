library reaction;

import 'package:flutter/widgets.dart';

class Action {
  String module = 'action';
  Map payload;
  Action([this.payload]);
  Future<dynamic> process(Map moduleStore) async {
    return payload;
  }

  /**
 * sometimes you can startUp anohter actions once this action finished
 * action 的 process执行时候，如果需要在此action结束时立即启动另外一个action, 使用此方法
 * 其他情况不能使用
 */
  void doChildAction(Action action) {
    _GlobalStore.actionQueue
        .insert(_GlobalStore.actionQueue.indexOf(this) + 1, action);
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
    Map data = await act.process(mst);
    if (mst != null) {
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

/**
 * register a module store, which is a Map<String, dynamic>
 * eg. A user store like : {'username': '', 'passwd': ''}
 */
void regModule(String module, Map<String, dynamic> store) {
  _GlobalStore.regModule(module, store);
}

/**
 * to modify a module store, you should call this method;
 * action will append to the action-queue, and execute one by one.
 * so if you call: doAction(actionA); doAction(actionB), the actionB will execute when the actionA finished
 */
void doAction(Action action, [String loading]) {
  _GlobalStore.doAction(action, loading);
}

/**
 * typically, one module's UI and action can ONLY use the module store which it belongs,
 * while, sometimes, you can use this method to access other module store's props
 */
dynamic getModuleProp(String module, String propName) {
  if (_GlobalStore.state.containsKey(module)) {
    return _GlobalStore.state[module][propName];
  }
  return null;
}

/**
 * must init [cares]' value in class property defination
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
 */
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
    cares.forEach((module, s) {
      _GlobalStore.listenProps(module, this);
    });
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
          this.props[k] = ms[o];
        }
      });
    });
  }

  hear(String module) {
    this.setState(this._updateCared);
  }

  /// @param action the Action instance
  /// @param loading optional, default is 'none', when other ,indicates this action will show loading
  doAction(Action action, [String loading]) {
    _GlobalStore.doAction(action, loading);
  }
}
