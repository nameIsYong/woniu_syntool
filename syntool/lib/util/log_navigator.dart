import 'package:flutter/material.dart';

class LogNavigator extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    // Logger().w("${previousRoute?.settings.name} --> ${route.settings.name}");
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is MaterialPageRoute) {
      String name = route.builder.toString().split("=>").last;
      print("进入页面:$name");
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    // TODO: implement didRemove
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    // TODO: implement didReplace
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {
    // TODO: implement didStartUserGesture
    super.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    // TODO: implement didStopUserGesture
    super.didStopUserGesture();
  }
}
