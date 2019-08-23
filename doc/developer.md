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
MY_ACCOUNT_PATRONINFO_URL=<netid/patron info lookup URL>
MY_ACCOUNT_ILSAPI_URL=<ilsapi script URL>
MY_ACCOUNT_VOYAGER_URL=<Voyager web services URL>
```

After restarting the Blacklight server, MyAccount should be accessible at `/myaccount`.

## Important files
Most of the MA functionality is implemented within a handful of files. Important files include:
- `/app/assets/javascripts/my_account/account.js.coffee`: manages the UI checkboxes and enabling/disabling of the action buttons
- `/app/controllers/my_account/account_controller.rb`: this contains the bulk of the control code for the system
- `/app/helpers/my_account/my_account_helper.rb`: contains functions for properly displaying titles and item statuses
- `/app/models`: There are three model files — `account.rb`, `charged_item.rb`, and `voyager.rb` — that are not currently used (but may be in future to better organize the code).
- `/app/views/my_account/account/`: view files. There is essentially one main view (`index.html`) that is broken into individual table panes for charged items, pending requests, etc.

## Important external systems
MyAccount requires connections to a patroninfo/netid lookup service, Voyager’s web services, the ILLiad system, and Borrow Direct.

### Patron/netid info
Patron info is derived from the `patron_info_service.cgi` service (part of `voyager-tools`. Sample output looks like this:
```json
{"mjc12":{"status":"Active","barcode":"<user barcode>","empl_id":"<employee ID>","netid":"<netid>","last_name":"Connolly","group":"STAF","patron_id":"<Voyager patron ID>","first_name":"Matt"}}
```
This information is essential for the rest of the system, because `barcode` and `patron_id` are needed to perform lookups in the other external services. There have been a few reports lately of patrons being unable to access their accounts that I’ve traced to the `patron_info_service` returning a blank or incomplete response object. I _think_ (though I’m not sure) that this is because there is some gap between the time that new patron records are created for Voyager circulation and the time that they become available to the netid lookup service.

### Charged items
The central item lookup service is the `ilsapi` CGI service (currently `ilsapiE.cgi`, but there have been several versions). This is where things get a bit tricky. The `ilsapi` service takes a netid  and returns a JSON object primarily containing an array of all the items the user has checked out from Voyager (**which includes charged items from Borrow Direct and ILL**) and all his/her pending requests from ILLiad (but, confusingly, not from Borrow Direct!). The record for an individual item looks something like this if it’s an item from Voyager:
```json
    {
      "iid": "7403341",
      "od": "2019-06-13",
      "odt": "23:59",
      "system": "voyager",
      "statedate": "2018-06-13",
      "vstatus": "Charged",
      "vstatus_type": "2",
      "status": "chrged",
      "bid": "5416882",
      "re": "",
      "rd": "2019-06-13",
      "lo": "Mann Library",
      "ou_isbn": "158011086X ",
      "callno": "TH4961 .H92 2003",
      "renewal_count": "0",
      "ou_aulast": "Hylton, William H. ",
      "ou_title": "Trellises & arbors : landscape & design ideas, plus projects / ",
      "ou_pp": "Upper Saddle River, N.J. : ",
      "ou_yr": "2003",
      "ou_pb": "Creative Homeowner, ",
      "item_enum": "",
      "chron": "",
      "year": "",
      "tl": "Trellises & arbors : landscape & design ideas, plus projects / Bill Hylton. ",
      "au": "Hylton, William H. "
    }

```
However, if it’s an ILL or BD item, it will include different keys and values. The difficulty is in determining (a) the origin of a particular item (Voyager, ILL, or BD) and (b) the status of a given request.  