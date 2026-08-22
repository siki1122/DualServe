import re

def fix_booking_screen():
    file_path = 'c:/code/DUALSERVE/household_towing_app/lib/screens/customer/booking_screen.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the night surcharge part to anchor our fix
    start_marker = "Text('+ ${PricingConfig.formatPrice(nightDiff)}'),\n              ],\n            ),\n          ],\n"
    
    # We want to replace everything after this up to the `_buildSubmitButton` logic if it's messed up.
    # Actually, let's just find the `Widget _buildSubmitButton()` and what's before it.
    
    # Because it's mangled, let's just use regex to replace everything from the Night Surcharge to `_buildDetailedAddressFields`
    
    pattern = r"Text\('\+ \$\{PricingConfig\.formatPrice\(nightDiff\)\}'\),\n\s+\],\n\s+\),\n\s+\],\n(.*?)\n\s*\}\n\n\s*Widget _buildSubmitButton\(\) \{"
    
    replacement = """Text('+ ${PricingConfig.formatPrice(nightDiff)}'),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                PricingConfig.formatPrice(_estimatedCost),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {"""
  
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    if new_content == content:
        print("Regex match failed. Trying alternative approach.")
        # Alternative: The file might be even more broken.
        # Let's find "Night Surcharge" and replace up to "child: DropdownButton<String>"
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("Fixed booking_screen.dart")

if __name__ == "__main__":
    fix_booking_screen()
