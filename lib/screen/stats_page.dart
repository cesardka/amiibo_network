import 'dart:async';
import 'package:amiibo_network/model/stat.dart';
import 'package:amiibo_network/riverpod/query_provider.dart';
import 'package:amiibo_network/riverpod/service_provider.dart';
import 'package:amiibo_network/service/screenshot.dart';
import 'package:flutter/material.dart';
import 'package:amiibo_network/service/storage.dart';
import 'package:amiibo_network/generated/l10n.dart';
import 'package:amiibo_network/widget/single_stat.dart';
import 'package:amiibo_network/service/notification_service.dart';
import 'package:amiibo_network/model/search_result.dart';
import 'package:amiibo_network/enum/amiibo_category_enum.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _statsProvider =
    StreamProvider.autoDispose.family<List<Stat>, Expression>((ref, exp) {
  final service = ref.watch(serviceProvider.notifier);
  final streamController = StreamController<Expression>()..sink.add(exp);

  void listener() => streamController.sink.add(exp);

  service.addListener(listener);

  ref.onDispose(() {
    service.removeListener(listener);
    streamController.close();
  });

  return streamController.stream.asyncMap(
    (cb) async => <Stat>[
      ...await service.fetchStats(expression: cb),
      ...await service.fetchStats(group: true, expression: cb)
    ],
  );
});

class StatsPage extends StatefulHookConsumerWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  AmiiboCategory category = AmiiboCategory.All;
  Expression expression = And();
  S? translate;
  late Size size;

  @override
  void didChangeDependencies() {
    translate = S.of(context);
    size = MediaQuery.of(context).size;
    super.didChangeDependencies();
  }

  void _updateCategory(WidgetRef ref, AmiiboCategory newCategory) {
    if (newCategory == category) return;
    setState(() {
      category = newCategory;
      switch (category) {
        case AmiiboCategory.All:
          expression = And();
          break;
        case AmiiboCategory.Custom:
          final query = ref.read(queryProvider.notifier);
          expression = Bracket(InCond.inn('type', figureType) &
                  InCond.inn('amiiboSeries', query.customFigures)) |
              Bracket(Cond.eq('type', 'Card') &
                  InCond.inn('amiiboSeries', query.customCards));
          break;
        case AmiiboCategory.Figures:
          expression = InCond.inn('type', figureType);
          break;
        case AmiiboCategory.Cards:
          expression = Cond.eq('type', 'Card');
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final _canSave = ref.watch(
      querySearchProvider.select<bool>((value) =>
          AmiiboCategory.Custom != category ||
          value.customFigures!.isNotEmpty ||
          value.customCards!.isNotEmpty),
    );
    if (size.longestSide >= 800)
      return SafeArea(
        child: Scaffold(
          body: Scrollbar(
            child: Row(
              children: <Widget>[
                NavigationRail(
                  destinations: <NavigationRailDestination>[
                    NavigationRailDestination(
                      icon: const Icon(Icons.all_inclusive),
                      label: Text(translate!.all),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.edit_outlined),
                      selectedIcon: const Icon(Icons.edit),
                      label: Text(translate!.category(AmiiboCategory.Custom)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.sports_esports_outlined),
                      selectedIcon: const Icon(Icons.sports_esports),
                      label: Text(translate!.figures),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.view_carousel_outlined),
                      selectedIcon: const Icon(Icons.view_carousel),
                      label: Text(translate!.cards),
                    )
                  ],
                  selectedIndex: category.index,
                  trailing: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _canSave
                          ? _FAB(category, expression)
                          : const SizedBox(),
                    ),
                  ),
                  onDestinationSelected: (selected) =>
                      _updateCategory(ref, AmiiboCategory.values[selected]),
                ),
                Expanded(child: _BodyStats(expression))
              ],
            ),
          ),
        ),
      );
    return SafeArea(
      child: Scaffold(
        body: _BodyStats.expanded(expression),
        floatingActionButton: _canSave ? _FAB(category, expression) : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        extendBody: true,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: _canSave
                ? const EdgeInsetsDirectional.only(end: 64)
                : EdgeInsets.zero,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.all_inclusive_outlined),
                  activeIcon: const Icon(Icons.all_inclusive_sharp),
                  label: translate!.all,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.edit_outlined),
                  activeIcon: const Icon(Icons.edit),
                  label: translate!.category(AmiiboCategory.Custom),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.sports_esports_outlined),
                  activeIcon: const Icon(Icons.sports_esports),
                  label: translate!.figures,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.view_carousel_outlined),
                  activeIcon: const Icon(Icons.view_carousel),
                  label: translate!.cards,
                )
              ],
              currentIndex: category.index,
              onTap: (selected) =>
                  _updateCategory(ref, AmiiboCategory.values[selected]),
            ),
          ),
        ),
      ),
    );
  }
}

