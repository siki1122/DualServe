import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class MapUtils {
  static Future<void> openMap(String address) async {
    String query = Uri.encodeComponent(address);
    Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    Uri appleUrl = Uri.parse("http://maps.apple.com/?q=$query");

    try {
      if (Platform.isIOS) {
        if (await canLaunchUrl(appleUrl)) {
          await launchUrl(appleUrl);
        } else if (await canLaunchUrl(googleUrl)) {
          await launchUrl(googleUrl);
        } else {
          throw 'Could not launch maps';
        }
      } else {
        if (await canLaunchUrl(googleUrl)) {
          await launchUrl(googleUrl);
        } else {
          throw 'Could not launch maps';
        }
      }
    } catch (e) {
    }
  }

  static Future<void> openMapWithCoords(double lat, double lng) async {
    Uri googleUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open the map.';
    }
  }
}
