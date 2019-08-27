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
BORROW_DIRECT_PROD_API_KEY=<API key for Borrow Direct web services>
BORROW_DIRECT_TIMEOUT=<Borrow Direct timeout in seconds>
```
Note that the Borrow Direct ENV keys are also used by the Requests engine.

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

### Charged items and ILL requests
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

### Borrow Direct requests
Borrow Direct _requests_ are brought in separately via the BD API (within `my_account_controller`, using the `borrow_direct` gem). Once the user has claimed and checked out an available BD request, it will appear in the output from the `ilsapi` lookup.

## Authentication and debugging without SAML
By default, MA uses SAML authentication to authenticate a user and retrieve a netid (see the `authenticate_user` and `user` methods in `my_account_controller.rb`). Since SAML is a little tricky to get up and running on an individual development machine, there is a workaround. If Blacklight/Rails is running in `development` mode, a special key can be added to the Blacklight `.env` file: `DEBUG_USER=<netid>`. (This has no effect if Rails is running in `production` mode, to prevent bad things from happening. This value can also be used to debug the Requests engine.) In that case, SAML authentication is bypassed and MA loads with the account information for the specified netid.

## Main event loop
The primary path/method in `my_account_controller` is `index`: this is the default content that is loaded when a user logs in. (The `/myaccount/login` path and `intro` method are used to display a “landing page” for the user, with general information about MA and a login button.)

When a user logs in and hits the `index` method, the following happens:
1. Patron info (netid, barcode, etc) is loaded into `@patron`.
2. The `params` object is checked to see if this page load is due to a `Renew` or `Cancel` button click. If so, the user is routed to the appropriate method for item renewal or request cancellation.
3. The `get_patron_stuff` method is called. This queries the `ilsapi` web service to retrieve a list of the user’s items and then tries to make sense of them, separating them into Voyager or other charged items, available requests, and pending requests. Then the Borrow Direct service and an additional Voyager web service are called to retrieve information about any BD requests and fines or fees the user may have.
4. If possible, the `@renewable_lookup_hash` object is built. This builds a lookup dictionary of item IDs and their renewability status in Voyager: `Y` or `N`, indicating whether the item can be renewed. This is used to indicate unrenewable items in the UI and to make the renewal process more efficient. Unfortunately, the Voyager web service that this process uses has a tendency to time out and return a nasty 500 error if the user has a large number of items checked out (on the order of a few hundred). For now, therefore, `@renewable_lookup_hash` is only populated if the number of charged items in question is \<= 100.
5. Finally, if the citation export button has been clicked, the `export` method is called to handle that. Otherwise, the view template is loaded to display the user’s list of items.

## Common problems
### Missing patron info
### Voyager web services timeout
### Determining the origin and status of a request