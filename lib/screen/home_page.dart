import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:amiibo_network/provider/amiibo_provider.dart';
import 'package:amiibo_network/model/amiibo_local_db.dart';
import 'package:amiibo_network/data/database.dart';
import 'package:flutter/rendering.dart';
import 'package:amiibo_network/widget/radial_progression.dart';
import 'package:amiibo_network/widget/drawer.dart';
import 'package:amiibo_network/widget/animated_widgets.dart';
import 'package:amiibo_network/widget/floating_bar.dart';

class Home extends StatelessWidget{

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ChangeNotifierProvider(
        builder: (context) => SelectProvider(),
        child: HomePage(),
      )
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin{
  ScrollController _controller;
  AnimationController _animationController;
  AmiiboProvider amiiboProvider;
  SelectProvider selected;
  static Widget _defaultLayoutBuilder(Widget currentChild, List<Widget> previousChildren) {
    List<Widget> children = previousChildren;
    if (currentChild != null)
      children = children.toList()..add(currentChild);
    return Stack(
      children: children,
      alignment: Alignment.centerRight,
    );
  }

  @override
  didChangeDependencies(){
    super.didChangeDependencies();
    amiiboProvider = Provider.of<AmiiboProvider>(context, listen: false);
    selected = Provider.of<SelectProvider>(context, listen: false);
  }

  void _restartAnimation(){
    _controller.jumpTo(0);
    _animationController.forward();
  }

  void _updateSelection({int wished = 0, int owned = 0}) async {
    AmiiboLocalDB amiibos = AmiiboLocalDB(amiibo: List<AmiiboDB>.of(
        selected.set.map((x) => AmiiboDB(key: x.value, wishlist: wished, owned: owned))
      )
    );
    selected.clearSelected();
    await amiiboProvider.updateAmiiboDB(amiibos: amiibos);
    await amiiboProvider.refreshPagination();
  }

  void _cancelSelection() => selected.clearSelected();

  void initBloc() async =>
    await Provider.of<AmiiboProvider>(context, listen: false).fetchAllAmiibosDB();

  @override
  void initState(){
    initBloc();
    _controller = ScrollController()..addListener(_scrollListener);
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this)..value = 1.0;
    super.initState();
  }

  @override
  void dispose(){
    //ConnectionFactory().close();
    _controller?.removeListener(_scrollListener);
    _controller?.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  void _scrollListener(){
    if((_controller?.hasClients ?? false) && !_animationController.isAnimating){
      switch(_controller.position.userScrollDirection){
        case ScrollDirection.forward:
          if(_animationController.isDismissed) _animationController.forward();
          break;
        case ScrollDirection.reverse:
          if(_animationController.isCompleted) _animationController.reverse();
          break;
        case ScrollDirection.idle:
          break;
      }
    }
  }

  void _search() async{
    String value = await Navigator.pushNamed(context,"/search");
    if(value != null && value != '') {
      amiiboProvider.resetPagination(value, search: true);
      _restartAnimation();
    }
  }

  Future<bool> _exitApp() async{
    if(selected.multipleSelected){
      selected.clearSelected();
      return false;
    } else {
      await ConnectionFactory().close();
      return await Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _exitApp,
      child: Selector<SelectProvider, bool>(
        selector: (_, select) => select.multipleSelected,
        child: SliverPersistentHeader(
          delegate: _SliverPersistentHeader(),
          pinned: true,
        ),
        builder: (_, _multipleSelection, child){
          return Scaffold(
            resizeToAvoidBottomInset: false,
            drawer: _multipleSelection ? null : CollectionDrawer(restart: _restartAnimation,),
            body: Scrollbar(
              child: CustomScrollView(
                controller: _controller,
                slivers: <Widget>[
                  SliverFloatingBar(
                    floating: true,
                    forward: _multipleSelection,
                    snap: true,
                    leading: Builder(
                      builder: (context) => IconButton(
                        icon: ImplicitIcon(forward: _multipleSelection),
                        tooltip: _multipleSelection ? 'close' : 'drawer',
                        onPressed: _multipleSelection ? _cancelSelection : () => Scaffold.of(context).openDrawer(),
                      )
                    ),
                    title: Selector2<AmiiboProvider, SelectProvider, String>(
                      selector: (context, text, count) => count.multipleSelected ? count.selected.toString() : text.strFilter,
                      builder: (context, text, _) {
                        return Tooltip(
                          message: '${num.tryParse(text) == null ?
                          'Search Amiibo' : '$text Selected' }',
                          child: Text(text ?? ''),
                        );
                      },
                    ),
                    onTap: _multipleSelection ? null : _search,
                    trailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      layoutBuilder: _defaultLayoutBuilder,
                      child: _multipleSelection ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: _updateSelection,
                            tooltip: 'Remove',
                          ),
                          IconButton(
                            icon: Icon(Icons.star),
                            onPressed: () => _updateSelection(owned: 1),
                            tooltip: 'Own',
                          ),
                          IconButton(
                            icon: Icon(Icons.card_giftcard),
                            onPressed: () => _updateSelection(wished: 1),
                            tooltip: 'Wish',
                          ),
                        ],
                      ) : _SortCollection(),
                    )
                  ),
                  child,
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    sliver: Selector<AmiiboProvider, AmiiboLocalDB>(
                      child: const SliverToBoxAdapter(
                        child: const Align(alignment: Alignment.center, heightFactor: 10,
                          child: const Text('Nothing to see here. . .yet',
                            textAlign: TextAlign.center,
                          )
                        )
                      ),
                      selector: (context, amiibo) => amiibo.amiibosDB,
                      builder: (ctx, data, child){
                        bool bigGrid = MediaQuery.of(context).size.width >= 600;
                        if((data?.amiibo?.length ?? 1) == 0)
                          return DefaultTextStyle(
                            style: Theme.of(context).textTheme.display1,
                            child: child,
                          );
                        else return SliverGrid(
                          gridDelegate: bigGrid ?
                          SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 192,
                            mainAxisSpacing: 8.0,
                          ) :
                          SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8.0
                          ),
                          delegate: SliverChildBuilderDelegate((BuildContext _, int index) {
                            return FadeSwitchAnimation(
                              key: ValueKey<int>(index),
                              child: AmiiboGrid(
                                index: index,
                                key: ValueKey<int>(data?.amiibo[index].key),
                              ),
                            );
                          },
                            //addRepaintBoundaries: false, addAutomaticKeepAlives: false,
                            childCount: data?.amiibo != null ? data?.amiibo?.length : 0,
                          )
                        );
                      },
                    )
                  ),
                ],
              )
            ),
            floatingActionButton: FAB(_animationController, () => _controller.jumpTo(0)),
          );
        },
      ),
    );
  }
}

