# User Feedback And Reviews

## Internal Feedback

Users can submit private feedback from Settings through `Geri bildirim gönder`.
The form supports:

- Optional 1-5 rating
- Optional category
- Optional message
- Source metadata

Feedback is stored in Supabase `user_feedback`. Users can insert and read only
their own feedback. Admins can read all feedback from the admin panel Feedback
tab.

Private complaints, bug reports, and negative experiences should go to this
feedback flow, not to a public review prompt.

## Ethical Review Prompting

Store review prompts must be respectful:

- Do not force users to rate.
- Do not block app features behind reviews.
- Do not repeatedly ask after dismissal.
- Do not show prompts after errors, reports, no-shows, or bad experiences.
- Do not ask on first launch.
- Do not manipulate users into only leaving positive public reviews.

The current app does not include a store review package. Until an official
package is added, the app only provides an internal lightweight prompt:

- `Match A Man deneyimin nasıldı?`
- `İyi`
- `Sorun yaşadım`

If the user taps `İyi`, the app thanks them and explains store review requests
may happen after launch. If the user taps `Sorun yaşadım`, the app opens the
private feedback form.

## Future Store Review Integration

If a supported official in-app review package is added later, use it only when
`ReviewPromptRules.canShow(...)` returns true and platform rules allow a prompt.
Keep prompt frequency conservative and continue routing complaints to private
feedback.
