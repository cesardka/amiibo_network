import 'package:amiibo_network/generated/l10n.dart';
import 'package:amiibo_network/repository/theme_repository.dart';
import 'package:amiibo_network/widget/stat_widget.dart';
import 'package:flutter/material.dart';

class SingleStat extends StatelessWidget {
  final String title;
  final int owned;
  final int wished;
  final int total;
  final WrapAlignment wrapAlignment;

  const SingleStat(
      {Key key,
      this.title,
      this.owned,
      this.wished,
      this.total,
      this.wrapAlignment = WrapAlignment.spaceAround})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final S translate = S.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: wrapAlignment,
          children: <Widget>[
            SizedBox(
              height: 21.24,
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.center,
                child: Text(
                  title,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.headline4,
                ),
              ),
            ),
            const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: StatWidget(
                num: owned.toDouble(),
                den: total.toDouble(),
                text: translate.owned,
                icon: Icon(iconOwnedDark, color: Colors.green[800]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: StatWidget(
                num: wished.toDouble(),
                den: total.toDouble(),
                text: translate.wished,
                icon: Icon(Icons.whatshot, color: Colors.amber[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
