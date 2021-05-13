# Release Notes - my-account

## v2.0
- Rewrite code to use FOLIO as a data source instead of Voyager (DISCOVERYACCESS-6993)
- Rewrite code to load sections of the user record via AJAX
- Implement read-only mode using MY_ACCOUNT_READONLY ENV flag (DISCOVERYACCESS-7019)

## v1.1.9
- Fix the Borrow Direct cancel link and move it to the template.

## v1.1.8
- Don't display checkbox for BD and ILL on pending tab. (DISCOVERYACCESS-6692)
- Callslip cancellations require their own url. (DISCOVERYACCESS-6692)

## v1.1.7
- Rescue any RestClient errors in the account controller. (DISCOVERYACCESS-6181)

## v1.1.6
- Remove the renewals alert text from the index template.

## v1.1.5
- Don't display the withdrawn status. (DISCOVERYACCESS-6433)

## v1.1.4
- Display alert text regarding renewals issue.

## v1.1.3
- Prevent 'undefined method strftime for nil:NilClass' exceptions. (DISCOVERYACCESS-5822)

## v1.1.2
- Call slip items should display on the pending requests tab. (DISCOVERYACCESS-5762)

## v1.1.1
- Call slip items should not be included in the @checkouts array. (DISCOVERYACCESS-5567)

## v1.1.0
- Add a master disable feature based on an env key: DISABLE_MY_ACCOUNT=1

## v1.0.6
- Changed 'Charged' status to be 'Checked Out' and added comma here: 'Recall Request, Checked Out'

## v1.0.5
- Reworked the redirect that occurs when no patron account is found

## v1.0.4
- Added nil check for @bd_requests in the index method
- If the netid isn't found, redirect to root and display flash message
- For Rails 5, protect_from_forgery must be explicitly prepended to the before_action chain
- Added Type column to the checkout out items tab

## v1.0.3
- Fixed a bug preventing renewals through ILLiad

## v1.0.2
### Bug fixes
- Improved renewal status and error messages
- Removed 'cannot be renewed' badges for items in large collections of charged material (fixes a timeout error)

## v1.0.1
### Bug fixes
- Guard against charged items with no due date
- Guard against empty renewable lookup hash
- Increase timeout of Voyager API call
- Rescue error in patron info lookup
- Additional nil checks

## v1.0

- Added new login page
- Added an easier way to switch users for debugging
- Various bug fixes

## v1.0 beta 3
- Removed catalog links for items that don't have a catalog record (#4)
- Add UI indication for items that can't be renewed (#3)
- Don't try to renew items that can't be renewed (#3)
- implemented 'renew all' (#5)

## v1.0 beta 2
- Added more debugging code
- Fixed a bug where charged ILL items appeared in the 'pending items' tab
- Sorted list of charged items by due date
- Fixed a bug in handling of voyager db id
- Sped up page reload by storing BD items in session
- Fix accessibility issue for checkboxes (DISCOVERYACCESS-4967)
- Enable/disable action buttons according to checkbox state

## v1.0 beta 1
- Initial beta release
