# FOR DEV ENVIRONMENTS ONLY - provide privacy filter option when using DEBUG_USER

window.toggleBlurredElements = ->
  privacyToggle = document.getElementById 'privacy-toggle'
  if privacyToggle
    # Find all elements that are marked as blur targets
    elementsToBlur = document.querySelectorAll('[data-blur-target]')
    elementsToBlur.forEach (element) ->
      if privacyToggle.checked
        element.classList.add('blurred')
      else
        element.classList.remove('blurred')
 