AsyncValue<List<Stat>> _usePreviousStat(WidgetRef ref, Expression expression) {
  final snapshot = ref.watch(_statsProvider(expression));
  final previous = usePrevious(snapshot);
  if (previous is AsyncData<List<Stat>> && snapshot is! AsyncData<List<Stat>>)
    return previous;
  return snapshot;
}

class _BodyStats extends HookConsumerWidget {
  final Expression expression;
  final bool expanded;

  _BodyStats(this.expression) : expanded = false;
  _BodyStats.expanded(this.expression) : expanded = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S translate = S.of(context);
    final snapshot = _usePreviousStat(ref, expression);
    if (snapshot is AsyncData<List<Stat>>) {
      if (snapshot.value.length <= 1)
        return Center(
          child: Text(
            translate.emptyPage,
            style: Theme.of(context).textTheme.headline4,
          ),
        );

      final Stat generalStats = snapshot.value.first;
      final List<Stat> stats = snapshot.value.sublist(1);
      return Scrollbar(
        child: CustomScrollView(
          slivers: <Widget>[
            if (stats.length > 1)
              SliverToBoxAdapter(
                key: Key('Amiibo Network'),
                child: SingleStat(
                  title: generalStats.name,
                  owned: generalStats.owned,
                  total: generalStats.total,
                  wished: generalStats.wished,
                ),
              ),
            if (MediaQuery.of(context).size.width <= 600)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => SingleStat(
                    key: ValueKey(index),
                    title: stats[index].name,
                    owned: stats[index].owned,
                    total: stats[index].total,
                    wished: stats[index].wished,
                  ),
                  semanticIndexOffset: 1,
                  childCount: stats.length,
                ),
              ),
            if (MediaQuery.of(context).size.width > 600)
              SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisSpacing: 8.0,
                  mainAxisExtent: 140,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => SingleStat(
                    key: ValueKey(index),
                    title: stats[index].name,
                    owned: stats[index].owned,
                    total: stats[index].total,
                    wished: stats[index].wished,
                  ),
                  semanticIndexOffset: 1,
                  childCount: stats.length,
                ),
              ),
            if (expanded) const SliverToBoxAdapter(child: SizedBox(height: 48))
          ],
        ),
      );
    }
    return const SizedBox();
  }
}

class _FAB extends ConsumerWidget {
  final Screenshot _screenshot = Screenshot();
  final AmiiboCategory _category;
  final Expression _expression;

  _FAB(this._category, this._expression);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final S translate = S.of(context);
    return FloatingActionButton(
      elevation: 0.0,
      child: const Icon(Icons.save),
      tooltip: translate.saveStatsTooltip,
      heroTag: 'MenuFAB',
      onPressed: () async {
        final ScaffoldMessengerState scaffoldState =
            ScaffoldMessenger.of(context);
        if (!(await permissionGranted(scaffoldState))) return;
        String message = translate.savingCollectionMessage;
        if (_screenshot.isRecording) message = translate.recordMessage;
        scaffoldState.hideCurrentSnackBar();
        scaffoldState.showSnackBar(SnackBar(content: Text(message)));
        if (!_screenshot.isRecording) {
          _screenshot.update(ref, context);
          final buffer = await _screenshot.saveStats(_expression);
          if (buffer != null) {
            String name;
            int id;
            switch (_category) {
              case AmiiboCategory.Cards:
                name = 'MyCardStats';
                id = 2;
                break;
              case AmiiboCategory.Figures:
                name = 'MyFigureStats';
                id = 3;
                break;
              case AmiiboCategory.Custom:
                name = 'MyCustomStats';
                id = 7;
                break;
              case AmiiboCategory.All:
              default:
                name = 'MyAmiiboStats';
                id = 1;
                break;
            }
            final Map<String, dynamic> notificationArgs = <String, dynamic>{
              'title': translate.notificationTitle,
              'actionTitle': translate.actionText,
              'id': id,
              'buffer': buffer,
              'name': '${name}_$dateTaken'
            };
            await NotificationService.saveImage(notificationArgs);
          }
        }
      },
    );
  }
}
