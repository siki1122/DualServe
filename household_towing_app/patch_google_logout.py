import os

target_files = [
    'lib/widgets/provider_drawer.dart',
    'lib/widgets/customer_drawer.dart',
    'lib/screens/driver/driver_main_layout.dart',
    'lib/screens/driver/driver_profile_screen.dart',
    'lib/screens/provider/provider_settings_screen.dart',
    'lib/screens/auth/pending_approval_screen.dart',
    'lib/screens/auth/profile_setup_screen.dart',
    'lib/screens/auth/email_verification_screen.dart',
    'lib/screens/customer/customer_settings_screen.dart'
]

import_statement = "import 'package:household_towing_app/services/google_auth_service.dart';\n"

for fpath in target_files:
    if os.path.exists(fpath):
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'FirebaseAuth.instance.signOut()' in content:
            # Replace sign out
            content = content.replace(
                'await FirebaseAuth.instance.signOut();',
                'await GoogleAuthService().signOut();'
            )
            
            # Add import if missing
            if 'google_auth_service.dart' not in content:
                # insert after the last import
                last_import_idx = content.rfind("import '")
                if last_import_idx != -1:
                    end_of_line = content.find('\n', last_import_idx)
                    content = content[:end_of_line+1] + import_statement + content[end_of_line+1:]
                else:
                    content = import_statement + content
                    
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(content)
            print('Patched Google SignOut in ' + fpath)
