import 'package:url_launcher/url_launcher.dart';

import '../core/privacidade.dart';

export '../core/privacidade.dart';

Future<bool> abrirEmailContato() => launchUrl(
    Uri(scheme: 'mailto', path: emailContato),
    mode: LaunchMode.externalApplication);