class _SliverPersistentHeader extends SliverPersistentHeaderDelegate {

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.5, 0.7, 1],
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.75),
            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
          ]
        )
      ),
      height: kToolbarHeight,
      child: StreamBuilder<Map<String,dynamic>>(
        initialData: {'Owned' : 0, 'Wished' : 0, 'Total' : 0},
        stream: Provider.of<AmiiboProvider>(context, listen: false).collectionList,
        builder: (context , statList) {
          if(statList.data['Total'] == 0 || statList == null)
            return const SizedBox();
          return Row(
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  child: FlatButton.icon(
                    onPressed: null,
                    icon: AnimatedRadial(
                      key: Key('Owned'),
                      percentage:
                      statList.data['Owned'].toDouble()
                          / statList.data['Total'].toDouble(),
                      child: const Icon(Icons.check, color: Colors.green),
                    ),
                    label: Text('${statList.data['Owned']}/'
                        '${statList.data['Total']} Owned', softWrap: false,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.subhead,
                    ),
                  ),
                )
              ),
              Expanded(
                child: FittedBox(
                  child: FlatButton.icon(
                    onPressed: null,
                    icon: AnimatedRadial(
                      key: Key('Wished'),
                      percentage:
                      statList.data['Wished'].toDouble()
                          / statList.data['Total'].toDouble(),
                      child: const Icon(Icons.whatshot, color: Colors.amber),
                    ),
                    label: Text('${statList.data['Wished']}/'
                        '${statList.data['Total']} Wished',
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.subhead,
                    ),
                  ),
                )
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  double get maxExtent => kToolbarHeight;

  @override
  double get minExtent => kToolbarHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate)
    => maxExtent != oldDelegate.maxExtent || minExtent != oldDelegate.minExtent;
}

class _SortCollection extends StatefulWidget{
  @override
  _SortCollectionState createState() => _SortCollectionState();
}

class _SortCollectionState extends State<_SortCollection> {

  void _selectOrder(String sort) async{
    final AmiiboProvider amiiboProvider = Provider.of<AmiiboProvider>(context, listen: false);
    amiiboProvider.strOrderBy = sort;
    await amiiboProvider.refreshPagination();
    Navigator.pop(context);
  }

