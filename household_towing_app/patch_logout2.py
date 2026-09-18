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

old_str = "pushNamedAndRemoveUntil('/login', (route) => false)"
new_str = "popUntil((route) => route.isFirst)"

for fpath in target_files:
    if os.path.exists(fpath):
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        if old_str in content:
            content = content.replace(old_str, new_str)
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(content)
            print('Fixed ' + fpath)
