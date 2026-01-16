# MyAccount Developer Documentation

The MyAccount system reproduces the functionality of the Drupal-based MyAccount implementation that was previously in use. The current system was put into production during July/August 2019. This document is intended to help developers understand how it all works and to debug common issues.

## Installation

MyAccount (MA) runs as a Rails engine. Assuming a working `blacklight-cornell` instance, MA can be added by doing the following:
1. In `config/routes.rb`, mount the engine:
```
mount MyAccount::Engine => '/myaccount', :as => 'my_account'
```
2. In the root-level `.env` file, add these key-value pairs:
```
MY_ACCOUNT_ILSAPI_URL=<ilsapi script URL>
OKAPI_URL=<URL of a FOLIO *Okapi* interface
OKAPI_TENANT=<Okapi tenant ID>
OKAPI_USER=<FOLIO username for requests API access>
OKAPI_PW=<password for FOLIO user>
BORROW_DIRECT_PROD_API_KEY=<API key for BorrowDirect web services>
BORROW_DIRECT_TIMEOUT=<BorrowDirect timeout in seconds>
```

Note that the BorrowDirect and Okapi ENV keys are also used by the Requests engine.

After restarting the Blacklight server, MyAccount should be accessible at `/myaccount`.

### Disabling MA
The entire MyAccount system can be disabled by adding another ENV key to the file: `DISABLE_MY_ACCOUNT=1`. If this key/value pair is present, then all visitors to MA will be rerouted to the catalog home page and shown a flash message informing them that the service is presently unavailable.

The system can be put into read-only mode by adding the ENV key: `MY_ACCOUNT_READONLY=1`. If this key/value pair is present, users can still view their accounts, but the renew and cancel buttons are missing.

## Important files
Most of the MA functionality is implemented within a handful of files. Important files include:
- `/app/assets/javascripts/my_account/account.js.coffee`: controls the main flow of the app, somewhat replacing the usual role of a Rails controller
- `/app/controllers/my_account/account_controller.rb`: this contains methods for querying FOLIO and other data sources via AJAX requests
- `/app/helpers/my_account/my_account_helper.rb`: contains functions for properly displaying titles and item statuses
- `/app/models`: There are three model files — `account.rb`, `charged_item.rb`, and `voyager.rb` — that are not currently used (but may be in future to better organize the code).
- `/app/views/my_account/account/`: view files. There is essentially one main view (`index.html`) that is broken into individual table panes for charged items, pending requests, etc.

## Important external systems
MyAccount requires connections to a patroninfo/netid lookup service, Voyager’s web services, the ILLiad system, and BorrowDirect.

