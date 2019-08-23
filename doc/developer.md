# MyAccount Developer Documentation

The MyAccount system reproduces the functionality from the Drupal-based MyAccount implementation that was previously in use. The current system was put into production during July/August 2019. This document is intended to help developers understand how it all works and too debug common issues.

## Installation

MyAccount (MA) runs as a Rails engine. Assuming a working `blacklight-cornell` instance, MA can be added by doing the following:
1. In `config/routes.rb`, mount the engine:
```
mount MyAccount::Engine => '/myaccount', :as => 'my_account'
```
2. In the root-level `.env` file, add these key-value pairs:
```
MY_ACCOUNT_PATRONINFO_URL=https://voyager-tools.library.cornell.edu/patron_info_service/patron_info_service.cgi/netid
MY_ACCOUNT_ILSAPI_URL=https://voy-api.library.cornell.edu/cgi-bin/ilsapiE.cgi
MY_ACCOUNT_VOYAGER_URL=https://catalog.library.cornell.edu/vxws
```

After restarting the Blacklight server, MyAccount should be accessible at `/myaccount`.

## Important files
Most of the MA functionality is implemented within a handful of files. Important files include:
- `/app/assets/javascripts/my_account/account.js.coffee`: manages the UI checkboxes and enabling/disabling of the action buttons
- `/app/controllers/my_account/account_controller.rb`: this contains the bulk of the control code for the system
- `/app/helpers/my_account/my_account_helper.rb`: contains functions for properly displaying titles and item statuses
- `/app/models`: There are three model files — `account.rb`, `charged_item.rb`, and `voyager.rb` — that are not currently used (but may be in future to better organize the code).
- `/app/views/my_account/account/`: view files. There is essentially one main view (`index.html`) that is broken into individual table panes for charged items, pending requests, etc.