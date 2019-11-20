# Release Notes - my-account

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