### Patron/netid info
Patron info is derived from the `patron_info_service.cgi` service (part of `voyager-tools`. Sample output looks like this:
```json
{"mjc12":{"status":"Active","barcode":"<user barcode>","empl_id":"<employee ID>","netid":"<netid>","last_name":"Connolly","group":"STAF","patron_id":"<Voyager patron ID>","first_name":"Matt"}}
```
This information is essential for the rest of the system, because `barcode` and `patron_id` are needed to perform lookups in the other external services. 

### Charged items and ILL requests
The central item lookup services are FOLIO and the `ilsapi` CGI service (currently `ilsapiE.cgi`, but there have been several versions). FOLIO provides user account information with details about checked-out items, pending FOLIO requests, and any fines/fees the user has. The `ilsapi` service takes a netid  and returns a JSON object primarily containing an array of all the pending requests the user has from ILLiad (but, confusingly, not from BorrowDirect!). 

A FOLIO account record lookup results in something like the following:
```json
{
  "totalCharges" : {
    "amount" : 0.0,
    "isoCurrencyCode" : "USD"
  },
  "totalChargesCount" : 0,
  "totalLoans" : 45,
  "totalHolds" : 0,
  "charges" : [ ],
  "holds" : [ ],
  "loans" : [ {
    "id" : "8e515b26-2924-473e-ad25-31ba0a28519f",
    "item" : {
      "instanceId" : "4f58060a-c857-4a53-b954-0ad670a80106",
      "itemId" : "9d5cfb8a-4286-4934-8091-2df8259ffa3a",
      "title" : "\"The way to the dwelling of light\" : how physics illuminates creation / Guy Consolmagno.",
      "author" : "Consolmagno, Guy, 1952-"
    },
    "loanDate" : "2007-05-03T21:43:44.000+0000",
    "dueDate" : "2022-02-06T23:00:00.000+0000",
    "overdue" : false
  }
```

The record for an individual item from ILLiad looks something like this:
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

### BorrowDirect requests
BorrowDirect _requests_ are brought in separately via the BD API (within `my_account_controller`, using the `borrow_direct` gem). Once the user has claimed and checked out an available BD request, it will appear in the output from the FOLIO lookup.

## Authentication and debugging without SAML
By default, MA uses SAML authentication to authenticate a user and retrieve a netid (see the `authenticate_user` and `user` methods in `my_account_controller.rb`). Since SAML is a little tricky to get up and running on an individual development machine, there is a workaround. If Blacklight/Rails is running in `development` mode, a special key can be added to the Blacklight `.env` file: `DEBUG_USER=<netid>`. (This has no effect if Rails is running in `production` mode, to prevent bad things from happening. This value can also be used to debug the Requests engine.) In that case, SAML authentication is bypassed and MA loads with the account information for the specified netid.

## Main event loop
The primary path/method in `my_account_controller` is `index`: this is the default content that is loaded when a user logs in. (The `/myaccount/login` path and `intro` method are used to display a “landing page” for the user, with general information about MA and a login button.) However, most of the action takes place not here, but in the `account.js.coffee` file.

The CoffeeScript file sets a document.ready action that initiates the following sequence once the initial page load is complete:

1. The user's netid is recovered from an embedded data tag on the page
2. AJAX is used to call the `get_folio_data` method in the account controller, which retrieves the patron's FOLIO account information (not his/her user record, but details about checkouts, requests, and fines). If the call is completed successfully, the data returned is used to populate the Checkouts and Fines tabs of the page (see 'AJAX loop' below).
3. At the same time as (2), a second AJAX call queries `get_illiad_data` to retrieve ILLiad account information.
4. When both of the AJAX calls in (2) and (3) are complete, the request-related data from both sources is combined and used to populate the Available requests and Pending requests tabs.
5. Links to catalog records are added to checked-out items.

A similar AJAX strategy is used to handle the renew and cancel user actions.

## AJAX loop
There are several ways of handling AJAX in Rails, so a description of how things are implemented here may be useful.

As stated above, all UI-related actions are initiated by AJAX calls from the CoffeeScript file -- either automatically when the page is loaded, or when the user clicks the renew or cancel button. Either way, when an action begins, the Javascript and Ruby/Rails controller work together as follows:

1. An AJAX call is made to a route defined as a normal Rails route in `routes.rb`. The route maps to a method defined in `account_controller.rb`. Most (but not all) of the methods used for this purpose are prefixed in the controller with `ajax_`, e.g., `ajax_renew`, to make them easy to spot.
2. The controller method uses the `CUL::FOLIO::Edge` gem to talk to FOLIO and retrieve or set the necessary data. It then returns a JSON response to the Javascript side.
3. The Javascript calling function receives the response from the controller method and checks it for errors. If there are none, TODO: FINISH THIS

## Common problems
### Missing patron info
There have been a few reports lately of patrons being unable to access their accounts that I’ve traced to the `patron_info_service` returning a blank or incomplete response object. I _think_ (though I’m not sure) that this is because there is some gap between the time that new patron records are created for Voyager circulation and the time that they become available to the netid lookup service. If we can’t determine a patron’s netid and barcode, then we can’t look up the details for his/her account. I’m not sure if the `patron_info_service.cgi` can be modified to remedy this.

### Voyager web services timeout
It turns out that some patrons have _a lot_ of items checked out! When the number of charged items runs into the thousands, it can cause problems with the Voyager web services (and the `ilsapi` script too, since it does its own Voyager lookups). In extreme cases, the `ilsapi` request can time out, causing an error and preventing the account view from loading properly. 

And, as mentioned above, there is a separate Voyager web service that is needed to provide an item’s renewability status. That service is much more prone to timeouts, so I’m trying not to use it now except for smaller accounts with a reasonable number of charged items.

### Determining the origin and status of a request
Voyager and ILLiad requests are retrieved through the `ilsapi` service; BorrowDirect through its own APIs. It’s easy to distinguish BD requests from the others, then (while they’re pending, at least; once an item is charged, it appears in the `ilsapi` list as well). But separating Voyager and ILLiad requests is more of a challenge.

Relevant fields in an `ilsapi` item record include `system`, `status` (but also `vstatus`), and `ttype`. `system` can be `illiad` or `voyager`. `ttype` can be `H` or `R` for hold or recall (or possibly something else for L2L?). `status` is the most ambiguous value; depending on where a request is in its process, status might appear as `waiting`, `chrged`, `finef` (for duplicate records showing fines), `ON_LOAN`,  or the mysterious `pahr`, which seems to have an ambiguous meaning. The `get_patron_stuff` method in `account_controller.rb` attempts to sort items into their proper categories based on these values.