  Future<void> _dialog() async {
    String _sortBy = Provider.of<AmiiboProvider>(context).orderBy;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          semanticLabel: 'Sort',
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text('Sort By'),
              ),
              const Divider(),
            ],
          ),
          titlePadding: const EdgeInsets.only(top: 12.0),
          contentPadding: const EdgeInsets.only(bottom: 8.0),
          children: <Widget>[
            RadioListTile(
              value: 'name',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('Name'),
              selected: _sortBy == 'name',
            ),
            RadioListTile(
              value: 'owned DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              selected: _sortBy == 'owned DESC',
              title: Text('Owned'),
            ),
            RadioListTile(
              value: 'wishlist DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('Wished'),
              selected: _sortBy == 'wishlist DESC',
            ),
            RadioListTile(
              value: 'na DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('American Date'),
              selected: _sortBy == 'na DESC',
              secondary: Image.asset(
                'assets/images/na.png',
                height: 16, width: 25,
                fit: BoxFit.fill,
                semanticLabel: 'American Date',
              ),
            ),
            RadioListTile(
              value: 'eu DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('European Date'),
              selected: _sortBy == 'eu DESC',
              secondary: Image.asset(
                'assets/images/eu.png',
                height: 16, width: 25,
                fit: BoxFit.fill,
                semanticLabel: 'European date',
              ),
            ),
            RadioListTile(
              value: 'jp DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('Japanese Date'),
              selected: _sortBy == 'jp DESC',
              secondary: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(width: 0.75)
                ),
                position: DecorationPosition.foreground,
                child: Image.asset(
                  'assets/images/jp.png',
                  height: 16, width: 25,
                  fit: BoxFit.fill,
                  semanticLabel: 'Japanese date',
                ),
              )
            ),
            RadioListTile(
              value: 'au DESC',
              groupValue: _sortBy,
              onChanged: _selectOrder,
              dense: true,
              title: Text('Australian Date'),
              selected: _sortBy == 'au DESC',
              secondary: Image.asset(
                'assets/images/au.png',
                height: 16, width: 25,
                fit: BoxFit.fill,
                semanticLabel: 'Australian date',
              ),
            ),
          ],
        );
      }
    );
  }

  Future<void> _bottomSheet() async {
    Map<String,String> _exSortBy = Provider.of<AmiiboProvider>(context).exOrderBy;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          maxChildSize: 0.75, expand: false, minChildSize: 0.15,
          builder: (context, scrollController){
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Theme.of(context).backgroundColor,
                shape: Theme.of(context).bottomSheetTheme.shape,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: <Widget>[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _BottomSheetHeader(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Text('Sort By', style: Theme.of(context).textTheme.subhead,),
                            ),
                            InkResponse(
                              radius: 18,
                              splashFactory: InkRipple.splashFactory,
                              highlightColor: Colors.transparent,
                              child: const Icon(Icons.save,),
                              onTap: () => print('pressed'),
                            ),
                          ],
                        )
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        ListTile(
                          onTap: () => print(''),
                          dense: true,
                          title: Text('Name'),
                          selected: _exSortBy.containsKey('name'),
                          leading: const Icon(Icons.arrow_upward, size: 15,)
                        ),
                        ListTile(
                          dense: true,
                          title: Text('Serie'),
                          selected: _exSortBy.containsKey('serie'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                        ),
                        ListTile(
                          dense: true,
                          title: Text('Game'),
                          selected: _exSortBy.containsKey('game'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                        ),
                        ListTile(
                          dense: true,
                          title: Text('Owned'),
                          selected: _exSortBy.containsKey('owned'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                        ),
                        ListTile(
                          dense: true,
                          title: Text('Wished'),
                          selected: _exSortBy.containsKey('wished'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                        ),
                        const Divider(),
                        ListTile(
                          onTap: () => print(''),
                          dense: true,
                          title: Text('American Date'),
                          selected: _exSortBy.containsKey('na'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                          trailing: Image.asset(
                            'assets/images/na.png',
                            height: 16, width: 25,
                            fit: BoxFit.fill,
                            semanticLabel: 'Australian date',
                          ),
                        ),
                        ListTile(
                          dense: true,
                          title: Text('European Date'),
                          selected: _exSortBy.containsKey('eu'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                          trailing: Image.asset(
                            'assets/images/eu.png',
                            height: 16, width: 25,
                            fit: BoxFit.fill,
                            semanticLabel: 'Australian date',
                          ),
                        ),
                        ListTile(
                            dense: true,
                            title: Text('Japanese Date'),
                            selected: _exSortBy.containsKey('jp'),
                            leading: const Icon(Icons.arrow_upward, size: 15,),
                            trailing: DecoratedBox(
                              decoration: BoxDecoration(
                                  border: Border.all(width: 0.75)
                              ),
                              position: DecorationPosition.foreground,
                              child: Image.asset(
                                'assets/images/jp.png',
                                height: 16, width: 25,
                                fit: BoxFit.fill,
                                semanticLabel: 'Japanese date',
                              ),
                            )
                        ),
                        ListTile(
                          dense: true,
                          title: Text('Australian Date'),
                          selected: _exSortBy.containsKey('au'),
                          leading: const Icon(Icons.arrow_upward, size: 15,),
                          trailing: Image.asset(
                            'assets/images/au.png',
                            height: 16, width: 25,
                            fit: BoxFit.fill,
                            semanticLabel: 'Australian date',
                          ),
                        ),
                      ]),
                    )
                  ],
                )
              )
            );
          },
        );
      }
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _dialog,
      icon: const Icon(Icons.sort_by_alpha),
      tooltip: 'Sort',
    );
  }
}

