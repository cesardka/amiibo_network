import 'package:flutter/material.dart';
import 'package:amiibo_network/screen/home_page.dart';
import 'package:amiibo_network/screen/splash_screen.dart';
import 'package:amiibo_network/widget/route_transitions.dart';
import 'package:amiibo_network/service/service.dart';
import 'package:amiibo_network/provider/theme_provider.dart';
import 'package:amiibo_network/provider/amiibo_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:amiibo_network/themes.dart';
//import 'package:flutter/gestures.dart';

void main() async {
  //debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  String savedTheme = await getTheme();
  bool splash = await Service().compareLastUpdate();
  runApp(
    AmiiboNetwork(
      firstPage: splash ? Home() : SplashScreen(),
      theme: savedTheme,
    )
  );
}

class AmiiboNetwork extends StatelessWidget {
  final Widget firstPage;
  final String theme;
  AmiiboNetwork({this.firstPage, this.theme});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          builder: (context) => ThemeProvider(theme),
        ),
        ChangeNotifierProvider<AmiiboProvider>(
          builder: (context) => AmiiboProvider(),
        ),
        Consumer<ThemeProvider>(
          builder: (context, themeMode, child) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Themes.light,
            darkTheme: Themes.dark,
            onGenerateRoute: Routes.getRoute,
            themeMode: themeMode.preferredTheme,
            home: Builder(
              builder: (BuildContext context){
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Theme.of(context).scaffoldBackgroundColor,
                    systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor
                  ),
                  child: child,
                );
              }
            )
          ),
        ),
      ],
      child: firstPage,
    );
  }
}