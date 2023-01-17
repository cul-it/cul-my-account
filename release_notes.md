# Release Notes - my-account

## v2.2.1
- Filter out ReShare items that don't match user's NetID.
- Skip ILL requests with status 'Request Sent to BD' (avoid duplicates).
- Skip BD/ReShare requests that are also listed in FOLIO (avoid duplicates).

## v2.2.0
- Replace Borrow Direct with ReShare
- Eliminate reference to ilsapi.cgi script
- Update login page text (DISCOVERYACCESS-7838)

## v2.1.6
- Specify Rails 6.1.

## v2.1.5
- Specify Rails 6 for Blacklight compatibility.

## v2.1.4
- Update wording for read-only, ILLiad and Borrow Direct notes

## v2.1.3
- Fix bug preventing display of service point name for requests
- Add repost gem dependency & use it to update auth calls for new Omniauth requirements

## v2.1.2
- Don't add links to checkout titles from Borrow Direct, but indicate BD titles with badges (DISCOVERYACCESS-7360)
- Cache FOLIO auth token to reduce number of API calls (DISCOVERYACCESS-7318)
- Require v1.2.1 or higher of cul-folio-edge (for new cancel function signature)

## v2.1.1
- Guard against null results from ILLiad lookup

## v2.1
- Add the ability to show alert messages at the top of the page from an alerts.yaml file

## v2.0.8
- Fix bug causing pending requests to show as available

## v2.0.7
- Fix bug causing renewals to sometimes fail (or appear to fail) (DISCOVERYACCESS-7201 again)
- Display pickup location names for available requests

## v2.0.6
- Properly display Borrow Direct requests

## v2.0.5

### Improvements
- Better appearance of alert banners
- Checkouts now sorted by both due date (primary) and title (secondary)

### Bug fixes
- Multiple cancel/renew attempts no longer generated for a single button click
- Resolved invalid date error with pending requests (DISCOVERYACCES-7218)
- Result of renewal attempts now reported correctly (DISCOVERYACCESS-7201)
- Due dates are displayed correctly for local time zone

## v2.0.4
- Remove temporary service interruptions alert. (DISCOVERYACCESS-7182)

## v2.0.3
- Remove guest ID login button. (DISCOVERYACCESS-7175)

## v2.0.2
- Update text of temporary service interruptions alert. (DISCOVERYACCESS-7181)

## v2.0.1
- Use promises to renew and cancel
- Add progress spinners to request buttons
- Add flash messages

## v2.0
- Rewrote code to use FOLIO as a data source instead of Voyager (DISCOVERYACCESS-6993)
- Rewrote code to load sections of the user record via AJAX
- Implemented read-only mode using MY_ACCOUNT_READONLY ENV flag (DISCOVERYACCESS-7019)
- Removed the RIS citation export buttons

## v1.2.3
- Modify the text of temporary service interruptions alert. (DISCOVERYACCESS-7094)

## v1.2.2
- Add read-only mode using MY_ACCOUNT_READONLY ENV flag (DISCOVERYACCESS-7019)

## v1.2.1
- Add temporary service interruptions alert. (DISCOVERYACCESS-7094)

## v1.2.0
- Apply mt-4 class to the first h2 heading.

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
