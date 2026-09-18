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

for file_path in target_files:
    if not os.path.exists(file_path): 
        print(f"Skipping {file_path}, not found.")
        continue
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'FirebaseAuth.instance.signOut()' in content and 'rootNavigator' not in content:
        content = content.replace(
            'await FirebaseAuth.instance.signOut();',
            'await FirebaseAuth.instance.signOut();\n              if (context.mounted) { Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(\'/login\', (route) => false); }'
        )
        content = content.replace(
            '() => FirebaseAuth.instance.signOut(),',
            '() async { await FirebaseAuth.instance.signOut(); if (context.mounted) { Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(\'/login\', (route) => false); } },'
        )
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Patched {file_path}")