class _BottomSheetHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  _BottomSheetHeader({@required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: kToolbarHeight,
      child: Material(
        color: Theme.of(context).backgroundColor,
        shape: Theme.of(context).bottomSheetTheme.shape,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
            const Divider()
          ],
        ),
      )
    );
  }

  @override
  double get maxExtent => kToolbarHeight;

  @override
  double get minExtent => kToolbarHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}

class FAB extends StatelessWidget{
  final Animation<double> scale;
  final AnimationController controller;
  final VoidCallback goTop;

  FAB(this.controller, this.goTop):
    scale = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
      CurvedAnimation(parent: controller,
        curve: Interval(0.0, 1, curve: Curves.decelerate),
      )
    );

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scale,
      child: FloatingActionButton(
        tooltip: 'Up',
        mini: true,
        heroTag: 'MenuFAB',
        onPressed: goTop,
        child: const Icon(Icons.keyboard_arrow_up),
      )
    );
  }
}

class AmiiboGrid extends StatefulWidget {
  final int index;

  const AmiiboGrid({
    Key key,
    this.index,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => AmiiboGridState();
}

class AmiiboGridState extends State<AmiiboGrid> {
  SelectProvider mSelected;
  bool _multipleSelected;
  AmiiboProvider amiiboProvider;
  AmiiboDB amiibo;

  @override
  didChangeDependencies(){
    super.didChangeDependencies();
    amiiboProvider = Provider.of<AmiiboProvider>(context, listen: false);
    mSelected = Provider.of<SelectProvider>(context, listen: false);
  }

  _onDoubleTap() =>
    Navigator.pushNamed(context, "/details", arguments: widget.index);

  _onTap(){
    switch(amiibo?.owned ?? 0){
      case 1:
        amiiboProvider.countOwned = amiibo.owned = 0;
        amiiboProvider.countWished = amiibo.wishlist = 1;
        break;
      case 0:
        if((amiibo?.wishlist ?? 0) == 0)
          amiiboProvider.countOwned = amiibo.owned = 1;
        else amiiboProvider.countWished = amiibo.wishlist = 0;
        break;
    }
    amiiboProvider..updateAmiiboDB(amiibo: amiibo)..updateList()..notifyWidgets();
    //setState(() {});
  }

  _onLongPress(){
    if(!mSelected.addSelected(widget.key)) mSelected.removeSelected(widget.key);
    mSelected.notifyWidgets();
  }

  @override
  Widget build(BuildContext context){
    _multipleSelected = mSelected.multipleSelected;
    amiibo = amiiboProvider.amiibosDB.amiibo[widget.index];
    return Selector<SelectProvider,bool>(
      builder: (context, _isSelected, child){
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.linearToEaseOut,
          margin: _isSelected ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : EdgeInsets.zero,
          padding: _isSelected ? const EdgeInsets.all(8) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: _isSelected ? Theme.of(context).selectedRowColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8)
          ),
          child: child
        );
      },
      selector: (context, selected) => selected.isSelected(widget.key),
      child: GestureDetector(
        onDoubleTap: _multipleSelected ? null : _onDoubleTap,
        onTap: _multipleSelected ? _onLongPress : _onTap,
        onLongPress: _onLongPress,
        child: Stack(
          children: <Widget>[
            Card(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Hero(
                      transitionOnUserGestures: true,
                      tag: amiibo.key,
                      child: Image.asset('assets/collection/icon_${amiibo.key}.png',
                        fit: BoxFit.scaleDown,
                      )
                    ),
                    flex: 9,
                  ),
                  Expanded(
                    child: Container(
                      decoration: ShapeDecoration(
                        color: Theme.of(context).primaryColorLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)))),
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text('${amiibo.name}',
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    flex: 2,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Selector<AmiiboProvider, Widget>(
                builder: (ctx, widget, child){
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeInToLinear,
                    switchOutCurve: Curves.easeOutCirc,
                    transitionBuilder: (Widget child, Animation <double> animation)
                    => ScaleTransition(scale: animation, child: child,),
                    child: widget
                  );
                },
                selector: (context, amiiboProvider) {
                  AmiiboDB amiibo = amiiboProvider.amiibosDB.amiibo[widget.index];
                  if(amiibo?.wishlist?.isOdd ?? false)
                    return const Icon(Icons.card_giftcard, key: ValueKey(2), color: Colors.limeAccent,);
                  else if(amiibo?.owned?.isOdd ?? false)
                    return const Icon(Icons.star, key: ValueKey(1), color: Colors.pinkAccent,);
                  else return const SizedBox.shrink();
                }
              )
            ),
          ],
        ),
      )
    );
  }
}